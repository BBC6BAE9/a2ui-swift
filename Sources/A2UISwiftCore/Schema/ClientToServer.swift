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

// Mirrors WebCore schema/client-to-server.ts

// MARK: - A2uiClientAction

/// Reports a user-initiated action from a component.
/// Matches 'action' in specification/v0_9/json/client_to_server.json.
/// Mirrors WebCore `A2uiClientAction`.
public struct A2uiClientAction: Codable, Equatable {
    /// The name of the action, taken from the component's action.event.name property.
    public let name: String
    /// The id of the surface where the event originated.
    public let surfaceId: String
    /// The id of the component that triggered the event.
    public let sourceComponentId: String
    /// An ISO 8601 timestamp of when the event occurred.
    public let timestamp: String
    /// Key-value pairs from the component's action.event.context, after resolving all data bindings.
    public let context: [String: AnyCodable]

    public init(
        name: String,
        surfaceId: String,
        sourceComponentId: String,
        timestamp: String = ISO8601DateFormatter().string(from: Date()),
        context: [String: AnyCodable] = [:]
    ) {
        self.name = name
        self.surfaceId = surfaceId
        self.sourceComponentId = sourceComponentId
        self.timestamp = timestamp
        self.context = context
    }
}

// MARK: - A2uiClientError

/// Reports a client-side error.
/// Matches 'error' in specification/v0_9/json/client_to_server.json.
/// Mirrors WebCore `A2uiClientError`.
public struct A2uiClientError: Codable, Equatable {
    /// Error code. "VALIDATION_FAILED" for validation errors; other strings for generic errors.
    public let code: String
    /// The id of the surface where the error occurred.
    public let surfaceId: String
    /// A short description of why the error occurred.
    public let message: String
    /// For VALIDATION_FAILED: JSON pointer to the field that failed (e.g. '/components/0/text').
    public let path: String?
    /// Optional additional details about the error.
    public let details: [String: AnyCodable]?

    public init(
        code: String,
        surfaceId: String,
        message: String,
        path: String? = nil,
        details: [String: AnyCodable]? = nil
    ) {
        self.code = code
        self.surfaceId = surfaceId
        self.message = message
        self.path = path
        self.details = details
    }
}

// MARK: - A2uiClientMessage

/// A message sent from the A2UI client to the server.
/// Matches specification/v0_9/json/client_to_server.json.
/// Mirrors WebCore `A2uiClientMessage`.
public enum A2uiClientMessage: Codable {
    case action(A2uiClientAction)
    case error(A2uiClientError)

    private enum CodingKeys: String, CodingKey {
        case version, action, error
    }

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        guard case .dictionary(let dict) = raw else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "A2uiClientMessage must be a JSON object."
            ))
        }

        let allowedKeys: Set<String> = ["version", "action", "error"]
        let extraKeys = Set(dict.keys).subtracting(allowedKeys)
        guard extraKeys.isEmpty else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "A2uiClientMessage contains unsupported properties: \(extraKeys.sorted().joined(separator: ", "))."
            ))
        }

        guard dict["version"]?.stringValue == "v0.9" else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "A2uiClientMessage version must be 'v0.9'."
            ))
        }

        let data = try JSONEncoder().encode(raw)
        let container = try JSONDecoder().decode(DecodedMessage.self, from: data)
        let hasAction = container.action != nil
        let hasError = container.error != nil
        guard hasAction != hasError else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "A2uiClientMessage must contain exactly one of 'action' or 'error'."
            ))
        }

        if let action = container.action {
            self = .action(action)
        } else if let error = container.error {
            self = .error(error)
        } else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "A2uiClientMessage must contain 'action' or 'error'."
            ))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("v0.9", forKey: .version)
        switch self {
        case .action(let a): try container.encode(a, forKey: .action)
        case .error(let e): try container.encode(e, forKey: .error)
        }
    }

    private struct DecodedMessage: Codable {
        let version: String
        let action: A2uiClientAction?
        let error: A2uiClientError?
    }
}

// MARK: - A2uiClientDataModel

/// Schema for the client data model synchronization.
/// Matches specification/v0_9/json/client_data_model.json.
/// Mirrors WebCore `A2uiClientDataModel`.
public struct A2uiClientDataModel: Codable, Equatable {
    public let version: String
    /// A map of surface IDs to their current data models.
    public let surfaces: [String: AnyCodable]

    public init(version: String = "v0.9", surfaces: [String: AnyCodable]) {
        self.version = version
        self.surfaces = surfaces
    }
}
