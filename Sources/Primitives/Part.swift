// Copyright 2025 GenUI Authors.

import Foundation

/// Base protocol for message content parts.
///
/// To create a custom part implementation, conform to this protocol and ensure:
/// * **Equality**: Implement `Equatable` for value-based equality.
/// * **Serialization**: Implement `toJson()` returning a dictionary with a
///   `"type"` field containing a unique string identifier.
/// * **Deserialization**: Provide a `JsonToPartConverter` that recreates the
///   part from its JSON representation.
public protocol Part: Equatable, Sendable {
    /// Serializes the part to a JSON-compatible dictionary.
    ///
    /// The returned dictionary must contain a key matching `Part.typeKey`
    /// with a unique string identifier for the part type.
    func toJson() -> [String: Any?]
}

/// The key of the part type in the JSON representation.
public let partTypeKey = "type"

/// A closure that converts a JSON dictionary to a `Part`.
public typealias JsonToPartConverter = ([String: Any?]) throws -> any Part

/// Deserializes a part from a JSON dictionary.
///
/// - Parameters:
///   - json: The JSON dictionary.
///   - converterRegistry: A map of part type strings to converters.
/// - Returns: The deserialized `Part`.
/// - Throws: If the part type is unknown (not in the registry).
public func partFromJson(
    _ json: [String: Any?],
    converterRegistry: [String: JsonToPartConverter]
) throws -> any Part {
    guard let type = json[partTypeKey] as? String else {
        throw PartError.missingTypeKey
    }
    guard let converter = converterRegistry[type] else {
        throw PartError.unknownType(type)
    }
    return try converter(json)
}

/// Errors that can occur during Part deserialization.
public enum PartError: Error, CustomStringConvertible {
    case missingTypeKey
    case unknownType(String)
    case invalidFormat(String)

    public var description: String {
        switch self {
        case .missingTypeKey:
            return "Missing 'type' key in part JSON"
        case .unknownType(let type):
            return "Unknown part type: \(type)"
        case .invalidFormat(let detail):
            return "Invalid part format: \(detail)"
        }
    }
}
