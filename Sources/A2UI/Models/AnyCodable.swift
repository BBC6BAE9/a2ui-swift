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

/// A type-erased Codable value for handling dynamic JSON structures.
/// Supports: String, Double, Bool, nil, Array, Dictionary.
public enum AnyCodable: Codable, CustomStringConvertible, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([AnyCodable])
    case dictionary([String: AnyCodable])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode([AnyCodable].self) {
            self = .array(value)
            return
        }
        if let value = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(value)
            return
        }

        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "Cannot decode AnyCodable")
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .dictionary(let value): try container.encode(value)
        }
    }

    /// Convenience accessors
    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    public var numberValue: Double? {
        if case .number(let v) = self { return v }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    public var arrayValue: [AnyCodable]? {
        if case .array(let v) = self { return v }
        return nil
    }

    public var dictionaryValue: [String: AnyCodable]? {
        if case .dictionary(let v) = self { return v }
        return nil
    }

    public var description: String {
        switch self {
        case .string(let v): return "\"\(v)\""
        case .number(let v): return "\(v)"
        case .bool(let v): return "\(v)"
        case .null: return "null"
        case .array(let v): return "\(v)"
        case .dictionary(let v): return "\(v)"
        }
    }
}
