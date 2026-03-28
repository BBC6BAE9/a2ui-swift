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

// MARK: - AnyCodable

/// A type-erased `Codable` wrapper that can hold any JSON-compatible value.
///
/// Used wherever the Dart source uses `Map<String, Object?>` or `Object?` to
/// represent arbitrary JSON payloads (e.g. extension metadata, data parts).
///
/// Supports: `nil`, `Bool`, `Int`, `Double`, `String`, `[AnyCodable]`,
/// `[String: AnyCodable]`.
public struct AnyCodable: Codable, @unchecked Sendable, Equatable, CustomStringConvertible {

    /// The underlying value.
    ///
    /// Uses `@unchecked Sendable` because the value is restricted to
    /// JSON-compatible types (`nil`, `Bool`, `Int`, `Double`, `String`,
    /// `[Any?]`, `[String: Any?]`) which are all value types and inherently
    /// safe to share across concurrency boundaries.
    public let value: Any?

    // MARK: - Initialisation

    public init(_ value: Any?) {
        self.value = value
    }

    // MARK: - Decodable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = nil
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable cannot decode value"
            )
        }
    }

    // MARK: - Encodable

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case nil:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any?]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any?]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value as Any,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable cannot encode value of type \(type(of: value))"
                )
            )
        }
    }

    // MARK: - Equatable

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (nil, nil):
            return true
        case (let l as Bool, let r as Bool):
            return l == r
        case (let l as Int, let r as Int):
            return l == r
        case (let l as Double, let r as Double):
            return l == r
        case (let l as String, let r as String):
            return l == r
        case (let l as [Any?], let r as [Any?]):
            return l.map { AnyCodable($0) } == r.map { AnyCodable($0) }
        case (let l as [String: Any?], let r as [String: Any?]):
            return l.mapValues { AnyCodable($0) } == r.mapValues { AnyCodable($0) }
        default:
            return false
        }
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        if let value {
            return String(describing: value)
        }
        return "nil"
    }
}

// MARK: - Convenience type aliases

/// A JSON object with arbitrary values, mirroring Dart `Map<String, Object?>`.
public typealias JSONObject = [String: AnyCodable]
