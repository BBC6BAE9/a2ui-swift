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

// MARK: - StringValue

/// A value that can be either a literal string or a path to the data model.
/// v0.8 format: `{"literalString":"..."}` or `{"path":"..."}`.
public struct StringValue {
    public var path: String?
    public var literalString: String?
    public var literal: String?

    public init(path: String? = nil, literalString: String? = nil, literal: String? = nil) {
        self.path = path
        self.literalString = literalString
        self.literal = literal
    }

    public var literalValue: String? {
        literalString ?? literal
    }
}

extension StringValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case path, literalString, literal
    }

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        switch raw {
        case .string(let s):
            self.path = nil
            self.literalString = s
            self.literal = nil
        case .dictionary(let dict):
            self.path = dict["path"]?.stringValue
            self.literalString = dict["literalString"]?.stringValue
            self.literal = dict["literal"]?.stringValue
        default:
            self.path = nil
            self.literalString = nil
            self.literal = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(path, forKey: .path)
        try container.encodeIfPresent(literalString, forKey: .literalString)
        try container.encodeIfPresent(literal, forKey: .literal)
    }
}

// MARK: - NumberValue

/// A value that can be either a literal number or a path to the data model.
/// v0.8 format: `{"literalNumber":42}` or `{"path":"..."}`.
public struct NumberValue {
    public var path: String?
    public var literalNumber: Double?
    public var literal: Double?

    public var literalValue: Double? {
        literalNumber ?? literal
    }
}

extension NumberValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case path, literalNumber, literal
    }

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        switch raw {
        case .number(let n):
            self.path = nil
            self.literalNumber = n
            self.literal = nil
        case .dictionary(let dict):
            self.path = dict["path"]?.stringValue
            self.literalNumber = dict["literalNumber"]?.numberValue
            self.literal = dict["literal"]?.numberValue
        default:
            self.path = nil
            self.literalNumber = nil
            self.literal = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(path, forKey: .path)
        try container.encodeIfPresent(literalNumber, forKey: .literalNumber)
        try container.encodeIfPresent(literal, forKey: .literal)
    }
}

// MARK: - BooleanValue

/// A value that can be either a literal boolean or a path to the data model.
/// v0.8 format: `{"literalBoolean":true}` or `{"path":"..."}`.
public struct BooleanValue {
    public var path: String?
    public var literalBoolean: Bool?
    public var literal: Bool?

    public var literalValue: Bool? {
        literalBoolean ?? literal
    }
}

extension BooleanValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case path, literalBoolean, literal
    }

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        switch raw {
        case .bool(let b):
            self.path = nil
            self.literalBoolean = b
            self.literal = nil
        case .dictionary(let dict):
            self.path = dict["path"]?.stringValue
            self.literalBoolean = dict["literalBoolean"]?.boolValue
            self.literal = dict["literal"]?.boolValue
        default:
            self.path = nil
            self.literalBoolean = nil
            self.literal = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(path, forKey: .path)
        try container.encodeIfPresent(literalBoolean, forKey: .literalBoolean)
        try container.encodeIfPresent(literal, forKey: .literal)
    }
}

// MARK: - BoundValue

/// A general bound value that can hold any literal type or a path reference.
/// Used in action context entries.
public struct BoundValue: Codable {
    public var path: String?
    public var literalString: String?
    public var literalNumber: Double?
    public var literalBoolean: Bool?
}

// MARK: - ValueMapEntry

/// An entry in the data model update's `contents` array (v0.8).
/// Uses `key` + one of the `value*` fields.
public struct ValueMapEntry: Codable {
    public var key: String
    public var valueString: String?
    public var valueNumber: Double?
    public var valueBoolean: Bool?
    public var valueBool: Bool?
    public var valueMap: [ValueMapEntry]?
}
