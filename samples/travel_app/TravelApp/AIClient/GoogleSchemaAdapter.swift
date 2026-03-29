// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/// An error that occurred during schema adaptation.
///
/// Mirrors Flutter's `GoogleSchemaAdapterError` from
/// `ai_client/google_schema_adapter.dart`.
struct GoogleSchemaAdapterError: CustomStringConvertible {
    /// A message describing the error.
    let message: String

    /// The path to the location in the schema where the error occurred.
    let path: [String]

    var description: String {
        "Error at path \"\(path.joined(separator: "/"))\": \(message)"
    }
}

/// The result of a schema adaptation.
///
/// Mirrors Flutter's `GoogleSchemaAdapterResult` from
/// `ai_client/google_schema_adapter.dart`.
struct GoogleSchemaAdapterResult {
    /// The adapted schema dictionary, or `nil` if adaptation failed entirely.
    let schema: [String: Any]?

    /// Errors encountered during adaptation.
    let errors: [GoogleSchemaAdapterError]
}

/// Adapts a JSON Schema dictionary to the Gemini API schema format.
///
/// Gemini uses uppercase type names (`"OBJECT"`, `"STRING"`, `"INTEGER"`, etc.)
/// while JSON Schema uses lowercase. This adapter converts as much as possible,
/// accumulating errors for unsupported keywords.
///
/// Mirrors Flutter's `GoogleSchemaAdapter` from
/// `ai_client/google_schema_adapter.dart`.
class GoogleSchemaAdapter {
    private var errors: [GoogleSchemaAdapterError] = []

    /// Adapts the given JSON Schema dictionary to Gemini format.
    ///
    /// Returns a ``GoogleSchemaAdapterResult`` containing the adapted schema
    /// and any errors encountered.
    func adapt(_ schema: [String: Any]) -> GoogleSchemaAdapterResult {
        errors.removeAll()
        let adapted = adaptInternal(schema, path: ["#"])
        return GoogleSchemaAdapterResult(schema: adapted, errors: errors)
    }

    // MARK: - Internal

    private func adaptInternal(_ schema: [String: Any], path: [String]) -> [String: Any]? {
        checkUnsupportedGlobalKeywords(schema, path: path)

        if schema["anyOf"] != nil {
            errors.append(GoogleSchemaAdapterError(
                message: "Unsupported keyword \"anyOf\". It will be ignored.",
                path: path
            ))
        }

        var typeName: String?

        if let type = schema["type"] as? String {
            typeName = type
        } else if let typeArray = schema["type"] as? [String] {
            if typeArray.isEmpty {
                errors.append(GoogleSchemaAdapterError(
                    message: "Schema has an empty \"type\" array.",
                    path: path
                ))
                return nil
            }
            typeName = typeArray.first
            if typeArray.count > 1 {
                errors.append(GoogleSchemaAdapterError(
                    message: "Multiple types found (\(typeArray.joined(separator: ", "))). "
                        + "Only the first type \"\(typeName!)\" will be used.",
                    path: path
                ))
            }
        } else if schema["properties"] != nil {
            typeName = "object"
        } else if schema["items"] != nil {
            typeName = "array"
        }

        guard let typeName else {
            errors.append(GoogleSchemaAdapterError(
                message: "Schema must have a \"type\" or be implicitly typed "
                    + "with \"properties\" or \"items\".",
                path: path
            ))
            return nil
        }

        switch typeName {
        case "object": return adaptObject(schema, path: path)
        case "array": return adaptArray(schema, path: path)
        case "string": return adaptString(schema, path: path)
        case "number": return adaptNumber(schema, path: path)
        case "integer": return adaptInteger(schema, path: path)
        case "boolean": return adaptBoolean(schema, path: path)
        case "null": return adaptNull(schema, path: path)
        default:
            errors.append(GoogleSchemaAdapterError(
                message: "Unsupported schema type \"\(typeName)\".",
                path: path
            ))
            return nil
        }
    }

    private func checkUnsupportedGlobalKeywords(_ schema: [String: Any], path: [String]) {
        let unsupported = [
            "$comment", "default", "examples", "deprecated", "readOnly",
            "writeOnly", "$defs", "$ref", "$anchor", "$dynamicAnchor",
            "$id", "$schema", "allOf", "oneOf", "not", "if", "then",
            "else", "dependentSchemas", "const",
        ]
        for keyword in unsupported {
            if schema[keyword] != nil {
                errors.append(GoogleSchemaAdapterError(
                    message: "Unsupported keyword \"\(keyword)\". It will be ignored.",
                    path: path
                ))
            }
        }
    }

    // MARK: - Type-specific adapters

    private func adaptObject(_ schema: [String: Any], path: [String]) -> [String: Any] {
        var properties: [String: Any] = [:]
        if let props = schema["properties"] as? [String: Any] {
            for (key, value) in props {
                if let propSchema = value as? [String: Any] {
                    let propPath = path + ["properties", key]
                    if let adapted = adaptInternal(propSchema, path: propPath) {
                        properties[key] = adapted
                    }
                }
            }
        }

        for keyword in ["patternProperties", "dependentRequired",
                        "additionalProperties", "unevaluatedProperties",
                        "propertyNames", "minProperties", "maxProperties"] {
            if schema[keyword] != nil {
                errors.append(GoogleSchemaAdapterError(
                    message: "Unsupported keyword \"\(keyword)\". It will be ignored.",
                    path: path
                ))
            }
        }

        var result: [String: Any] = ["type": "OBJECT"]
        if !properties.isEmpty { result["properties"] = properties }
        if let required = schema["required"] { result["required"] = required }
        result["description"] = schema["description"] as? String ?? ""
        return result
    }

    private func adaptArray(_ schema: [String: Any], path: [String]) -> [String: Any]? {
        guard let items = schema["items"] as? [String: Any] else {
            errors.append(GoogleSchemaAdapterError(
                message: "Array schema must have an \"items\" property.",
                path: path
            ))
            return nil
        }

        guard let adaptedItems = adaptInternal(items, path: path + ["items"]) else {
            return nil
        }

        for keyword in ["prefixItems", "unevaluatedItems", "contains",
                        "minContains", "maxContains", "uniqueItems",
                        "minItems", "maxItems"] {
            if schema[keyword] != nil {
                errors.append(GoogleSchemaAdapterError(
                    message: "Unsupported keyword \"\(keyword)\". It will be ignored.",
                    path: path
                ))
            }
        }

        let result: [String: Any] = [
            "type": "ARRAY",
            "items": adaptedItems,
            "description": schema["description"] as? String ?? "",
        ]
        _ = result // suppress unused warning
        return result
    }

    private func adaptString(_ schema: [String: Any], path: [String]) -> [String: Any] {
        for keyword in ["minLength", "maxLength", "pattern"] {
            if schema[keyword] != nil {
                errors.append(GoogleSchemaAdapterError(
                    message: "Unsupported keyword \"\(keyword)\". It will be ignored.",
                    path: path
                ))
            }
        }

        var result: [String: Any] = [
            "type": "STRING",
            "description": schema["description"] as? String ?? "",
        ]
        if let format = schema["format"] as? String { result["format"] = format }
        if let enumValues = schema["enum"] { result["enum"] = enumValues }
        return result
    }

    private func adaptNumber(_ schema: [String: Any], path: [String]) -> [String: Any] {
        for keyword in ["exclusiveMinimum", "exclusiveMaximum",
                        "multipleOf", "minimum", "maximum"] {
            if schema[keyword] != nil {
                errors.append(GoogleSchemaAdapterError(
                    message: "Unsupported keyword \"\(keyword)\". It will be ignored.",
                    path: path
                ))
            }
        }
        return [
            "type": "NUMBER",
            "description": schema["description"] as? String ?? "",
        ]
    }

    private func adaptInteger(_ schema: [String: Any], path: [String]) -> [String: Any] {
        for keyword in ["exclusiveMinimum", "exclusiveMaximum",
                        "multipleOf", "minimum", "maximum"] {
            if schema[keyword] != nil {
                errors.append(GoogleSchemaAdapterError(
                    message: "Unsupported keyword \"\(keyword)\". It will be ignored.",
                    path: path
                ))
            }
        }
        return [
            "type": "INTEGER",
            "description": schema["description"] as? String ?? "",
        ]
    }

    private func adaptBoolean(_ schema: [String: Any], path: [String]) -> [String: Any] {
        return [
            "type": "BOOLEAN",
            "description": schema["description"] as? String ?? "",
        ]
    }

    private func adaptNull(_ schema: [String: Any], path: [String]) -> [String: Any] {
        return [
            "type": "OBJECT",
            "nullable": true,
            "description": schema["description"] as? String ?? "",
        ]
    }
}
