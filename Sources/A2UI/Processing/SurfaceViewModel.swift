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
import Observation

/// Core state manager for a single A2UI surface.
/// Processes the four message types and maintains the component buffer + data model.
///
/// Uses `@Observable` with per-key `ObservableValue` slots for the data model.
/// When only `dataStore["name"]` changes, only Views that read that specific key
/// re-render — matching the Signal-based approach used by the official Lit and
/// Angular renderers.
@Observable
public final class SurfaceViewModel {
    public var surfaceId: String?
    public var rootComponentId: String?
    public var components: [String: RawComponentInstance] = [:]
    public var styles: [String: String] = [:]
    public var a2uiStyle = A2UIStyle()
    public var lastAction: ResolvedAction?
    public var componentTree: ComponentNode?

    /// Extracted data store that owns all path resolution, read, and write logic.
    public let dataStore = DataStore()

    /// Backward-compatible computed accessor delegating to `dataStore`.
    public var dataModel: [String: AnyCodable] {
        get { dataStore.dataModel }
        set { dataStore.dataModel = newValue }
    }

    /// All top-level keys currently in the data store (for debugging).
    public var dataStoreKeys: [String] { dataStore.dataStoreKeys }

    public init() {}

    /// Process an array of server-to-client messages in order.
    public func processMessages(_ messages: [ServerToClientMessage]) throws {
        for message in messages {
            try processMessage(message)
        }
    }

    /// Process a single server-to-client message (used by JSONL stream parsing).
    public func processMessage(_ message: ServerToClientMessage) throws {
        if let br = message.beginRendering {
            handleBeginRendering(br)
        }
        if let su = message.surfaceUpdate {
            try handleSurfaceUpdate(su)
        }
        if let dm = message.dataModelUpdate {
            handleDataModelUpdate(dm)
        }
        if message.deleteSurface != nil {
            handleDeleteSurface()
        }
    }

    // MARK: - Message Handlers

    private func handleBeginRendering(_ message: BeginRenderingMessage) {
        surfaceId = message.surfaceId
        rootComponentId = message.root
        styles = message.styles ?? [:]
        a2uiStyle = A2UIStyle(from: styles)
        rebuildComponentTree()
    }

    private func handleSurfaceUpdate(_ message: SurfaceUpdateMessage) throws {
        for component in message.components {
            components[component.id] = component
        }
        rebuildComponentTree()
    }

    private func handleDataModelUpdate(_ message: DataModelUpdateMessage) {
        let converted = Self.convertValueMap(message.contents)
        if let path = message.path, path != "/" {
            dataStore.setData(path: path, value: .dictionary(converted))
        } else {
            for (key, value) in converted {
                if key.contains(".") || key.contains("[") {
                    // Flat dotted/bracket key (e.g. "chart.items[0].label")
                    // → normalize to slash path and set via dataStore
                    let normalized = normalizePath(key)
                    dataStore.setData(path: "/\(normalized)", value: value)
                } else {
                    dataStore.setData(path: key, value: value)
                }
            }
        }
        // Data-bound values are read reactively from per-key ObservableValues.
        // Only rebuild when template-driven structure may have changed.
        rebuildComponentTreeIfNeeded()
    }

    private func handleDeleteSurface() {
        rootComponentId = nil
        components.removeAll()
        dataStore.removeAll()
        styles.removeAll()
        a2uiStyle = A2UIStyle()
        componentTree = nil
    }

    // MARK: - Data Store Delegation

    /// Resolve a relative path against a data context path into an absolute path.
    public func resolvePath(_ path: String, context: String) -> String {
        dataStore.resolvePath(path, context: context)
    }

    /// Normalize bracket/dot notation to slash-delimited paths.
    public func normalizePath(_ path: String) -> String {
        dataStore.normalizePath(path)
    }

    /// Traverse the data model by a slash-delimited path.
    public func getDataByPath(_ path: String) -> AnyCodable? {
        dataStore.getDataByPath(path)
    }

    /// Write a value into the data model at a given path.
    public func setData(path: String, value: AnyCodable, dataContextPath: String = "/") {
        dataStore.setData(path: path, value: value, dataContextPath: dataContextPath)
    }

    /// Resolve a `StringListValue` to an array of selected value strings.
    public func resolveStringArray(
        _ selections: StringListValue,
        dataContextPath: String = "/"
    ) -> [String] {
        dataStore.resolveStringArray(selections, dataContextPath: dataContextPath)
    }

    /// Write an array of strings into the data model at the given path.
    public func setStringArray(
        path: String, values: [String],
        dataContextPath: String = "/"
    ) {
        dataStore.setStringArray(path: path, values: values, dataContextPath: dataContextPath)
    }

    // MARK: - Data Binding (Path Resolution)

    /// Resolve a `StringValue` to an actual string, looking up paths in the data model.
    /// When both `path` and a literal are present, the literal seeds the data model as
    /// the initial value (only if the path has no existing value) and the result is
    /// always read from the data model so that user edits are preserved.
    public func resolveString(_ value: StringValue, dataContextPath: String = "/") -> String {
        if let path = value.path {
            let fullPath = resolvePath(path, context: dataContextPath)
            if let literal = value.literalValue, getDataByPath(fullPath) == nil {
                setData(path: path, value: .string(literal), dataContextPath: dataContextPath)
            }
            if let data = getDataByPath(fullPath) {
                return data.stringValue ?? ""
            }
            // Fallback: inside a template context, an absolute path like "/name"
            // may actually refer to a field relative to the current item.
            if path.hasPrefix("/"), dataContextPath != "/" {
                let relative = String(path.dropFirst())
                let fallback = resolvePath(relative, context: dataContextPath)
                if let data = getDataByPath(fallback) {
                    return data.stringValue ?? ""
                }
            }
        }
        if let literal = value.literalValue { return literal }
        return ""
    }

    /// Resolve a `NumberValue` to an actual number.
    /// When both `path` and a literal are present, the literal seeds the data model once.
    public func resolveNumber(_ value: NumberValue, dataContextPath: String = "/") -> Double? {
        if let path = value.path {
            let fullPath = resolvePath(path, context: dataContextPath)
            if let literal = value.literalValue, getDataByPath(fullPath) == nil {
                setData(path: path, value: .number(literal), dataContextPath: dataContextPath)
            }
            if let result = getDataByPath(fullPath)?.numberValue {
                return result
            }
            // Fallback: inside a template context, treat absolute path as relative.
            if path.hasPrefix("/"), dataContextPath != "/" {
                let relative = String(path.dropFirst())
                let fallback = resolvePath(relative, context: dataContextPath)
                return getDataByPath(fallback)?.numberValue
            }
        }
        if let literal = value.literalValue { return literal }
        return nil
    }

    /// Resolve a `BooleanValue` to an actual boolean.
    /// When both `path` and a literal are present, the literal seeds the data model once.
    public func resolveBoolean(_ value: BooleanValue, dataContextPath: String = "/") -> Bool? {
        if let path = value.path {
            let fullPath = resolvePath(path, context: dataContextPath)
            if let literal = value.literalValue, getDataByPath(fullPath) == nil {
                setData(path: path, value: .bool(literal), dataContextPath: dataContextPath)
            }
            if let result = getDataByPath(fullPath)?.boolValue {
                return result
            }
            // Fallback: inside a template context, treat absolute path as relative.
            if path.hasPrefix("/"), dataContextPath != "/" {
                let relative = String(path.dropFirst())
                let fallback = resolvePath(relative, context: dataContextPath)
                return getDataByPath(fallback)?.boolValue
            }
        }
        if let literal = value.literalValue { return literal }
        return nil
    }

    // MARK: - Action Resolution

    /// Resolve an action's context entries, converting paths to actual values.
    public func resolveAction(
        _ action: Action,
        sourceComponentId: String,
        dataContextPath: String = "/"
    ) -> ResolvedAction {
        var resolved: [String: AnyCodable] = [:]
        for entry in action.context ?? [] {
            if let path = entry.value.path {
                let full = resolvePath(path, context: dataContextPath)
                var value = getDataByPath(full)
                // Fallback: inside a template context, treat absolute path as relative.
                if value == nil, path.hasPrefix("/"), dataContextPath != "/" {
                    let relative = String(path.dropFirst())
                    let fallback = resolvePath(relative, context: dataContextPath)
                    value = getDataByPath(fallback)
                }
                resolved[entry.key] = value ?? .null
            } else if let s = entry.value.literalString {
                resolved[entry.key] = .string(s)
            } else if let n = entry.value.literalNumber {
                resolved[entry.key] = .number(n)
            } else if let b = entry.value.literalBoolean {
                resolved[entry.key] = .bool(b)
            }
        }
        return ResolvedAction(
            name: action.name,
            sourceComponentId: sourceComponentId,
            context: resolved
        )
    }

    // MARK: - ValueMap → Dictionary Conversion

    /// Recursively converts `[ValueMapEntry]` into `[String: AnyCodable]`.
    public static func convertValueMap(_ entries: [ValueMapEntry]) -> [String: AnyCodable] {
        var result: [String: AnyCodable] = [:]
        for entry in entries {
            if let s = entry.valueString {
                result[entry.key] = .string(s)
            } else if let n = entry.valueNumber {
                result[entry.key] = .number(n)
            } else if let b = entry.valueBoolean ?? entry.valueBool {
                result[entry.key] = .bool(b)
            } else if let map = entry.valueMap {
                result[entry.key] = .dictionary(convertValueMap(map))
            }
        }
        return result
    }

    // MARK: - Component Node Builder (Public API for Custom Renderers)

    /// Build a standalone `ComponentNode` for a component referenced by ID.
    /// Useful for custom renderers that need to render child components (e.g. image
    /// references via `imageChildId`) that are not part of the standard `children` array.
    public func buildComponentNode(
        for componentId: String,
        dataContextPath: String = "/"
    ) -> ComponentNode? {
        guard let instance = components[componentId],
              let payload = instance.component else {
            return nil
        }
        return ComponentNode(
            id: componentId,
            baseComponentId: componentId,
            type: payload.componentType,
            dataContextPath: dataContextPath,
            weight: instance.weight,
            payload: payload,
            children: []
        )
    }

    // MARK: - Component Tree Building

    /// Rebuild the resolved component tree from the current component buffer
    /// and data model, migrating UI state from the previous tree by ID match.
    public func rebuildComponentTree() {
        guard let rootId = rootComponentId else {
            componentTree = nil
            return
        }

        // 1. Collect old UI states
        var oldStateMap: [String: any ComponentUIState] = [:]
        if let oldTree = componentTree {
            collectUIStates(from: oldTree, into: &oldStateMap)
        }

        // 2. Build new tree
        var visited = Set<String>()
        guard let newTree = buildNodeRecursive(
            baseComponentId: rootId,
            visited: &visited,
            dataContextPath: "/",
            idSuffix: ""
        ) else {
            componentTree = nil
            return
        }

        // 3. Migrate UI states from old tree
        migrateUIStates(node: newTree, from: oldStateMap)

        // 4. Try to update existing tree in-place to preserve object identity.
        //    If the structure matches (same IDs in same order), we patch the
        //    existing nodes so SwiftUI does not see a new object graph.
        if let existingTree = componentTree {
            if updateTreeInPlace(existing: existingTree, from: newTree) {
                return // patched in-place, no root replacement needed
            }
        }

        // 5. Structure changed — must replace the root
        componentTree = newTree
    }

    /// Light rebuild for data model changes: only rebuild if template-driven
    /// children actually changed (array/dict size changed). If the tree
    /// structure is identical, the existing nodes stay in place and the views
    /// re-read data reactively from per-key `ObservableValue` slots.
    private func rebuildComponentTreeIfNeeded() {
        guard let rootId = rootComponentId else {
            componentTree = nil
            return
        }
        guard componentTree != nil else {
            // No existing tree — full build
            rebuildComponentTree()
            return
        }

        // Speculatively build a new tree and compare structure
        var visited = Set<String>()
        guard let candidate = buildNodeRecursive(
            baseComponentId: rootId,
            visited: &visited,
            dataContextPath: "/",
            idSuffix: ""
        ) else {
            componentTree = nil
            return
        }

        if let existingTree = componentTree, treeStructureMatches(existing: existingTree, candidate: candidate) {
            // Structure unchanged — views read data reactively, no update needed
            return
        }

        // Structure changed (e.g. template array grew) — full rebuild with migration
        rebuildComponentTree()
    }

    /// Check if two trees have the same ID structure (same IDs in same order).
    private func treeStructureMatches(existing: ComponentNode, candidate: ComponentNode) -> Bool {
        guard existing.id == candidate.id,
              existing.children.count == candidate.children.count else {
            return false
        }
        for i in existing.children.indices {
            if !treeStructureMatches(existing: existing.children[i], candidate: candidate.children[i]) {
                return false
            }
        }
        return true
    }

    /// Recursively patch an existing tree from a new tree, preserving object
    /// identity for `ComponentNode` instances. Returns true if the patch succeeded
    /// (structure was identical), false if the structure differs and a full
    /// replacement is needed.
    private func updateTreeInPlace(existing: ComponentNode, from newNode: ComponentNode) -> Bool {
        guard existing.id == newNode.id,
              existing.children.count == newNode.children.count else {
            return false
        }
        // Patch mutable properties while keeping the same object reference
        existing.payload = newNode.payload
        existing.weight = newNode.weight
        if let newState = newNode.uiState, existing.uiState == nil {
            existing.uiState = newState
        }
        for i in existing.children.indices {
            if !updateTreeInPlace(existing: existing.children[i], from: newNode.children[i]) {
                return false
            }
        }
        return true
    }

    /// Recursively build a `ComponentNode` for the given component ID.
    private func buildNodeRecursive(
        baseComponentId: String,
        visited: inout Set<String>,
        dataContextPath: String,
        idSuffix: String
    ) -> ComponentNode? {
        guard !visited.contains(baseComponentId) else { return nil }
        guard let instance = components[baseComponentId],
              let payload = instance.component else {
            return nil
        }

        let type = payload.componentType

        visited.insert(baseComponentId)
        defer { visited.remove(baseComponentId) }

        let fullId = baseComponentId + idSuffix
        let children = resolveNodeChildren(
            type: type,
            payload: payload,
            visited: &visited,
            dataContextPath: dataContextPath,
            idSuffix: idSuffix
        )

        // Parse accessibility attributes from the raw instance
        let accessibility = Self.parseAccessibility(from: instance)

        let node = ComponentNode(
            id: fullId,
            baseComponentId: baseComponentId,
            type: type,
            dataContextPath: dataContextPath,
            weight: instance.weight,
            payload: payload,
            children: children,
            uiState: createDefaultUIState(for: type),
            accessibility: accessibility
        )
        return node
    }

    /// Dispatch child resolution by component type.
    private func resolveNodeChildren(
        type: ComponentType,
        payload: RawComponentPayload,
        visited: inout Set<String>,
        dataContextPath: String,
        idSuffix: String
    ) -> [ComponentNode] {
        switch type {
        case .Column:
            guard let props = try? payload.typedProperties(ColumnProperties.self) else { return [] }
            return resolveChildrenReference(
                props.children, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            )
        case .Row:
            guard let props = try? payload.typedProperties(RowProperties.self) else { return [] }
            return resolveChildrenReference(
                props.children, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            )
        case .List:
            guard let props = try? payload.typedProperties(ListProperties.self) else { return [] }
            return resolveChildrenReference(
                props.children, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            )
        case .Card:
            guard let props = try? payload.typedProperties(CardProperties.self) else { return [] }
            if let child = buildNodeRecursive(
                baseComponentId: props.child, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            ) {
                return [child]
            }
            return []
        case .Button:
            guard let props = try? payload.typedProperties(ButtonProperties.self) else { return [] }
            if let child = buildNodeRecursive(
                baseComponentId: props.child, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            ) {
                return [child]
            }
            return []
        case .Tabs:
            guard let props = try? payload.typedProperties(TabsProperties.self) else { return [] }
            return props.tabItems.compactMap { item in
                buildNodeRecursive(
                    baseComponentId: item.child, visited: &visited,
                    dataContextPath: dataContextPath, idSuffix: idSuffix
                )
            }
        case .Modal:
            guard let props = try? payload.typedProperties(ModalProperties.self) else { return [] }
            var children: [ComponentNode] = []
            if let entry = buildNodeRecursive(
                baseComponentId: props.entryPointChild, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            ) {
                children.append(entry)
            }
            if let content = buildNodeRecursive(
                baseComponentId: props.contentChild, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            ) {
                children.append(content)
            }
            return children
        default:
            // Leaf components (Text, Image, Icon, Divider, TextField, CheckBox,
            // Slider, DateTimeInput, Video, AudioPlayer, MultipleChoice) have no children.
            // Custom components: attempt to resolve children from a "children" property.
            if case .custom = type {
                return resolveCustomChildren(
                    payload: payload, visited: &visited,
                    dataContextPath: dataContextPath, idSuffix: idSuffix
                )
            }
            return []
        }
    }

    /// Attempt to resolve children for a custom (non-standard) component
    /// by looking for a "children" key in its properties.
    private func resolveCustomChildren(
        payload: RawComponentPayload,
        visited: inout Set<String>,
        dataContextPath: String,
        idSuffix: String
    ) -> [ComponentNode] {
        guard let childrenRaw = payload.properties["children"] else { return [] }
        // Try to decode as ChildrenReference
        do {
            let data = try JSONEncoder().encode(childrenRaw)
            let ref = try JSONDecoder().decode(ChildrenReference.self, from: data)
            return resolveChildrenReference(
                ref, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            )
        } catch {
            // Try as a single child ID
            if let childId = childrenRaw.stringValue {
                if let child = buildNodeRecursive(
                    baseComponentId: childId, visited: &visited,
                    dataContextPath: dataContextPath, idSuffix: idSuffix
                ) {
                    return [child]
                }
            }
            return []
        }
    }

    /// Resolve a `ChildrenReference` into child nodes (explicit list or template).
    private func resolveChildrenReference(
        _ children: ChildrenReference,
        visited: inout Set<String>,
        dataContextPath: String,
        idSuffix: String
    ) -> [ComponentNode] {
        if let list = children.explicitList {
            return list.compactMap { childId in
                buildNodeRecursive(
                    baseComponentId: childId, visited: &visited,
                    dataContextPath: dataContextPath, idSuffix: idSuffix
                )
            }
        }
        if let template = children.template {
            return resolveTemplateChildren(
                template, visited: &visited,
                dataContextPath: dataContextPath
            )
        }
        return []
    }

    /// Expand a template reference against the data model (Array or Dictionary).
    private func resolveTemplateChildren(
        _ template: TemplateReference,
        visited: inout Set<String>,
        dataContextPath: String
    ) -> [ComponentNode] {
        let fullDataPath = resolvePath(template.dataBinding, context: dataContextPath)
        guard let data = getDataByPath(fullDataPath) else { return [] }

        switch data {
        case .array(let items):
            return items.indices.compactMap { index in
                let childContext = "\(fullDataPath)/\(index)"
                let suffix = templateSuffix(dataContextPath: dataContextPath, index: index)
                return buildNodeRecursive(
                    baseComponentId: template.componentId,
                    visited: &visited,
                    dataContextPath: childContext,
                    idSuffix: suffix
                )
            }
        case .dictionary(let dict):
            let sortedKeys = dict.keys.sorted()
            return sortedKeys.compactMap { key in
                let childContext = "\(fullDataPath)/\(key)"
                let suffix = ":\(key)"
                return buildNodeRecursive(
                    baseComponentId: template.componentId,
                    visited: &visited,
                    dataContextPath: childContext,
                    idSuffix: suffix
                )
            }
        default:
            return []
        }
    }

    /// Build a synthetic ID suffix matching web_core format: `:parentIdx:childIdx`
    private func templateSuffix(dataContextPath: String, index: Int) -> String {
        let parentIndices = dataContextPath
            .split(separator: "/")
            .filter { $0.allSatisfy(\.isNumber) }
        let allIndices = parentIndices.map(String.init) + [String(index)]
        return ":\(allIndices.joined(separator: ":"))"
    }

    // MARK: - UI State Migration

    /// Recursively collect all `[id: uiState]` entries from a tree.
    private func collectUIStates(
        from node: ComponentNode,
        into map: inout [String: any ComponentUIState]
    ) {
        if let state = node.uiState {
            map[node.id] = state
        }
        for child in node.children {
            collectUIStates(from: child, into: &map)
        }
    }

    /// Recursively replace default UI states with old ones matched by ID.
    private func migrateUIStates(
        node: ComponentNode,
        from map: [String: any ComponentUIState]
    ) {
        if let oldState = map[node.id], let newState = node.uiState,
           type(of: oldState) == type(of: newState) {
            node.uiState = oldState
        }
        for child in node.children {
            migrateUIStates(node: child, from: map)
        }
    }

    /// Create a default UI state for component types that need one.
    private func createDefaultUIState(for type: ComponentType) -> (any ComponentUIState)? {
        switch type {
        case .Tabs: return TabsUIState()
        case .Modal: return ModalUIState()
        case .AudioPlayer: return AudioPlayerUIState()
        case .Video: return VideoUIState()
        case .MultipleChoice: return MultipleChoiceUIState()
        case .custom: return nil
        default: return nil
        }
    }

    // MARK: - Accessibility Parsing

    /// Parse accessibility attributes from a raw component instance.
    private static func parseAccessibility(from instance: RawComponentInstance) -> A2UIAccessibility? {
        guard let payload = instance.component,
              let accessibilityRaw = payload.properties["accessibility"],
              case .dictionary(let dict) = accessibilityRaw else {
            return nil
        }

        var label: StringValue?
        var description: StringValue?

        if let labelRaw = dict["label"] {
            label = decodeStringValue(from: labelRaw)
        }
        if let descRaw = dict["description"] {
            description = decodeStringValue(from: descRaw)
        }

        guard label != nil || description != nil else { return nil }
        return A2UIAccessibility(label: label, description: description)
    }

    /// Decode a StringValue from an AnyCodable (handles string literal and path).
    private static func decodeStringValue(from raw: AnyCodable) -> StringValue? {
        switch raw {
        case .string(let s):
            return StringValue(literalString: s)
        case .dictionary(let dict):
            if let path = dict["path"]?.stringValue {
                return StringValue(path: path)
            }
            return nil
        default:
            return nil
        }
    }
}
