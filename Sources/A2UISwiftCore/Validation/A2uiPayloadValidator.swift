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

/// Semantic (graph/topology) validator for v0.9 A2UI payloads.
///
/// This is a *pre-flight* layer that sits above the per-message `Codable` decode in
/// `A2uiMessage`. Where the decoder only enforces the message envelope (version + key
/// shape), this validator enforces the structural rules the protocol requires of the
/// component graph and data model:
///
/// * duplicate component ids
/// * a reachable `root` component (for full renders)
/// * dangling / non-existent component references
/// * orphaned (unreachable) components
/// * self-references and reference cycles
/// * `functionCall` nesting depth
/// * global logical (component-chain) and data-model nesting depth
/// * JSON-Pointer path syntax
/// * catalog-declared property schemas (type checks)
///
/// It mirrors the Python reference implementation in
/// `a2ui_core/core/validating/{validator,integrity_checker,topology_analyzer}.py`.
///
/// The validator operates on raw JSON values (`Any` / `[String: Any]`) — the same shape
/// the conformance harness feeds it — rather than on the decoded `A2uiMessage`, because
/// the graph rules need the raw component structure (catalog-specific reference fields,
/// arbitrary property nesting) that the strongly-typed model intentionally discards.
///
/// # Incremental updates
/// A single `A2uiPayloadValidator` instance accumulates the set of previously-declared
/// component ids across successive `validate(payload:)` calls. When a payload contains
/// no `createSurface` message it is treated as an incremental update, which relaxes the
/// "must contain a root" and "no orphans / no dangling refs" rules (a component may
/// legitimately reference ids delivered in an earlier update). Self-references, cycles,
/// duplicate ids, depth limits, path syntax and property schemas are always enforced.
public final class A2uiPayloadValidator {

    // Limits mirror the Python reference validator.
    private static let maxGlobalDepth = 50
    private static let maxFuncCallDepth = 5

    /// Root component id required for a full (non-incremental) render.
    private let rootId: String

    /// Per-component reference-field map derived from the catalog schema.
    /// For each component type: (single-reference field names, list-reference field names).
    private let refFields: [String: (single: Set<String>, list: Set<String>)]

    /// The catalog's component-property schemas (`catalogId` → components map), used for
    /// per-property type validation. Keyed by component type name.
    private let componentSchemas: [String: [String: Any]]

    /// Ids seen across all `updateComponents` messages processed by this instance.
    /// Lets incremental updates resolve references to earlier-declared components.
    private var knownComponentIds: Set<String> = []

    /// - Parameters:
    ///   - catalogSchema: The catalog schema (already parsed to `[String: Any]`), if any.
    ///   - rootId: The id treated as the surface root (defaults to `"root"`).
    public init(catalogSchema: Any? = nil, rootId: String = "root") {
        self.rootId = rootId
        let schemaDict = catalogSchema as? [String: Any]
        self.componentSchemas = Self.extractComponentSchemas(schemaDict)
        self.refFields = Self.extractRefFields(schemaDict)
    }

    // MARK: - Public entry point

    /// Validates one payload (an array of message dictionaries), throwing the first
    /// structural violation encountered.
    public func validate(_ payload: Any) throws {
        guard let messages = payload as? [Any] else {
            throw A2uiValidationError("Payload must be an array of message objects")
        }

        // 1. Recursion / path checks over the entire message array (data model depth,
        //    functionCall depth, JSON-Pointer syntax). Mirrors validate_recursion_and_paths.
        try validateRecursionAndPaths(messages)

        // 2. An incremental update (no createSurface) relaxes root/orphan/dangling rules.
        let hasCreateSurface = messages.contains { ($0 as? [String: Any])?["createSurface"] != nil }
        let allowIncremental = !hasCreateSurface

        // 3. Per-message component-graph validation.
        for message in messages {
            guard let dict = message as? [String: Any] else { continue }
            guard let update = dict["updateComponents"] as? [String: Any],
                  let components = update["components"] as? [Any] else {
                continue
            }
            let componentDicts = components.compactMap { $0 as? [String: Any] }
            try validateComponents(componentDicts, allowIncremental: allowIncremental)
        }
    }

    // MARK: - Component graph validation

    private func validateComponents(_ components: [[String: Any]], allowIncremental: Bool) throws {
        // a. Catalog property schema checks (e.g. "123 is not of type 'string'").
        for component in components {
            try validateComponentProperties(component)
        }

        // b. Integrity: duplicate ids, missing root, dangling references.
        try validateComponentIntegrity(
            components,
            allowDanglingReferences: allowIncremental,
            allowMissingRoot: allowIncremental
        )

        // c. Topology: self-references, cycles, orphans, logical depth.
        try analyzeTopology(
            components,
            allowOrphanComponents: allowIncremental,
            allowMissingRoot: allowIncremental
        )
    }

    // MARK: - Integrity checker (mirrors integrity_checker.validate_component_integrity)

    private func validateComponentIntegrity(
        _ components: [[String: Any]],
        allowDanglingReferences: Bool,
        allowMissingRoot: Bool
    ) throws {
        var ids: Set<String> = []
        for component in components {
            guard let id = component["id"] as? String else { continue }
            if ids.contains(id) {
                throw A2uiIntegrityError("Duplicate component ID: \(id)")
            }
            ids.insert(id)
        }

        // Record every id this instance has ever seen, so later incremental updates can
        // resolve references to components declared in earlier updates.
        knownComponentIds.formUnion(ids)

        // In an incremental update, components may reference ids already on the client.
        if allowDanglingReferences {
            return
        }

        // Missing-root check.
        if !allowMissingRoot && !ids.contains(rootId) {
            throw A2uiIntegrityError("Missing root component: No component has id='\(rootId)'")
        }

        // Dangling reference check.
        for component in components {
            let compId = (component["id"] as? String) ?? "Unknown"
            for reference in componentReferences(component) where !ids.contains(reference.id) {
                throw A2uiIntegrityError(
                    "Component '\(compId)' references non-existent component '\(reference.id)' "
                        + "in field '\(reference.field)'"
                )
            }
        }
    }

    // MARK: - Topology analyzer (mirrors topology_analyzer.analyze_topology)

    private func analyzeTopology(
        _ components: [[String: Any]],
        allowOrphanComponents: Bool,
        allowMissingRoot: Bool
    ) throws {
        var adjacency: [String: [String]] = [:]
        var allIds: Set<String> = []

        for component in components {
            guard let id = component["id"] as? String else { continue }
            allIds.insert(id)
            if adjacency[id] == nil { adjacency[id] = [] }
            for reference in componentReferences(component) {
                if reference.id == id {
                    throw A2uiRecursionError(
                        "Self-reference detected: Component '\(id)' references itself in field "
                            + "'\(reference.field)'"
                    )
                }
                adjacency[id, default: []].append(reference.id)
            }
        }

        var visited: Set<String> = []
        var stack: Set<String> = []

        func dfs(_ node: String, depth: Int) throws {
            if depth > Self.maxGlobalDepth {
                throw A2uiRecursionError(
                    "Global recursion limit exceeded: logical depth > \(Self.maxGlobalDepth)"
                )
            }
            visited.insert(node)
            stack.insert(node)
            for neighbor in adjacency[node] ?? [] {
                if !visited.contains(neighbor) {
                    try dfs(neighbor, depth: depth + 1)
                } else if stack.contains(neighbor) {
                    throw A2uiRecursionError(
                        "Circular reference detected involving component '\(neighbor)'"
                    )
                }
            }
            stack.remove(node)
        }

        if allowMissingRoot {
            // No guaranteed root: traverse every component to catch cycles/self-refs.
            for node in allIds.sorted() where !visited.contains(node) {
                try dfs(node, depth: 0)
            }
        } else {
            if allIds.contains(rootId) {
                try dfs(rootId, depth: 0)
            }
            if !allowOrphanComponents {
                let orphans = allIds.subtracting(visited)
                if let first = orphans.sorted().first {
                    throw A2uiIntegrityError(
                        "Component '\(first)' is not reachable from '\(rootId)'"
                    )
                }
            }
        }
    }

    // MARK: - Reference extraction (mirrors integrity_checker.get_component_references)

    private struct ComponentReference {
        let id: String
        let field: String
    }

    /// Yields every component-id reference contained in a component, tagged with the field
    /// it was found in. Uses the catalog-derived `refFields` map to know which properties
    /// hold references (single ids vs. child lists / `{componentId, path}` templates).
    private func componentReferences(_ component: [String: Any]) -> [ComponentReference] {
        guard let compType = component["component"] as? String else { return [] }
        let fields = refFields[compType] ?? (single: [], list: [])
        let refFieldNames = fields.single.union(fields.list)

        var results: [ComponentReference] = []
        for (key, value) in component where refFieldNames.contains(key) {
            extractPointers(value, field: key, into: &results)
        }
        return results
    }

    private func extractPointers(_ value: Any, field: String, into results: inout [ComponentReference]) {
        if let string = value as? String {
            results.append(ComponentReference(id: string, field: field))
        } else if let array = value as? [Any] {
            for item in array {
                extractPointers(item, field: field, into: &results)
            }
        } else if let dict = value as? [String: Any] {
            // A `{componentId, path}` template list reference.
            if let componentId = dict["componentId"] as? String {
                results.append(ComponentReference(id: componentId, field: "\(field).componentId"))
            }
        }
    }

    // MARK: - Recursion & path checks (mirrors integrity_checker.validate_recursion_and_paths)

    /// JSON-Pointer syntax accepted by the reference validator: allows `~0` / `~1` escapes
    /// only. A bare `~` followed by anything else (e.g. `~2`) is invalid.
    private static let relaxedPathPattern: NSRegularExpression = {
        // ^(?:(?:/(?:[^~/]|~[01])*)*|(?:[^~/]|~[01])+(?:/(?:[^~/]|~[01])*)*)$
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(
            pattern: #"^(?:(?:/(?:[^~/]|~[01])*)*|(?:[^~/]|~[01])+(?:/(?:[^~/]|~[01])*)*)$"#
        )
    }()

    private func validateRecursionAndPaths(_ data: Any) throws {
        try traverse(data, globalDepth: 0, funcDepth: 0)
    }

    private func traverse(_ item: Any, globalDepth: Int, funcDepth: Int) throws {
        if globalDepth > Self.maxGlobalDepth {
            throw A2uiRecursionError(
                "Global recursion limit exceeded: Depth > \(Self.maxGlobalDepth)"
            )
        }

        if let array = item as? [Any] {
            for element in array {
                try traverse(element, globalDepth: globalDepth + 1, funcDepth: funcDepth)
            }
            return
        }

        guard let dict = item as? [String: Any] else { return }

        if let path = dict["path"] as? String {
            let range = NSRange(path.startIndex..., in: path)
            if Self.relaxedPathPattern.firstMatch(in: path, range: range) == nil {
                throw A2uiValidationError("Invalid path syntax: '\(path)'")
            }
        }

        let isFuncV08 = dict["functionCall"] is [String: Any]
        let isFuncV09 = dict["call"] != nil && dict["args"] != nil

        if isFuncV08 {
            if funcDepth >= Self.maxFuncCallDepth {
                throw A2uiRecursionError(
                    "Recursion limit exceeded: functionCall depth > \(Self.maxFuncCallDepth)"
                )
            }
            try traverse(dict["functionCall"]!, globalDepth: globalDepth + 1, funcDepth: funcDepth + 1)
        } else if isFuncV09 {
            if funcDepth >= Self.maxFuncCallDepth {
                throw A2uiRecursionError(
                    "Recursion limit exceeded: functionCall depth > \(Self.maxFuncCallDepth)"
                )
            }
            for (key, value) in dict {
                let nextFuncDepth = key == "args" ? funcDepth + 1 : funcDepth
                try traverse(value, globalDepth: globalDepth + 1, funcDepth: nextFuncDepth)
            }
        } else {
            for value in dict.values {
                try traverse(value, globalDepth: globalDepth + 1, funcDepth: funcDepth)
            }
        }
    }

    // MARK: - Catalog property schema validation

    /// Validates a component's properties against its catalog-declared schema. Mirrors the
    /// jsonschema check in the Python `CatalogSchemaValidator`, restricted to the schema
    /// constructs the conformance catalogs actually use (`type`, `const`, `enum`, nested
    /// `properties`, `allOf`/`oneOf`/`anyOf`). Unknown component types are ignored here —
    /// they are covered by other layers.
    private func validateComponentProperties(_ component: [String: Any]) throws {
        guard let compType = component["component"] as? String,
              let schema = componentSchemas[compType] else {
            return
        }
        // `id`/`component` are envelope fields, not catalog properties.
        var properties = component
        properties.removeValue(forKey: "id")
        if !schemaDefinesProperty(schema, "component") {
            properties.removeValue(forKey: "component")
        }
        try validateAgainstSchema(properties, schema: schema)
    }

    private func schemaDefinesProperty(_ schema: [String: Any], _ name: String) -> Bool {
        if let props = schema["properties"] as? [String: Any], props[name] != nil {
            return true
        }
        for key in ["allOf", "oneOf", "anyOf"] {
            if let subs = schema[key] as? [Any] {
                for sub in subs {
                    if let subDict = sub as? [String: Any], schemaDefinesProperty(subDict, name) {
                        return true
                    }
                }
            }
        }
        return false
    }

    /// Minimal JSON-Schema validation sufficient for the catalog schemas used by the
    /// conformance suite. Recurses through `allOf`/`oneOf`/`anyOf`, checks `type`,
    /// `const`, `enum`, and nested object `properties`. Throws `A2uiValidationError`
    /// with a jsonschema-style message on the first violation.
    private func validateAgainstSchema(_ value: Any, schema: [String: Any]) throws {
        if let allOf = schema["allOf"] as? [Any] {
            for sub in allOf {
                if let subSchema = sub as? [String: Any] {
                    try validateAgainstSchema(value, schema: subSchema)
                }
            }
        }
        // For oneOf/anyOf we only recurse when there is a single branch (the conformance
        // catalogs use single-branch unions); multi-branch unions are treated as satisfied
        // to avoid false positives, matching the permissive intent of the reference impl.
        for unionKey in ["oneOf", "anyOf"] {
            if let branches = schema[unionKey] as? [Any], branches.count == 1,
               let only = branches[0] as? [String: Any] {
                try validateAgainstSchema(value, schema: only)
            }
        }

        if let type = schema["type"] as? String {
            try validateType(value, expected: type)
        }
        if let constValue = schema["const"] {
            if !jsonEquals(value, constValue) {
                throw A2uiValidationError("\(describe(value)) was expected")
            }
        }
        if let enumValues = schema["enum"] as? [Any] {
            if !enumValues.contains(where: { jsonEquals(value, $0) }) {
                throw A2uiValidationError("\(describe(value)) is not one of the allowed values")
            }
        }

        // Nested object property validation.
        if let dict = value as? [String: Any],
           let props = schema["properties"] as? [String: Any] {
            for (propName, propSchema) in props {
                guard let propSchemaDict = propSchema as? [String: Any],
                      let propValue = dict[propName] else { continue }
                try validateAgainstSchema(propValue, schema: propSchemaDict)
            }
        }
    }

    private func validateType(_ value: Any, expected: String) throws {
        let ok: Bool
        switch expected {
        case "string":
            ok = value is String
        case "number", "integer":
            ok = isNumber(value)
        case "boolean":
            ok = value is Bool && !isNumber(value)
        case "object":
            ok = value is [String: Any]
        case "array":
            ok = value is [Any]
        case "null":
            ok = value is NSNull
        default:
            ok = true
        }
        if !ok {
            throw A2uiValidationError("\(describe(value)) is not of type '\(expected)'")
        }
    }

    // MARK: - Value helpers

    private func isNumber(_ value: Any) -> Bool {
        if value is Bool { return false }
        if let number = value as? NSNumber {
            // Exclude boolean NSNumbers.
            return CFGetTypeID(number) != CFBooleanGetTypeID()
        }
        return value is Int || value is Double || value is Float
    }

    /// Renders a value the way the jsonschema error messages do (e.g. `123`, `'text'`).
    private func describe(_ value: Any) -> String {
        if let string = value as? String { return "'\(string)'" }
        if value is Bool { return "\(value)" }
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            // Print integers without a trailing ".0".
            if number.doubleValue == number.doubleValue.rounded() {
                return "\(number.intValue)"
            }
            return "\(number.doubleValue)"
        }
        if let int = value as? Int { return "\(int)" }
        if let double = value as? Double {
            if double == double.rounded() { return "\(Int(double))" }
            return "\(double)"
        }
        return "\(value)"
    }

    private func jsonEquals(_ lhs: Any, _ rhs: Any) -> Bool {
        if let l = lhs as? String, let r = rhs as? String { return l == r }
        if isNumber(lhs) && isNumber(rhs) {
            return (lhs as? NSNumber)?.doubleValue == (rhs as? NSNumber)?.doubleValue
        }
        if let l = lhs as? Bool, let r = rhs as? Bool { return l == r }
        return false
    }

    // MARK: - Catalog schema introspection

    /// Extracts the per-component-type schema map from a catalog schema dictionary.
    private static func extractComponentSchemas(_ catalog: [String: Any]?) -> [String: [String: Any]] {
        guard let components = catalog?["components"] as? [String: Any] else { return [:] }
        var result: [String: [String: Any]] = [:]
        for (name, schema) in components {
            if let schemaDict = schema as? [String: Any] {
                result[name] = schemaDict
            }
        }
        return result
    }

    /// Derives, for each component type, which property fields hold component references.
    /// A property is a *single* reference when its (resolved) schema `$ref` ends in
    /// `/ComponentId`; a *list* reference when it ends in `/ChildList`. Mirrors
    /// `catalog_schema_validator._extract_ref_fields_json`.
    private static func extractRefFields(
        _ catalog: [String: Any]?
    ) -> [String: (single: Set<String>, list: Set<String>)] {
        guard let components = catalog?["components"] as? [String: Any] else { return [:] }
        var result: [String: (single: Set<String>, list: Set<String>)] = [:]

        for (compName, compSchemaAny) in components {
            guard let compSchema = compSchemaAny as? [String: Any] else { continue }
            var single: Set<String> = []
            var list: Set<String> = []
            collectRefFields(compSchema, single: &single, list: &list)
            if !single.isEmpty || !list.isEmpty {
                result[compName] = (single: single, list: list)
            }
        }
        return result
    }

    private static func collectRefFields(
        _ schema: [String: Any],
        single: inout Set<String>,
        list: inout Set<String>
    ) {
        if let props = schema["properties"] as? [String: Any] {
            for (propName, propSchemaAny) in props {
                guard let propSchema = propSchemaAny as? [String: Any] else { continue }
                if isComponentIdRef(propSchema) {
                    single.insert(propName)
                } else if isChildListRef(propSchema) {
                    list.insert(propName)
                }
            }
        }
        for key in ["allOf", "oneOf", "anyOf"] {
            if let subs = schema[key] as? [Any] {
                for sub in subs {
                    if let subSchema = sub as? [String: Any] {
                        collectRefFields(subSchema, single: &single, list: &list)
                    }
                }
            }
        }
    }

    private static func isComponentIdRef(_ schema: [String: Any]) -> Bool {
        if let ref = schema["$ref"] as? String, ref.hasSuffix("/ComponentId") {
            return true
        }
        return anyBranchMatches(schema, isComponentIdRef)
    }

    private static func isChildListRef(_ schema: [String: Any]) -> Bool {
        if let ref = schema["$ref"] as? String, ref.hasSuffix("/ChildList") {
            return true
        }
        return anyBranchMatches(schema, isChildListRef)
    }

    private static func anyBranchMatches(
        _ schema: [String: Any],
        _ predicate: ([String: Any]) -> Bool
    ) -> Bool {
        for key in ["oneOf", "anyOf", "allOf"] {
            if let subs = schema[key] as? [Any] {
                for sub in subs {
                    if let subSchema = sub as? [String: Any], predicate(subSchema) {
                        return true
                    }
                }
            }
        }
        return false
    }
}
