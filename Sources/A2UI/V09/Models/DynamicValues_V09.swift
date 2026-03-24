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

// MARK: - FunctionCall_V09

/// A function call: `{"call":"funcName","args":{...},"returnType":"string"}`.
public struct FunctionCall_V09: Codable {
    public var call: String
    public var args: [String: AnyCodable]?
    public var returnType: String?

    /// Direct construction from an already-parsed dictionary (avoids encode/decode round-trip).
    public init(from dict: [String: AnyCodable]) {
        self.call = dict["call"]?.stringValue ?? ""
        if let argsDict = dict["args"]?.dictionaryValue {
            self.args = argsDict
        } else {
            self.args = nil
        }
        self.returnType = dict["returnType"]?.stringValue
    }
}

// MARK: - Shared Dynamic Value Resolution

/// Resolves the dictionary branch shared by all DynamicXxx types.
/// Returns `.dataBinding` or `.functionCall` if matched, `nil` otherwise.
enum DynamicDictResolution {
    case dataBinding(path: String)
    case functionCall(FunctionCall_V09)

    static func resolve(from dict: [String: AnyCodable]) -> DynamicDictResolution? {
        if dict["call"]?.stringValue != nil {
            return .functionCall(FunctionCall_V09(from: dict))
        }
        if let path = dict["path"]?.stringValue {
            return .dataBinding(path: path)
        }
        return nil
    }
}

// MARK: - DynamicString_V09

/// v0.9 DynamicString: string literal | DataBinding `{path}` | FunctionCall.
public enum DynamicString_V09 {
    case literal(String)
    case dataBinding(path: String)
    case functionCall(FunctionCall_V09)
}

extension DynamicString_V09: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        switch raw {
        case .string(let s):
            self = .literal(s)
        case .dictionary(let dict):
            if let resolved = DynamicDictResolution.resolve(from: dict) {
                switch resolved {
                case .dataBinding(let path): self = .dataBinding(path: path)
                case .functionCall(let fc): self = .functionCall(fc)
                }
            } else {
                self = .literal("")
            }
        default:
            self = .literal("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .literal(let s):
            var container = encoder.singleValueContainer()
            try container.encode(s)
        case .dataBinding(let path):
            var container = encoder.singleValueContainer()
            try container.encode(["path": path])
        case .functionCall(let fc):
            try fc.encode(to: encoder)
        }
    }
}

// MARK: - DynamicNumber_V09

/// v0.9 DynamicNumber: number literal | DataBinding | FunctionCall.
public enum DynamicNumber_V09 {
    case literal(Double)
    case dataBinding(path: String)
    case functionCall(FunctionCall_V09)
}

extension DynamicNumber_V09: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        switch raw {
        case .number(let n):
            self = .literal(n)
        case .dictionary(let dict):
            if let resolved = DynamicDictResolution.resolve(from: dict) {
                switch resolved {
                case .dataBinding(let path): self = .dataBinding(path: path)
                case .functionCall(let fc): self = .functionCall(fc)
                }
            } else {
                self = .literal(0)
            }
        default:
            self = .literal(0)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .literal(let n):
            var container = encoder.singleValueContainer()
            try container.encode(n)
        case .dataBinding(let path):
            var container = encoder.singleValueContainer()
            try container.encode(["path": path])
        case .functionCall(let fc):
            try fc.encode(to: encoder)
        }
    }
}

// MARK: - DynamicBoolean_V09

/// v0.9 DynamicBoolean: boolean literal | DataBinding | FunctionCall.
public enum DynamicBoolean_V09 {
    case literal(Bool)
    case dataBinding(path: String)
    case functionCall(FunctionCall_V09)
}

extension DynamicBoolean_V09: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        switch raw {
        case .bool(let b):
            self = .literal(b)
        case .dictionary(let dict):
            if let resolved = DynamicDictResolution.resolve(from: dict) {
                switch resolved {
                case .dataBinding(let path): self = .dataBinding(path: path)
                case .functionCall(let fc): self = .functionCall(fc)
                }
            } else {
                self = .literal(false)
            }
        default:
            self = .literal(false)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .literal(let b):
            var container = encoder.singleValueContainer()
            try container.encode(b)
        case .dataBinding(let path):
            var container = encoder.singleValueContainer()
            try container.encode(["path": path])
        case .functionCall(let fc):
            try fc.encode(to: encoder)
        }
    }
}

// MARK: - DynamicStringList_V09

/// v0.9 DynamicStringList: [String] literal | DataBinding | FunctionCall.
public enum DynamicStringList_V09 {
    case literal([String])
    case dataBinding(path: String)
    case functionCall(FunctionCall_V09)
}

extension DynamicStringList_V09: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        switch raw {
        case .array(let arr):
            self = .literal(arr.compactMap(\.stringValue))
        case .dictionary(let dict):
            if let resolved = DynamicDictResolution.resolve(from: dict) {
                switch resolved {
                case .dataBinding(let path): self = .dataBinding(path: path)
                case .functionCall(let fc): self = .functionCall(fc)
                }
            } else {
                self = .literal([])
            }
        default:
            self = .literal([])
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .literal(let arr):
            var container = encoder.singleValueContainer()
            try container.encode(arr)
        case .dataBinding(let path):
            var container = encoder.singleValueContainer()
            try container.encode(["path": path])
        case .functionCall(let fc):
            try fc.encode(to: encoder)
        }
    }
}

// MARK: - DynamicValue_V09

/// A general dynamic value (string | number | boolean | array | DataBinding | FunctionCall).
/// Used in action context values.
public enum DynamicValue_V09 {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([AnyCodable])
    case dataBinding(path: String)
    case functionCall(FunctionCall_V09)

    /// Direct construction from AnyCodable (avoids encode/decode round-trip).
    public init(from value: AnyCodable) {
        switch value {
        case .string(let s): self = .string(s)
        case .number(let n): self = .number(n)
        case .bool(let b): self = .bool(b)
        case .array(let arr): self = .array(arr)
        case .dictionary(let dict):
            if let resolved = DynamicDictResolution.resolve(from: dict) {
                switch resolved {
                case .dataBinding(let path): self = .dataBinding(path: path)
                case .functionCall(let fc): self = .functionCall(fc)
                }
            } else {
                self = .string("")
            }
        case .null: self = .string("")
        }
    }
}

extension DynamicValue_V09: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        switch raw {
        case .string(let s):
            self = .string(s)
        case .number(let n):
            self = .number(n)
        case .bool(let b):
            self = .bool(b)
        case .array(let arr):
            self = .array(arr)
        case .dictionary(let dict):
            if let resolved = DynamicDictResolution.resolve(from: dict) {
                switch resolved {
                case .dataBinding(let path): self = .dataBinding(path: path)
                case .functionCall(let fc): self = .functionCall(fc)
                }
            } else {
                self = .string("")
            }
        case .null:
            self = .string("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let s):
            var c = encoder.singleValueContainer()
            try c.encode(s)
        case .number(let n):
            var c = encoder.singleValueContainer()
            try c.encode(n)
        case .bool(let b):
            var c = encoder.singleValueContainer()
            try c.encode(b)
        case .array(let arr):
            var c = encoder.singleValueContainer()
            try c.encode(arr)
        case .dataBinding(let path):
            var c = encoder.singleValueContainer()
            try c.encode(["path": path])
        case .functionCall(let fc):
            try fc.encode(to: encoder)
        }
    }
}

// MARK: - CheckRule_V09

/// A validation rule: `{"condition": DynamicBoolean, "message": "..."}`.
public struct CheckRule_V09: Codable {
    public var condition: DynamicBoolean_V09
    public var message: String
}

// MARK: - Action_V09

/// v0.9 action: either a server event or a client-side function call.
/// Event: `{"event": {"name":"tap", "context":{...}}}`.
/// FunctionCall: `{"functionCall": {"call":"openUrl", "args":{...}}}`.
public enum Action_V09 {
    case event(name: String, context: [String: DynamicValue_V09]?)
    case functionCall(FunctionCall_V09)
}

extension Action_V09: Codable {
    private enum TopKeys: String, CodingKey {
        case event, functionCall
    }

    private enum EventKeys: String, CodingKey {
        case name, context
    }

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        guard case .dictionary(let dict) = raw else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Action_V09 must be an object")
            )
        }

        if let eventDict = dict["event"]?.dictionaryValue,
           let name = eventDict["name"]?.stringValue {
            var ctx: [String: DynamicValue_V09]?
            if let ctxDict = eventDict["context"]?.dictionaryValue {
                var result: [String: DynamicValue_V09] = [:]
                for (key, value) in ctxDict {
                    result[key] = DynamicValue_V09(from: value)
                }
                ctx = result
            }
            self = .event(name: name, context: ctx)
        } else if let fcDict = dict["functionCall"]?.dictionaryValue {
            self = .functionCall(FunctionCall_V09(from: fcDict))
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Action_V09: expected 'event' or 'functionCall'")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TopKeys.self)
        switch self {
        case .event(let name, let context):
            var eventContainer = container.nestedContainer(keyedBy: EventKeys.self, forKey: .event)
            try eventContainer.encode(name, forKey: .name)
            try eventContainer.encodeIfPresent(context, forKey: .context)
        case .functionCall(let fc):
            try container.encode(fc, forKey: .functionCall)
        }
    }
}

// MARK: - ChildList_V09

/// v0.9 ChildList: `[ComponentId]` (static) or `{"componentId":"id","path":"/items"}` (template).
public enum ChildList_V09 {
    case staticList([String])
    case template(componentId: String, path: String)
}

extension ChildList_V09: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        switch raw {
        case .array(let items):
            self = .staticList(items.compactMap(\.stringValue))
        case .dictionary(let dict):
            guard let componentId = dict["componentId"]?.stringValue,
                  let path = dict["path"]?.stringValue else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath,
                          debugDescription: "ChildList_V09 template requires 'componentId' and 'path'")
                )
            }
            self = .template(componentId: componentId, path: path)
        default:
            self = .staticList([])
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .staticList(let ids):
            var container = encoder.singleValueContainer()
            try container.encode(ids)
        case .template(let componentId, let path):
            var container = encoder.singleValueContainer()
            try container.encode(["componentId": componentId, "path": path])
        }
    }
}
