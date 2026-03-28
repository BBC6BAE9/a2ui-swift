// Copyright 2025 GenUI Authors.

import Foundation

/// A tool that can be called by the LLM.
public struct ToolDefinition: @unchecked Sendable {
    /// The unique name of the tool that clearly communicates its purpose.
    public let name: String

    /// Used to tell the model how/when/why to use the tool.
    public let description: String

    /// Schema to parse and validate tool's input arguments.
    /// Following the [JSON Schema specification](https://json-schema.org).
    public let inputSchema: [String: Any]

    public init(
        name: String,
        description: String,
        inputSchema: [String: Any]? = nil
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema ?? [
            "type": "object",
            "properties": [String: Any](),
        ]
    }

    // MARK: - JSON Serialization

    private enum JsonKey {
        static let name = "name"
        static let description = "description"
        static let inputSchema = "inputSchema"
    }

    /// Serializes the tool definition to JSON.
    public func toJson() -> [String: Any?] {
        [
            JsonKey.name: name,
            JsonKey.description: description,
            JsonKey.inputSchema: inputSchema,
        ]
    }

    /// Deserializes a tool definition from JSON.
    public static func fromJson(_ json: [String: Any?]) throws -> ToolDefinition {
        guard let name = json[JsonKey.name] as? String else {
            throw PartError.invalidFormat("ToolDefinition requires 'name'")
        }
        guard let description = json[JsonKey.description] as? String else {
            throw PartError.invalidFormat("ToolDefinition requires 'description'")
        }
        let inputSchema = json[JsonKey.inputSchema] as? [String: Any]
        return ToolDefinition(name: name, description: description, inputSchema: inputSchema)
    }
}

// MARK: - CustomDebugStringConvertible

extension ToolDefinition: CustomDebugStringConvertible {
    public var debugDescription: String {
        "ToolDefinition(name: \(name), description: \(description))"
    }
}
