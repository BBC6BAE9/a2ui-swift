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
/// Encoding always includes `"version":"v0.9"`.
public enum A2uiMessage: Codable, Sendable {
    case createSurface(CreateSurfacePayload)
    case updateComponents(UpdateComponentsPayload)
    case updateDataModel(UpdateDataModelPayload)
    case deleteSurface(DeleteSurfacePayload)

    private enum CodingKeys: String, CodingKey {
        case version
        case createSurface
        case updateComponents
        case updateDataModel
        case deleteSurface

        var stringValue: String { rawValue }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let version = try container.decode(String.self, forKey: .version)
        guard version == "v0.9" else {
            throw DecodingError.dataCorruptedError(
                forKey: .version,
                in: container,
                debugDescription: #"A2UI message version must be "v0.9"."#
            )
        }

        // Validate: only one update-type key is allowed per message.
        let updateTypeKeys: [CodingKeys] = [.createSurface, .updateComponents, .updateDataModel, .deleteSurface]
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
        } else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Message must contain one of: createSurface, updateComponents, updateDataModel, deleteSurface."
            ))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("v0.9", forKey: .version)
        switch self {
        case .createSurface(let payload):   try container.encode(payload, forKey: .createSurface)
        case .updateComponents(let payload): try container.encode(payload, forKey: .updateComponents)
        case .updateDataModel(let payload): try container.encode(payload, forKey: .updateDataModel)
        case .deleteSurface(let payload):   try container.encode(payload, forKey: .deleteSurface)
        }
    }
}

// MARK: - Payloads

public struct CreateSurfacePayload: Codable, Sendable {
    public var surfaceId: String
    public var catalogId: String
    public var theme: AnyCodable?
    public var sendDataModel: Bool

    public init(
        surfaceId: String,
        catalogId: String,
        theme: AnyCodable? = nil,
        sendDataModel: Bool = false
    ) {
        self.surfaceId = surfaceId
        self.catalogId = catalogId
        self.theme = theme
        self.sendDataModel = sendDataModel
    }

    private enum CodingKeys: String, CodingKey {
        case surfaceId, catalogId, theme, sendDataModel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        surfaceId = try container.decode(String.self, forKey: .surfaceId)
        catalogId = try container.decode(String.self, forKey: .catalogId)
        theme = try container.decodeIfPresent(AnyCodable.self, forKey: .theme)
        sendDataModel = try container.decodeIfPresent(Bool.self, forKey: .sendDataModel) ?? false
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
public struct RawComponent: Sendable {
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
