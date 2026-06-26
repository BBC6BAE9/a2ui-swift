// Tests/A2UIConformanceTests/ConformanceCase.swift
import Foundation
import XCTest

struct ConformanceCatalogConfig {
    let version: String           // "0.8" or "0.9"
    let s2cSchema: Any?           // [String: Any] or nil
    let catalogSchema: Any?       // [String: Any] or nil
    let commonTypesSchema: Any?   // [String: Any] or nil
}

struct ConformanceExpectedError {
    let category: String          // "ParseError", "ValidationError", etc.
    let message: String?
}

struct ConformanceStep {
    let input: String?            // for process_chunk / parse_full / fix_payload / has_parts
    let payload: Any?             // for validate (array of messages)
    let args: [String: Any]?      // for prune, load, select_catalog, etc.
    let expect: Any?              // expected output (array of parts, mapping, etc.)
    let expectOutput: String?     // for render / load actions
    let expectError: ConformanceExpectedError?
    let expectSelected: String?   // for select_catalog
}

struct ConformanceCase {
    let name: String
    let description: String?
    let catalog: ConformanceCatalogConfig?
    let action: String
    let steps: [ConformanceStep]
}

// MARK: - Loaders

func loadTestDataJSON(path: String) throws -> Any {
    // path may be like "test_data/simplified_s2c_v08.json" — strip the prefix
    let strippedPath = path.hasPrefix("test_data/") ? String(path.dropFirst("test_data/".count)) : path
    let fileURL = URL(fileURLWithPath: strippedPath)
    let filename = fileURL.deletingPathExtension().lastPathComponent
    let ext = fileURL.pathExtension

    guard let url = Bundle.module.url(
        forResource: filename,
        withExtension: ext.isEmpty ? nil : ext,
        subdirectory: "Resources/test_data"
    ) else {
        throw YAMLError.parse("test_data file not found: \(path)")
    }
    let data = try Data(contentsOf: url)
    return try JSONSerialization.jsonObject(with: data)
}

func loadConformanceCases(suite: String) throws -> [ConformanceCase] {
    guard let url = Bundle.module.url(
        forResource: suite,
        withExtension: "yaml",
        subdirectory: "Resources/suites"
    ) else {
        throw YAMLError.parse("Suite not found: \(suite).yaml")
    }
    let text = try String(contentsOf: url, encoding: .utf8)
    let parsed = try parseYAML(text)
    guard let rawCases = parsed as? [[String: Any]] else {
        throw YAMLError.parse("Expected array of mappings in \(suite).yaml")
    }
    return try rawCases.map { try decodeCase($0) }
}

// MARK: - Private helpers

private func decodeCase(_ d: [String: Any]) throws -> ConformanceCase {
    guard let name = d["name"] as? String else {
        throw YAMLError.parse("Case missing 'name'")
    }
    let action = d["action"] as? String ?? "process_chunk"

    let catalogConfig: ConformanceCatalogConfig?
    if let catalogDict = d["catalog"] as? [String: Any] {
        catalogConfig = try decodeCatalogConfig(catalogDict)
    } else {
        catalogConfig = nil
    }

    // Collect steps: either explicit "steps" array, or the case itself is one step
    let rawSteps: [[String: Any]]
    if let stepsArray = d["steps"] as? [[String: Any]] {
        rawSteps = stepsArray
    } else {
        rawSteps = [d]
    }

    // Top-level expect_error propagates to steps that don't have their own
    let topLevelError = decodeExpectedError(d)
    let steps = rawSteps.map { decodeStep($0, fallbackError: topLevelError) }

    return ConformanceCase(
        name: name,
        description: d["description"] as? String,
        catalog: catalogConfig,
        action: action,
        steps: steps
    )
}

private func decodeCatalogConfig(_ d: [String: Any]) throws -> ConformanceCatalogConfig {
    let version = d["version"] as? String ?? "0.9"

    func resolveSchema(_ key: String) throws -> Any? {
        guard let val = d[key] else { return nil }
        if let path = val as? String {
            return try loadTestDataJSON(path: path)
        }
        return val
    }

    return ConformanceCatalogConfig(
        version: version,
        s2cSchema: try resolveSchema("s2c_schema"),
        catalogSchema: try resolveSchema("catalog_schema"),
        commonTypesSchema: try resolveSchema("common_types_schema")
    )
}

private func decodeExpectedError(_ d: [String: Any]) -> ConformanceExpectedError? {
    if let errDict = d["expect_error"] as? [String: Any] {
        return ConformanceExpectedError(
            category: errDict["category"] as? String ?? "",
            message: errDict["message"] as? String
        )
    } else if let errStr = d["expect_error"] as? String {
        return ConformanceExpectedError(category: "ParseError", message: errStr)
    }
    return nil
}

private func decodeStep(_ d: [String: Any], fallbackError: ConformanceExpectedError? = nil) -> ConformanceStep {
    let expectError = decodeExpectedError(d) ?? fallbackError
    return ConformanceStep(
        input: d["input"] as? String,
        payload: d["payload"],
        args: d["args"] as? [String: Any],
        expect: d["expect"],
        expectOutput: d["expect_output"] as? String,
        expectError: expectError,
        expectSelected: d["expect_selected"] as? String
    )
}
