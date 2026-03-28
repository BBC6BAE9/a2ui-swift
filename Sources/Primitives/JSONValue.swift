// Copyright 2025 GenUI Authors.

import Foundation

/// A type-safe representation of a JSON value.
///
/// Used for metadata, tool arguments, tool results, and any dynamic JSON
/// content where `[String: Any]` would otherwise be needed.
public enum JSONValue: Hashable, Sendable {
    case null_
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    // MARK: - Convenience initializers

    /// Creates a `JSONValue` from an arbitrary value.
    ///
    /// Returns `nil` if the value cannot be represented as JSON.
    public init?(_ value: Any?) {
        guard let value = value else {
            self = .null_
            return
        }
        switch value {
        case is NSNull:
            self = .null_
        case let b as Bool:
            self = .bool(b)
        case let i as Int:
            self = .int(i)
        case let d as Double:
            // Check if it's actually an integer stored as Double
            if d.truncatingRemainder(dividingBy: 1) == 0,
               d >= Double(Int.min), d <= Double(Int.max) {
                self = .int(Int(d))
            } else {
                self = .double(d)
            }
        case let s as String:
            self = .string(s)
        case let arr as [Any?]:
            var result: [JSONValue] = []
            for item in arr {
                guard let jv = JSONValue(item) else { return nil }
                result.append(jv)
            }
            self = .array(result)
        case let dict as [String: Any?]:
            var result: [String: JSONValue] = [:]
            for (k, v) in dict {
                guard let jv = JSONValue(v) else { return nil }
                result[k] = jv
            }
            self = .object(result)
        default:
            return nil
        }
    }

    // MARK: - Conversion to Any

    /// Converts back to a loosely-typed representation (`Any?`).
    public var anyValue: Any? {
        switch self {
        case .null_:
            return nil
        case .bool(let b):
            return b
        case .int(let i):
            return i
        case .double(let d):
            return d
        case .string(let s):
            return s
        case .array(let arr):
            return arr.map { $0.anyValue }
        case .object(let dict):
            return dict.mapValues { $0.anyValue }
        }
    }

    // MARK: - Convenience accessors

    /// The string value if this is a `.string`, otherwise `nil`.
    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    /// The int value if this is an `.int`, otherwise `nil`.
    public var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }

    /// The double value if this is a `.double`, otherwise `nil`.
    public var doubleValue: Double? {
        if case .double(let d) = self { return d }
        return nil
    }

    /// The bool value if this is a `.bool`, otherwise `nil`.
    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    /// The array value if this is an `.array`, otherwise `nil`.
    public var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    /// The object value if this is an `.object`, otherwise `nil`.
    public var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    /// Whether this value is `.null_`.
    public var isNull: Bool {
        if case .null_ = self { return true }
        return false
    }
}

// MARK: - ExpressibleBy literals

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null_
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

// MARK: - CustomStringConvertible

extension JSONValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .null_:
            return "null"
        case .bool(let b):
            return b ? "true" : "false"
        case .int(let i):
            return "\(i)"
        case .double(let d):
            return "\(d)"
        case .string(let s):
            return s
        case .array(let arr):
            return "[\(arr.map(\.description).joined(separator: ", "))]"
        case .object(let dict):
            let pairs = dict.sorted(by: { $0.key < $1.key })
                .map { "\($0.key): \($0.value.description)" }
            return "{\(pairs.joined(separator: ", "))}"
        }
    }
}

// MARK: - Helpers

/// Compares two `[String: Any?]` dictionaries for deep equality using JSONValue.
public func jsonDictionariesEqual(_ lhs: [String: Any?], _ rhs: [String: Any?]) -> Bool {
    guard let lv = JSONValue(lhs as Any), let rv = JSONValue(rhs as Any) else {
        return false
    }
    return lv == rv
}
