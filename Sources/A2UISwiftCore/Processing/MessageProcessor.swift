// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

// MARK: - MessageProcessor

/// The central processor for A2UI server-to-client messages.
/// Owns a `SurfaceGroupModel` and routes each `A2uiMessage` to the appropriate handler.
/// Mirrors WebCore `MessageProcessor`.
public final class MessageProcessor {
    /// The root state model holding all active surfaces.
    public let model: SurfaceGroupModel

    private let catalogs: [Catalog]

    /// Creates a new message processor.
    ///
    /// - Parameters:
    ///   - catalogs: The list of available catalogs.
    ///   - actionHandler: An optional global listener for actions from all surfaces.
    public init(
        catalogs: [Catalog],
        actionHandler: ((A2uiClientAction) -> Void)? = nil
    ) {
        self.catalogs = catalogs
        self.model = SurfaceGroupModel()
        if let handler = actionHandler {
            model.onAction.subscribe(handler)
        }
    }

    // MARK: - Subscription helpers (mirrors TS onSurfaceCreated / onSurfaceDeleted)

    /// Subscribes to surface creation events.
    @discardableResult
    public func onSurfaceCreated(_ handler: @escaping (SurfaceModel) -> Void) -> Subscription {
        model.onSurfaceCreated.subscribe(handler)
    }

    /// Subscribes to surface deletion events.
    @discardableResult
    public func onSurfaceDeleted(_ handler: @escaping (String) -> Void) -> Subscription {
        model.onSurfaceDeleted.subscribe(handler)
    }

    // MARK: - Client Data Model

    /// Returns the aggregated data model for all surfaces with `sendDataModel == true`.
    /// Returns `nil` if no such surfaces exist.
    public func getClientDataModel() -> A2uiClientDataModel? {
        var surfaces: [String: AnyCodable] = [:]
        for surface in model.surfacesMap.values where surface.sendDataModel {
            surfaces[surface.id] = surface.dataModel.get("/")
        }
        guard !surfaces.isEmpty else { return nil }
        return A2uiClientDataModel(version: "v1.0", surfaces: surfaces)
    }

    /// Returns the client capabilities for this renderer, populated from the loaded catalogs.
    /// Include this value as `a2uiClientCapabilities` in transport metadata with every
    /// outgoing message, per spec §823-838.
    ///
    /// Example (in your send callback):
    /// ```swift
    /// let capabilities = processor.clientCapabilities
    /// // Attach to your A2A/HTTP transport metadata
    /// ```
    public var clientCapabilities: A2uiClientCapabilities {
        A2uiClientCapabilities.make(from: catalogs)
    }

    // MARK: - Path Resolution

    /// Resolves a path relative to an optional context path.
    /// Absolute paths pass through unchanged; relative paths are joined with contextPath.
    /// Mirrors WebCore `resolvePath(path, contextPath?)`.
    public func resolvePath(_ path: String, contextPath: String? = nil) -> String {
        if path.hasPrefix("/") { return path }
        if let context = contextPath {
            let base = context.hasSuffix("/") ? context : "\(context)/"
            return "\(base)\(path)"
        }
        return "/\(path)"
    }

    // MARK: - Message Processing

    /// Processes a list of A2UI server-to-client messages in order.
    /// Per spec §76-82: if one message fails, logs the error and continues with the rest.
    /// Returns any errors that occurred during processing (empty if all succeeded).
    @discardableResult
    public func processMessages(_ messages: [A2uiMessage]) -> [Error] {
        var errors: [Error] = []
        for message in messages {
            do {
                try processMessage(message)
            } catch {
                errors.append(error)
            }
        }
        return errors
    }

    private func processMessage(_ message: A2uiMessage) throws {
        switch message {
        case .createSurface(let payload):
            try processCreateSurface(payload)
        case .updateComponents(let payload):
            try processUpdateComponents(payload)
        case .updateDataModel(let payload):
            try processUpdateDataModel(payload)
        case .deleteSurface(let payload):
            processDeleteSurface(payload)
        case .callFunction(let payload):
            try processCallFunction(payload)
        case .actionResponse(let payload):
            processActionResponse(payload)
        }
    }

    // MARK: - Handlers

    private func processCreateSurface(_ payload: CreateSurfacePayload) throws {
        guard let catalog = catalogs.first(where: { $0.id == payload.catalogId }) else {
            throw A2uiStateError("Catalog not found: \(payload.catalogId)")
        }

        if model.getSurface(payload.surfaceId) != nil {
            throw A2uiStateError("Surface \(payload.surfaceId) already exists.")
        }

        let surface = SurfaceModel(
            id: payload.surfaceId,
            catalog: catalog,
            surfaceProperties: payload.surfaceProperties,
            sendDataModel: payload.sendDataModel
        )
        model.addSurface(surface)

        // v1.0: inline createSurface — apply initial dataModel before components
        // so that data bindings in components can resolve during tree construction.
        if let initialData = payload.dataModel {
            try surface.dataModel.set("/", value: initialData)
        }

        // v1.0: inline createSurface — apply initial components.
        if let components = payload.components, !components.isEmpty {
            try processUpdateComponents(UpdateComponentsPayload(
                surfaceId: payload.surfaceId,
                components: components
            ))
        }
    }

    private func processDeleteSurface(_ payload: DeleteSurfacePayload) {
        model.deleteSurface(payload.surfaceId)
    }

    private func processUpdateComponents(_ payload: UpdateComponentsPayload) throws {
        guard let surface = model.getSurface(payload.surfaceId) else {
            throw A2uiStateError("Surface not found for message: \(payload.surfaceId)")
        }

        for rawComp in payload.components {
            let id = rawComp.id
            let componentType = rawComp.component
            let properties = rawComp.properties

            if let existing = surface.componentsModel.get(id) {
                if !componentType.isEmpty && componentType != existing.type {
                    // Type changed — remove old, create new
                    surface.componentsModel.removeComponent(id)
                    let newComp = ComponentModel(id: id, type: componentType, properties: properties)
                    try surface.componentsModel.addComponent(newComp)
                } else {
                    // Same type — update properties
                    existing.properties = properties
                }
            } else {
                // New component
                if componentType.isEmpty {
                    throw A2uiValidationError("Cannot create component \(id) without a type.")
                }
                let newComp = ComponentModel(id: id, type: componentType, properties: properties)
                try surface.componentsModel.addComponent(newComp)
            }
        }

        // Per spec §179: warn if surface has components but no root yet.
        // Root may arrive in a later message, so this is a warning only (not an error).
        if surface.componentsModel.get("root") == nil {
            surface.dispatchError(
                code: "VALIDATION_FAILED",
                message: "Surface '\(payload.surfaceId)' has no root component yet. Rendering will be deferred until a component with id=\"root\" is received.",
                path: "/updateComponents/components"
            )
        }
    }

    private func processUpdateDataModel(_ payload: UpdateDataModelPayload) throws {
        guard let surface = model.getSurface(payload.surfaceId) else {
            throw A2uiStateError("Surface not found for message: \(payload.surfaceId)")
        }

        let path = payload.path ?? "/"
        try surface.dataModel.set(path, value: payload.value)
    }

    // MARK: - v1.0 Handlers

    /// v1.0: Processes a server-initiated function call.
    /// Looks up the function in the catalog, executes it, and emits a `functionResponse`
    /// if `wantResponse` is true.
    /// Rejects calls to unregistered functions with an error.
    private func processCallFunction(_ payload: CallFunctionPayload) throws {
        let functionName = payload.call.call

        // Find the catalog that owns this function. Use the first loaded catalog that has it.
        guard let catalog = catalogs.first(where: { $0.functions[functionName] != nil }) else {
            // Emit error via first surface, or as a stand-alone function error.
            if let surface = model.surfacesMap.values.first {
                surface.dispatchError(
                    code: "INVALID_FUNCTION_CALL",
                    message: "Function '\(functionName)' not found in any loaded catalog.",
                    details: ["functionCallId": .string(payload.functionCallId)]
                )
            }
            return
        }

        // Use the first available surface to build a DataContext.
        // Functions called remotely have no inherent surface binding; the first
        // surface's context is used as a best-effort execution environment.
        let surface = model.surfacesMap.values.first
        let context = surface.map { DataContext(surface: $0, path: "/") }

        let result: AnyCodable?
        do {
            if let context = context, let fn = catalog.functions[functionName] {
                result = try fn(functionName, payload.call.args, context)
            } else {
                throw A2uiExpressionError("No DataContext available for remote function call", expression: functionName)
            }
        } catch {
            surface?.dispatchError(
                code: "FUNCTION_EXECUTION_ERROR",
                message: "Error executing function '\(functionName)': \(error.localizedDescription)",
                details: ["functionCallId": .string(payload.functionCallId)]
            )
            if payload.wantResponse {
                model.emitFunctionResponse(A2uiFunctionResponse(
                    functionCallId: payload.functionCallId,
                    call: functionName,
                    value: .string(error.localizedDescription)
                ))
            }
            return
        }

        if payload.wantResponse {
            model.emitFunctionResponse(A2uiFunctionResponse(
                functionCallId: payload.functionCallId,
                call: functionName,
                value: result ?? .null
            ))
        }
    }

    /// v1.0: Routes an `actionResponse` to the surface that originated the action.
    /// The surface is looked up via the `actionId` prefix (surfaceId is embedded
    /// in the action when dispatched). Since the spec doesn't include surfaceId in
    /// `actionResponse`, we route to the surface that has a matching pending action.
    private func processActionResponse(_ payload: ActionResponsePayload) {
        // Route the response to all surfaces; each surface ignores actionIds not in its queue.
        for surface in model.surfacesMap.values {
            surface.deliverActionResponse(payload)
        }
    }
}
