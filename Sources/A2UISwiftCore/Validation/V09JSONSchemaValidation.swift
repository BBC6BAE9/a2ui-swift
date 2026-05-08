// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0

import DynamicJSON
import Foundation

// MARK: - Schema document $id values (must match bundled `specification/v0_9/json`)

private enum V09SchemaDocumentId {
    static let serverToClient = "https://a2ui.org/specification/v0_9/server_to_client.json"
    static let serverToClientList = "https://a2ui.org/specification/v0_9/server_to_client_list.json"
    static let catalog = "https://a2ui.org/specification/v0_9/catalog.json"
}

// MARK: - V09JSONSchemaValidation

/// Loads official v0.9 JSON Schemas from ``Bundle.module`` (`Resources/v0_9`) and validates
/// payloads with [swift-dynamicjson](https://github.com/objecthub/swift-dynamicjson).
///
/// Bundled `catalog.json` is derived from `basic_catalog.json` with `$id` / `catalogId` rewritten
/// so `$ref: "catalog.json#/..."` from `server_to_client.json` resolves, per spec.
public enum V09JSONSchemaValidation {

    private static let registryLock = NSLock()
    private nonisolated(unsafe) static var cachedRegistry: JSONSchemaRegistry?

    private static func bundledSchemaURL(_ name: String) -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "v0_9")
        else {
            preconditionFailure(
                "A2UISwiftCore missing bundled schema \(name).json " +
                    "under v0_9 — check Package.swift resources."
            )
        }
        return url
    }

    private static func registry() throws -> JSONSchemaRegistry {
        registryLock.lock()
        defer { registryLock.unlock() }
        if let cachedRegistry {
            return cachedRegistry
        }
        let reg = JSONSchemaRegistry()
        try reg.loadSchema(from: bundledSchemaURL("common_types"))
        try reg.loadSchema(from: bundledSchemaURL("catalog"))
        try reg.loadSchema(from: bundledSchemaURL("server_to_client"))
        try reg.loadSchema(from: bundledSchemaURL("server_to_client_list"))
        cachedRegistry = reg
        return reg
    }

    private static func json(from value: Any) throws -> JSON {
        let data = try JSONSerialization.data(withJSONObject: value)
        return try JSON(data: data)
    }

    private static func failureMessage(_ result: JSONSchemaValidationResult, prefix: String) -> String {
        let lines = result.errors.map(\.description)
        if lines.isEmpty { return prefix }
        return prefix + ": " + lines.joined(separator: "; ")
    }

    private static func failureDetails(_ result: JSONSchemaValidationResult) -> [String: AnyCodable] {
        let lines = result.errors.map(\.description)
        return ["errors": .array(lines.map { .string($0) })]
    }

    /// Validates one server-to-client message object against `server_to_client.json`.
    public static func validateServerToClientMessage(_ message: [String: Any]) throws {
        let reg = try registry()
        let validator = try reg.validator(for: V09SchemaDocumentId.serverToClient)
        let result = validator.validate(try json(from: message))
        guard result.isValid else {
            throw A2uiValidationError(
                failureMessage(result, prefix: "A2UI server message failed JSON Schema validation"),
                details: failureDetails(result)
            )
        }
    }

    /// Validates a JSON array of messages against `server_to_client_list.json`.
    public static func validateServerToClientMessageList(_ messages: [Any]) throws {
        let reg = try registry()
        let validator = try reg.validator(for: V09SchemaDocumentId.serverToClientList)
        let result = validator.validate(try json(from: messages))
        guard result.isValid else {
            throw A2uiValidationError(
                failureMessage(result, prefix: "A2UI server message list failed JSON Schema validation"),
                details: failureDetails(result)
            )
        }
    }

    /// Validates a single component object against `catalog.json#/components/{componentType}`.
    public static func validateCatalogComponent(_ component: [String: Any], componentType: String) throws {
        let reg = try registry()
        let uri = "\(V09SchemaDocumentId.catalog)#/components/\(componentType)"
        guard let identifier = JSONSchemaIdentifier(string: uri) else {
            throw A2uiValidationError("Invalid JSON Schema identifier for component type: \(componentType)")
        }
        let validator = try JSONSchemaValidationContext(registry: reg).validator(for: identifier)
        let result = validator.validate(try json(from: component))
        guard result.isValid else {
            throw A2uiValidationError(
                failureMessage(
                    result,
                    prefix: "Component '\(componentType)' failed JSON Schema validation"
                ),
                details: failureDetails(result)
            )
        }
    }
}
