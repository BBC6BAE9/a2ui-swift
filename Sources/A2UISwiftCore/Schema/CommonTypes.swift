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

// MARK: - FunctionCallReturnType

/// The allowed return-type values for a `FunctionCall`, matching the spec enum.
public enum FunctionCallReturnType: String, Codable, Sendable {
    case string
    case number
    case boolean
    case array
    case object
    case any
    case void
}

// MARK: - FunctionCall

/// A function call: `{"call":"name","args":{...},"returnType":"string"}`.
/// Mirrors WebCore `FunctionCallSchema`.
public struct FunctionCall: Codable, Sendable {
    public var call: String
    public var args: [String: AnyCodable]
    public var returnType: FunctionCallReturnType?

    public init(call: String, args: [String: AnyCodable] = [:], returnType: FunctionCallReturnType? = nil) {
        self.call = call
        self.args = args
        self.returnType = returnType
    }
}

// MARK: - LiteralDecodable protocol

/// 让泛型 Dynamic<T> 知道如何从 AnyCodable 提取字面量，以及提供默认值。
public protocol LiteralDecodable: Codable {
    static func fromAnyCodable(_ value: AnyCodable) -> Self?
    static var defaultLiteral: Self { get }
}

extension String: LiteralDecodable {
    public static func fromAnyCodable(_ value: AnyCodable) -> String? { value.stringValue }
    public static var defaultLiteral: String { "" }
}

extension Double: LiteralDecodable {
    public static func fromAnyCodable(_ value: AnyCodable) -> Double? { value.numberValue }
    public static var defaultLiteral: Double { 0 }
}

extension Bool: LiteralDecodable {
    public static func fromAnyCodable(_ value: AnyCodable) -> Bool? { value.boolValue }
    public static var defaultLiteral: Bool { false }
}

extension Array: LiteralDecodable where Element == String {
    public static func fromAnyCodable(_ value: AnyCodable) -> [String]? {
        value.arrayValue?.compactMap(\.stringValue)
    }
    public static var defaultLiteral: [String] { [] }
}

// MARK: - Dynamic<T>

/// 泛型动态值：字面量 T | 数据绑定 | 函数调用。
/// 一份 Codable 实现覆盖 DynamicString / DynamicNumber / DynamicBoolean / DynamicStringList。
public enum Dynamic<T: LiteralDecodable & Sendable>: Codable, Sendable {
    
    case literal(T)
    case dataBinding(path: String)
    case functionCall(FunctionCall)

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        if let literal = T.fromAnyCodable(raw) {
            self = .literal(literal)
        } else if case .dictionary(let dict) = raw, let resolved = DynamicDictResolver.resolve(dict) {
            switch resolved {
            case .dataBinding(let path): self = .dataBinding(path: path)
            case .functionCall(let fc):
                guard Self.functionCallReturnTypeMatchesSchema(fc.returnType) else {
                    throw DecodingError.dataCorrupted(.init(
                        codingPath: decoder.codingPath,
                        debugDescription: "FunctionCall returnType does not match Dynamic<\(T.self)> schema."
                    ))
                }
                self = .functionCall(fc)
            }
        } else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Dynamic<\(T.self)> received unexpected value: \(raw)"
            ))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .literal(let v): try container.encode(v)
        case .dataBinding(let path): try container.encode(["path": path])
        case .functionCall(let fc): try container.encode(fc)
        }
    }

    /// Enforces typed Dynamic schema constraints for function-call return types.
    /// Mirrors the JSON-schema intent:
    /// - DynamicString: returnType is absent or "string"
    /// - DynamicNumber: returnType is absent or "number"
    /// - DynamicBoolean: returnType is absent or "boolean"
    /// - DynamicStringList: returnType is absent or "array"
    private static func functionCallReturnTypeMatchesSchema(_ returnType: FunctionCallReturnType?) -> Bool {
        guard let returnType else { return true }
        if T.self == String.self { return returnType == .string }
        if T.self == Double.self { return returnType == .number }
        if T.self == Bool.self { return returnType == .boolean }
        if T.self == [String].self { return returnType == .array }
        return true
    }
}

// MARK: - Type aliases

public typealias DynamicString = Dynamic<String>
public typealias DynamicNumber = Dynamic<Double>
public typealias DynamicBoolean = Dynamic<Bool>
public typealias DynamicStringList = Dynamic<[String]>

// MARK: - Shared decoding helper

/// Resolves `{"path":"..."}` → dataBinding, `{"call":"..."}` → functionCall.
enum DynamicDictResolver {
    enum Result {
        case dataBinding(path: String)
        case functionCall(FunctionCall)
    }

    static func resolve(_ dict: [String: AnyCodable]) -> Result? {
        if let callName = dict["call"]?.stringValue {
            let args = dict["args"]?.dictionaryValue ?? [:]
            let returnType = dict["returnType"]?.stringValue.flatMap(FunctionCallReturnType.init(rawValue:))
            return .functionCall(FunctionCall(call: callName, args: args, returnType: returnType))
        }
        if let path = dict["path"]?.stringValue {
            return .dataBinding(path: path)
        }
        return nil
    }
}

// MARK: - DynamicValue

/// A generic dynamic value: any literal | DataBinding | FunctionCall.
/// 不适合泛型（多种字面量类型），保持独立 enum。
/// Mirrors WebCore `DynamicValueSchema`.
public enum DynamicValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([AnyCodable])
    case dataBinding(path: String)
    case functionCall(FunctionCall)

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        self.init(from: raw)
    }

    public init(from value: AnyCodable) {
        switch value {
        case .string(let s): self = .string(s)
        case .number(let n): self = .number(n)
        case .bool(let b): self = .bool(b)
        case .array(let arr): self = .array(arr)
        case .dictionary(let dict):
            if let resolved = DynamicDictResolver.resolve(dict) {
                switch resolved {
                case .dataBinding(let path): self = .dataBinding(path: path)
                case .functionCall(let fc): self = .functionCall(fc)
                }
            } else {
                assertionFailure("A2UI: DynamicValue received unresolvable object: \(dict)")
                self = .string("")
            }
        case .null:
            assertionFailure("A2UI: DynamicValue received null, falling back to empty string.")
            self = .string("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .array(let arr): try container.encode(arr)
        case .dataBinding(let path): try container.encode(["path": path])
        case .functionCall(let fc): try container.encode(fc)
        }
    }
}

// MARK: - Action

/// Server event or client-side function call.
/// Mirrors WebCore `ActionSchema`.
public enum Action: Codable, Sendable {
    case event(name: String, context: [String: DynamicValue]?)
    case functionCall(FunctionCall)

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        guard case .dictionary(let dict) = raw else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Action must be a JSON object."
            ))
        }

        if let eventDict = dict["event"]?.dictionaryValue,
           let name = eventDict["name"]?.stringValue {
            var ctx: [String: DynamicValue]?
            if let ctxDict = eventDict["context"]?.dictionaryValue {
                ctx = ctxDict.mapValues { DynamicValue(from: $0) }
            }
            self = .event(name: name, context: ctx)
        } else if let fcDict = dict["functionCall"]?.dictionaryValue,
                  let resolved = DynamicDictResolver.resolve(fcDict),
                  case .functionCall(let fc) = resolved {
            self = .functionCall(fc)
        } else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Action must contain 'event' or 'functionCall'."
            ))
        }
    }

    /// Convenience init from AnyCodable (non-throwing, for runtime use).
    public init(from value: AnyCodable) {
        guard case .dictionary(let dict) = value else {
            self = .event(name: "", context: nil)
            return
        }
        if let eventDict = dict["event"]?.dictionaryValue,
           let name = eventDict["name"]?.stringValue {
            var ctx: [String: DynamicValue]?
            if let ctxDict = eventDict["context"]?.dictionaryValue {
                ctx = ctxDict.mapValues { DynamicValue(from: $0) }
            }
            self = .event(name: name, context: ctx)
        } else if let fcDict = dict["functionCall"]?.dictionaryValue,
                  let resolved = DynamicDictResolver.resolve(fcDict),
                  case .functionCall(let fc) = resolved {
            self = .functionCall(fc)
        } else {
            self = .event(name: "", context: nil)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .event(let name, let context):
            var event: [String: AnyCodable] = ["name": .string(name)]
            if let ctx = context {
                let encoded = try JSONEncoder().encode(ctx)
                let decoded = try JSONDecoder().decode(AnyCodable.self, from: encoded)
                event["context"] = decoded
            }
            try container.encode(["event": AnyCodable.dictionary(event)])
        case .functionCall(let fc):
            let encoded = try JSONEncoder().encode(fc)
            let decoded = try JSONDecoder().decode(AnyCodable.self, from: encoded)
            try container.encode(["functionCall": decoded])
        }
    }
}

// MARK: - ChildList

/// Static component ID list or dynamic template.
/// Mirrors WebCore `ChildListSchema`.
public enum ChildList: Codable, Sendable {
    case staticList([String])
    case template(componentId: String, path: String)

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        switch raw {
        case .array(let items):
            self = .staticList(items.compactMap(\.stringValue))
        case .dictionary(let dict):
            guard let componentId = dict["componentId"]?.stringValue,
                  let path = dict["path"]?.stringValue else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "ChildList template requires 'componentId' and 'path'."
                ))
            }
            self = .template(componentId: componentId, path: path)
        default:
            self = .staticList([])
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .staticList(let ids): try container.encode(ids)
        case .template(let componentId, let path):
            try container.encode(["componentId": componentId, "path": path])
        }
    }
}

// MARK: - CheckRule

/// A validation rule with a condition and error message.
/// Mirrors WebCore `CheckRuleSchema`.
public struct CheckRule: Codable, Sendable {
    public var condition: DynamicBoolean
    public var message: String

    public init(condition: DynamicBoolean, message: String) {
        self.condition = condition
        self.message = message
    }
}
