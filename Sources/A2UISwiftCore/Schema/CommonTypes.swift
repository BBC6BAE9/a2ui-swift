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
}

extension String: LiteralDecodable {
    public static func fromAnyCodable(_ value: AnyCodable) -> String? { value.stringValue }
}

extension Double: LiteralDecodable {
    public static func fromAnyCodable(_ value: AnyCodable) -> Double? { value.numberValue }
}

extension Bool: LiteralDecodable {
    public static func fromAnyCodable(_ value: AnyCodable) -> Bool? { value.boolValue }
}

extension Array: LiteralDecodable where Element == String {
    public static func fromAnyCodable(_ value: AnyCodable) -> [String]? {
        guard let values = value.arrayValue else { return nil }
        var strings: [String] = []
        strings.reserveCapacity(values.count)
        for item in values {
            guard let string = item.stringValue else { return nil }
            strings.append(string)
        }
        return strings
    }
}

private func schemaDecodingError(at codingPath: [any CodingKey], _ message: String) -> DecodingError {
    DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: message))
}

private enum DynamicSchemaKind: String {
    case string
    case number
    case boolean
    case array

    var functionReturnType: FunctionCallReturnType {
        switch self {
        case .string: return .string
        case .number: return .number
        case .boolean: return .boolean
        case .array: return .array
        }
    }
}

private func dynamicSchemaKind<T>(for type: T.Type) -> DynamicSchemaKind? {
    switch type {
    case is String.Type:
        return .string
    case is Double.Type:
        return .number
    case is Bool.Type:
        return .boolean
    case is [String].Type:
        return .array
    default:
        return nil
    }
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
        guard let schemaKind = dynamicSchemaKind(for: T.self) else {
            throw schemaDecodingError(at: decoder.codingPath, "Unsupported Dynamic literal type: \(T.self).")
        }
        if let literal = T.fromAnyCodable(raw) {
            self = .literal(literal)
        } else if case .dictionary(let dict) = raw {
            let resolved = try DynamicDictResolver.resolve(dict, codingPath: decoder.codingPath)
            switch resolved {
            case .dataBinding(let path): self = .dataBinding(path: path)
            case .functionCall(let fc):
                if let returnType = fc.returnType, returnType != schemaKind.functionReturnType {
                    throw schemaDecodingError(
                        at: decoder.codingPath,
                        "Dynamic<\(T.self)> function call must declare returnType '\(schemaKind.rawValue)'."
                    )
                }
                self = .functionCall(fc)
            }
        } else {
            throw schemaDecodingError(
                at: decoder.codingPath,
                "Dynamic<\(T.self)> must be a literal \(schemaKind.rawValue), data binding, or matching function call."
            )
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

    static func resolve(_ dict: [String: AnyCodable], codingPath: [any CodingKey]) throws -> Result {
        if dict.keys.contains("path") {
            guard dict.count == 1, let path = dict["path"]?.stringValue else {
                throw schemaDecodingError(at: codingPath, "DataBinding must be exactly {'path': string}.")
            }
            return .dataBinding(path: path)
        }

        if dict.keys.contains("call") || dict.keys.contains("args") || dict.keys.contains("returnType") {
            let allowedKeys: Set<String> = ["call", "args", "returnType"]
            let extraKeys = Set(dict.keys).subtracting(allowedKeys)
            guard extraKeys.isEmpty else {
                throw schemaDecodingError(
                    at: codingPath,
                    "FunctionCall contains unsupported properties: \(extraKeys.sorted().joined(separator: ", "))."
                )
            }
            guard let callName = dict["call"]?.stringValue else {
                throw schemaDecodingError(at: codingPath, "FunctionCall requires 'call' to be a string.")
            }
            let args: [String: AnyCodable]
            if let rawArgs = dict["args"] {
                guard let dictArgs = rawArgs.dictionaryValue else {
                    throw schemaDecodingError(at: codingPath, "FunctionCall 'args' must be an object.")
                }
                args = dictArgs
            } else {
                args = [:]
            }
            let returnType: FunctionCallReturnType?
            if let rawReturnType = dict["returnType"] {
                guard let stringValue = rawReturnType.stringValue,
                      let decodedReturnType = FunctionCallReturnType(rawValue: stringValue) else {
                    throw schemaDecodingError(at: codingPath, "FunctionCall 'returnType' must be a valid spec enum value.")
                }
                returnType = decodedReturnType
            } else {
                returnType = nil
            }
            return .functionCall(FunctionCall(call: callName, args: args, returnType: returnType))
        }

        throw schemaDecodingError(at: codingPath, "Object does not match DataBinding or FunctionCall schema.")
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
        self = try Self.decodeStrict(from: raw, codingPath: decoder.codingPath)
    }

    public init(from value: AnyCodable) {
        self = Self.decodeLenient(from: value)
    }

    fileprivate static func decodeStrict(from value: AnyCodable, codingPath: [any CodingKey]) throws -> DynamicValue {
        switch value {
        case .string(let s): return .string(s)
        case .number(let n): return .number(n)
        case .bool(let b): return .bool(b)
        case .array(let arr): return .array(arr)
        case .dictionary(let dict):
            let resolved = try DynamicDictResolver.resolve(dict, codingPath: codingPath)
            switch resolved {
            case .dataBinding(let path): return .dataBinding(path: path)
            case .functionCall(let fc): return .functionCall(fc)
            }
        case .null:
            throw schemaDecodingError(at: codingPath, "DynamicValue does not allow null.")
        }
    }

    private static func decodeLenient(from value: AnyCodable) -> DynamicValue {
        switch value {
        case .string(let s): return .string(s)
        case .number(let n): return .number(n)
        case .bool(let b): return .bool(b)
        case .array(let arr): return .array(arr)
        case .dictionary(let dict):
            if let path = dict["path"]?.stringValue, dict.count == 1 {
                return .dataBinding(path: path)
            }
            if let callName = dict["call"]?.stringValue {
                let args = dict["args"]?.dictionaryValue ?? [:]
                let returnType = dict["returnType"]?.stringValue.flatMap(FunctionCallReturnType.init(rawValue:))
                return .functionCall(FunctionCall(call: callName, args: args, returnType: returnType))
            }
            return .string("")
        case .null:
            return .string("")
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

        let allowedTopLevelKeys: Set<String> = ["event", "functionCall"]
        let extraTopLevelKeys = Set(dict.keys).subtracting(allowedTopLevelKeys)
        guard extraTopLevelKeys.isEmpty else {
            throw schemaDecodingError(
                at: decoder.codingPath,
                "Action contains unsupported properties: \(extraTopLevelKeys.sorted().joined(separator: ", "))."
            )
        }

        let hasEvent = dict["event"] != nil
        let hasFunctionCall = dict["functionCall"] != nil
        guard hasEvent != hasFunctionCall else {
            throw schemaDecodingError(at: decoder.codingPath, "Action must contain exactly one of 'event' or 'functionCall'.")
        }

        if let eventDict = dict["event"]?.dictionaryValue,
           let name = eventDict["name"]?.stringValue {
            let allowedEventKeys: Set<String> = ["name", "context"]
            let extraEventKeys = Set(eventDict.keys).subtracting(allowedEventKeys)
            guard extraEventKeys.isEmpty else {
                throw schemaDecodingError(
                    at: decoder.codingPath,
                    "Action event contains unsupported properties: \(extraEventKeys.sorted().joined(separator: ", "))."
                )
            }
            var ctx: [String: DynamicValue]?
            if let ctxDict = eventDict["context"]?.dictionaryValue {
                ctx = try ctxDict.reduce(into: [:]) { result, item in
                    result[item.key] = try DynamicValue.decodeStrict(from: item.value, codingPath: decoder.codingPath)
                }
            } else if eventDict["context"] != nil {
                throw schemaDecodingError(at: decoder.codingPath, "Action event 'context' must be an object.")
            }
            self = .event(name: name, context: ctx)
        } else if let fcDict = dict["functionCall"]?.dictionaryValue,
                  case .functionCall(let fc) = try DynamicDictResolver.resolve(fcDict, codingPath: decoder.codingPath) {
            self = .functionCall(fc)
        } else if dict["functionCall"] != nil {
            throw schemaDecodingError(at: decoder.codingPath, "Action 'functionCall' must be a valid FunctionCall object.")
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
                  let callName = fcDict["call"]?.stringValue {
            let args = fcDict["args"]?.dictionaryValue ?? [:]
            let returnType = fcDict["returnType"]?.stringValue.flatMap(FunctionCallReturnType.init(rawValue:))
            let fc = FunctionCall(call: callName, args: args, returnType: returnType)
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
            var componentIds: [String] = []
            componentIds.reserveCapacity(items.count)
            for item in items {
                guard let componentId = item.stringValue else {
                    throw schemaDecodingError(at: decoder.codingPath, "ChildList array items must all be strings.")
                }
                componentIds.append(componentId)
            }
            self = .staticList(componentIds)
        case .dictionary(let dict):
            let allowedKeys: Set<String> = ["componentId", "path"]
            let extraKeys = Set(dict.keys).subtracting(allowedKeys)
            guard extraKeys.isEmpty else {
                throw schemaDecodingError(
                    at: decoder.codingPath,
                    "ChildList template contains unsupported properties: \(extraKeys.sorted().joined(separator: ", "))."
                )
            }
            guard let componentId = dict["componentId"]?.stringValue,
                  let path = dict["path"]?.stringValue else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "ChildList template requires 'componentId' and 'path'."
                ))
            }
            self = .template(componentId: componentId, path: path)
        default:
            throw schemaDecodingError(at: decoder.codingPath, "ChildList must be an array of component ids or a template object.")
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

    private enum CodingKeys: String, CodingKey {
        case condition
        case message
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        condition = try container.decode(DynamicBoolean.self, forKey: .condition)
        message = try container.decode(String.self, forKey: .message)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(condition, forKey: .condition)
        try container.encode(message, forKey: .message)
    }
}
