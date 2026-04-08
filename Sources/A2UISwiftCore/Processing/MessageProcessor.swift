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
        return A2uiClientDataModel(version: "v0.9", surfaces: surfaces)
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
            theme: payload.theme,
            sendDataModel: payload.sendDataModel
        )
        model.addSurface(surface)
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
}
