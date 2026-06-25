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

// MARK: - A2uiMessage

/// A discriminated-union message from the A2UI server to the client.
/// Mirrors WebCore `A2uiMessage`.
///
/// Each case maps to one top-level JSON key.
/// Encoding defaults to `"version":"v1.0"`.
public enum A2uiMessage: Codable, Sendable {
    case createSurface(CreateSurfacePayload)
    case updateComponents(UpdateComponentsPayload)
    case updateDataModel(UpdateDataModelPayload)
    case deleteSurface(DeleteSurfacePayload)
    /// v1.0: server-initiated function call to a client-registered function.
    case callFunction(CallFunctionPayload)
    /// v1.0: server response to a client action that had `wantResponse: true`.
    case actionResponse(ActionResponsePayload)

    private enum CodingKeys: String, CodingKey {
        case version
        case createSurface
        case updateComponents
        case updateDataModel
        case deleteSurface
        case callFunction
        case actionResponse
        case actionId
        case functionCallId
        case wantResponse

        var stringValue: String { rawValue }
    }

    /// Accepted protocol version strings. v0.9 / v0.9.1 are backward-compatible
    /// refinements; v1.0 is the current release candidate.
    public static let acceptedVersions: Set<String> = ["v0.9", "v0.9.1", "v1.0"]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let version = try container.decode(String.self, forKey: .version)
        guard Self.acceptedVersions.contains(version) else {
            throw DecodingError.dataCorruptedError(
                forKey: .version,
                in: container,
                debugDescription: #"A2UI message version must be "v0.9", "v0.9.1", or "v1.0"."#
            )
        }

        // Validate: only one update-type key is allowed per message.
        let updateTypeKeys: [CodingKeys] = [
            .createSurface, .updateComponents, .updateDataModel,
            .deleteSurface, .callFunction, .actionResponse
        ]
        let presentKeys = updateTypeKeys.filter { container.contains($0) }
        if presentKeys.count > 1 {
            let names = presentKeys.map(\.stringValue).joined(separator: ", ")
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Message contains multiple update types: \(names)."
            ))
        }

        if let payload = try container.decodeIfPresent(CreateSurfacePayload.self, forKey: .createSurface) {
            self = .createSurface(payload)
        } else if let payload = try container.decodeIfPresent(UpdateComponentsPayload.self, forKey: .updateComponents) {
            self = .updateComponents(payload)
        } else if let payload = try container.decodeIfPresent(UpdateDataModelPayload.self, forKey: .updateDataModel) {
            self = .updateDataModel(payload)
        } else if let payload = try container.decodeIfPresent(DeleteSurfacePayload.self, forKey: .deleteSurface) {
            self = .deleteSurface(payload)
        } else if container.contains(.callFunction) {
            let functionCallId = try container.decode(String.self, forKey: .functionCallId)
            let wantResponse = try container.decodeIfPresent(Bool.self, forKey: .wantResponse) ?? false
            let callPayload = try container.decode(FunctionCall.self, forKey: .callFunction)
            self = .callFunction(CallFunctionPayload(
                functionCallId: functionCallId,
                wantResponse: wantResponse,
                call: callPayload
            ))
        } else if container.contains(.actionResponse) {
            let actionId = try container.decode(String.self, forKey: .actionId)
            let responsePayload = try container.decode(ActionResponsePayload.self, forKey: .actionResponse)
            var payload = responsePayload
            payload.actionId = actionId
            self = .actionResponse(payload)
        } else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Message must contain one of: createSurface, updateComponents, updateDataModel, deleteSurface, callFunction, actionResponse."
            ))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("v1.0", forKey: .version)
        switch self {
        case .createSurface(let payload):    try container.encode(payload, forKey: .createSurface)
        case .updateComponents(let payload): try container.encode(payload, forKey: .updateComponents)
        case .updateDataModel(let payload):  try container.encode(payload, forKey: .updateDataModel)
        case .deleteSurface(let payload):    try container.encode(payload, forKey: .deleteSurface)
        case .callFunction(let payload):
            try container.encode(payload.functionCallId, forKey: .functionCallId)
            try container.encode(payload.wantResponse, forKey: .wantResponse)
            try container.encode(payload.call, forKey: .callFunction)
        case .actionResponse(let payload):
            try container.encode(payload.actionId, forKey: .actionId)
            try container.encode(payload, forKey: .actionResponse)
        }
    }
}

// MARK: - Payloads

public struct CreateSurfacePayload: Codable, Sendable {
    public var surfaceId: String
    public var catalogId: String
    /// v1.0: replaces `theme`. Accepts both `surfaceProperties` (v1.0) and
    /// `theme` (v0.9/v0.9.1) for backward compatibility, preferring `surfaceProperties`.
    public var surfaceProperties: AnyCodable?
    public var sendDataModel: Bool
    /// v1.0: optional initial component definitions included in the create payload.
    public var components: [RawComponent]?
    /// v1.0: optional initial data model included in the create payload.
    public var dataModel: AnyCodable?

    public init(
        surfaceId: String,
        catalogId: String,
        surfaceProperties: AnyCodable? = nil,
        sendDataModel: Bool = false,
        components: [RawComponent]? = nil,
        dataModel: AnyCodable? = nil
    ) {
        self.surfaceId = surfaceId
        self.catalogId = catalogId
        self.surfaceProperties = surfaceProperties
        self.sendDataModel = sendDataModel
        self.components = components
        self.dataModel = dataModel
    }

    private enum CodingKeys: String, CodingKey {
        case surfaceId, catalogId, surfaceProperties, theme, sendDataModel, components, dataModel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        surfaceId = try container.decode(String.self, forKey: .surfaceId)
        catalogId = try container.decode(String.self, forKey: .catalogId)
        // Accept both v1.0 `surfaceProperties` and v0.9 `theme` (prefer v1.0).
        surfaceProperties = try container.decodeIfPresent(AnyCodable.self, forKey: .surfaceProperties)
            ?? container.decodeIfPresent(AnyCodable.self, forKey: .theme)
        sendDataModel = try container.decodeIfPresent(Bool.self, forKey: .sendDataModel) ?? false
        components = try container.decodeIfPresent([RawComponent].self, forKey: .components)
        dataModel = try container.decodeIfPresent(AnyCodable.self, forKey: .dataModel)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(surfaceId, forKey: .surfaceId)
        try container.encode(catalogId, forKey: .catalogId)
        try container.encodeIfPresent(surfaceProperties, forKey: .surfaceProperties)
        try container.encode(sendDataModel, forKey: .sendDataModel)
        try container.encodeIfPresent(components, forKey: .components)
        try container.encodeIfPresent(dataModel, forKey: .dataModel)
    }
}

public struct UpdateComponentsPayload: Codable, Sendable {
    public var surfaceId: String
    public var components: [RawComponent]

    public init(surfaceId: String, components: [RawComponent]) {
        self.surfaceId = surfaceId
        self.components = components
    }
}

public struct UpdateDataModelPayload: Codable, Sendable {
    public var surfaceId: String
    public var path: String?
    public var value: AnyCodable?

    public init(surfaceId: String, path: String? = nil, value: AnyCodable? = nil) {
        self.surfaceId = surfaceId
        self.path = path
        self.value = value
    }
}

public struct DeleteSurfacePayload: Codable, Sendable {
    public var surfaceId: String

    public init(surfaceId: String) {
        self.surfaceId = surfaceId
    }
}

// MARK: - RawComponent

/// A raw component received in an `updateComponents` message.
/// The fixed fields `id`, `component`, `weight`, and `accessibility` are extracted;
/// all remaining keys become `properties`.
/// Mirrors WebCore `AnyComponentSchema`.
public struct RawComponent: Sendable, Equatable {
    public var id: String
    public var component: String
    public var weight: Double?
    public var accessibility: A2UIAccessibility?
    public var properties: [String: AnyCodable]

    public init(
        id: String,
        component: String,
        weight: Double? = nil,
        accessibility: A2UIAccessibility? = nil,
        properties: [String: AnyCodable] = [:]
    ) {
        self.id = id
        self.component = component
        self.weight = weight
        self.accessibility = accessibility
        self.properties = properties
    }
}

// MARK: - v1.0 New Payloads

/// v1.0: Server-initiated function call to a client-registered function.
/// Mirrors WebCore `CallFunctionMessage`.
public struct CallFunctionPayload: Sendable {
    /// Unique identifier for this function call instance. Must be echoed back in `functionResponse`.
    public var functionCallId: String
    /// If true, the client must send a `functionResponse` with the result.
    public var wantResponse: Bool
    /// The function to invoke.
    public var call: FunctionCall

    public init(functionCallId: String, wantResponse: Bool = false, call: FunctionCall) {
        self.functionCallId = functionCallId
        self.wantResponse = wantResponse
        self.call = call
    }
}

/// v1.0: Server response to a client-initiated action that specified `wantResponse: true`.
/// Mirrors WebCore `ActionResponseMessage`.
public struct ActionResponsePayload: Codable, Sendable {
    /// The `actionId` of the originating client action.
    public var actionId: String
    /// The return value of the action (mutually exclusive with `error`).
    public var value: AnyCodable?
    /// An error that occurred during the action (mutually exclusive with `value`).
    public var error: ActionResponseError?

    public init(actionId: String, value: AnyCodable? = nil, error: ActionResponseError? = nil) {
        self.actionId = actionId
        self.value = value
        self.error = error
    }

    private enum CodingKeys: String, CodingKey {
        case value, error
    }

    public init(from decoder: Decoder) throws {
        // actionId is decoded at the message level and injected separately.
        self.actionId = ""
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeIfPresent(AnyCodable.self, forKey: .value)
        error = try container.decodeIfPresent(ActionResponseError.self, forKey: .error)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(error, forKey: .error)
    }
}

/// v1.0: An error returned inside an `actionResponse`.
public struct ActionResponseError: Codable, Sendable {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

extension RawComponent: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        guard case .dictionary(var dict) = raw else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "RawComponent must be a JSON object."
            ))
        }
        // `id` is required at the Codable level; missing-type is validated in MessageProcessor.
        guard let id = dict.removeValue(forKey: "id")?.stringValue else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "RawComponent missing 'id'."
            ))
        }
        self.id = id
        // `component` is optional at decode time; MessageProcessor validates its presence for new components.
        self.component = dict.removeValue(forKey: "component")?.stringValue ?? ""
        self.weight = dict.removeValue(forKey: "weight")?.numberValue
        if let accRaw = dict.removeValue(forKey: "accessibility"),
           case .dictionary(let accDict) = accRaw {
            self.accessibility = A2UIAccessibility.decode(from: accDict)
        } else {
            self.accessibility = nil
        }
        self.properties = dict
    }

    public func encode(to encoder: Encoder) throws {
        var dict = properties
        dict["id"] = .string(id)
        dict["component"] = .string(component)
        if let w = weight { dict["weight"] = .number(w) }
        if let accDict = accessibility?.toDict() {
            dict["accessibility"] = .dictionary(accDict)
        }
        var container = encoder.singleValueContainer()
        try container.encode(dict)
    }
}
