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

// MARK: - SurfaceModel

/// The state model for a single UI surface.
/// Owns a DataModel and a SurfaceComponentsModel.
/// Coordinates action/error dispatching back to the server.
/// Mirrors WebCore `SurfaceModel`.
public final class SurfaceModel: Identifiable {
    public let id: String
    public let catalogId: String
    /// The catalog this surface was created with. Used by DataContext for function invocation.
    public let catalog: Catalog
    /// v1.0: surface properties parsed from `createSurface.surfaceProperties` (replaces `theme`).
    /// The legacy `theme` field is accepted for backward compatibility with v0.9 messages.
    public let surfaceProperties: AnyCodable?
    public let sendDataModel: Bool
    /// The locale to use in locale-sensitive functions (BCP 47, e.g. "en-US", "pl", "ar").
    /// When nil, functions fall back to the client's current locale.
    /// Mirrors WebCore `SurfaceModel.locale`.
    public let locale: String?

    public let dataModel: DataModel
    public let componentsModel: SurfaceComponentsModel

    private let _onAction = EventEmitter<A2uiClientAction>()
    private let _onError = EventEmitter<A2uiClientError>()
    /// v1.0: fires when an `actionResponse` message arrives for an action from this surface.
    private let _onActionResponse = EventEmitter<ActionResponsePayload>()

    /// Fires whenever an action is dispatched from this surface.
    /// Mirrors WebCore `onAction: EventSource<A2uiClientAction>`.
    public var onAction: some EventSource<A2uiClientAction> { _onAction }

    /// Fires whenever an error occurs on this surface.
    /// Mirrors WebCore `onError: EventSource<any>`.
    public var onError: some EventSource<A2uiClientError> { _onError }

    /// v1.0: fires whenever an `actionResponse` is received for this surface.
    public var onActionResponse: some EventSource<ActionResponsePayload> { _onActionResponse }

    private var disposed = false

    // MARK: - Init

    /// Creates a surface using a Catalog reference (preferred, used by MessageProcessor).
    public init(
        id: String,
        catalog: Catalog,
        surfaceProperties: AnyCodable? = nil,
        sendDataModel: Bool = false,
        locale: String? = nil
    ) {
        self.id = id
        self.catalog = catalog
        self.catalogId = catalog.id
        self.surfaceProperties = surfaceProperties
        self.sendDataModel = sendDataModel
        self.locale = locale
        self.dataModel = DataModel()
        self.componentsModel = SurfaceComponentsModel()
    }

    /// Creates a surface by catalog ID only (used in tests / legacy paths that don't have a catalog object).
    public convenience init(
        id: String,
        catalogId: String = "",
        surfaceProperties: AnyCodable? = nil,
        sendDataModel: Bool = false,
        locale: String? = nil
    ) {
        self.init(
            id: id,
            catalog: Catalog(id: catalogId),
            surfaceProperties: surfaceProperties,
            sendDataModel: sendDataModel,
            locale: locale
        )
    }

    // MARK: - Action dispatch

    /// Dispatches a resolved action from a component.
    /// Mirrors WebCore `surface.dispatchAction(payload, sourceComponentId)`:
    /// expects context values to already be resolved to plain AnyCodable by the
    /// renderer (via DataContext.resolveAction) before calling this method.
    /// Validates the payload via A2uiClientActionSchema equivalent and emits on onAction.
    public func dispatchAction(
        name: String,
        sourceComponentId: String,
        context: [String: AnyCodable] = [:],
        wantResponse: Bool = false,
        actionId: String? = nil
    ) {
        guard !disposed else { return }
        let action = A2uiClientAction(
            name: name,
            surfaceId: id,
            sourceComponentId: sourceComponentId,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            context: context,
            wantResponse: wantResponse,
            actionId: actionId
        )
        _onAction.emit(action)
    }

    // MARK: - Error dispatch

    /// Dispatches an error from this surface.
    public func dispatchError(
        code: String,
        message: String,
        path: String? = nil,
        details: [String: AnyCodable]? = nil
    ) {
        guard !disposed else { return }
        let error = A2uiClientError(
            code: code,
            surfaceId: id,
            message: message,
            path: path,
            details: details
        )
        _onError.emit(error)
    }

    // MARK: - Action Response (v1.0)

    /// Delivers an `actionResponse` from the server to any listeners on this surface.
    /// Mirrors WebCore `surface.handleActionResponse(payload)`.
    public func deliverActionResponse(_ payload: ActionResponsePayload) {
        guard !disposed else { return }
        _onActionResponse.emit(payload)
    }

    // MARK: - Dispose

    /// Clears all state and stops dispatching.
    public func dispose() {
        disposed = true
        _onAction.dispose()
        _onError.dispose()
        _onActionResponse.dispose()
        dataModel.dispose()
        componentsModel.dispose()
    }
}
