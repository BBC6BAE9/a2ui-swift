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

/// Core state manager for a single v0.9 A2UI surface.
/// Processes createSurface/updateComponents/updateDataModel/deleteSurface messages.
@Observable
public final class SurfaceViewModel_V09 {
    public var surfaceId: String?
    public var catalogId: String?
    public var rootComponentId: String?
    public var components: [String: RawComponentInstance_V09] = [:]
    public var a2uiStyle = A2UIStyle()
    public var lastAction: ResolvedAction?
    public var componentTree: ComponentNode_V09?
    public var sendDataModel: Bool = false

    /// v0.9 spec: one component must have id "root" to serve as the root.
    private static let defaultRootId = "root"

    public let dataStore = DataStore_V09()

    public var dataModel: [String: AnyCodable] {
        get { dataStore.dataModel }
        set { dataStore.dataModel = newValue }
    }

    public var dataStoreKeys: [String] { dataStore.dataStoreKeys }

    public init() {}

    // MARK: - Message Processing

    public func processMessages(_ messages: [ServerToClientMessage_V09]) throws {
        for message in messages {
            try processMessage(message)
        }
    }

    public func processMessage(_ message: ServerToClientMessage_V09) throws {
        if let cs = message.createSurface {
            handleCreateSurface(cs)
        }
        if let uc = message.updateComponents {
            try handleUpdateComponents(uc)
        }
        if let udm = message.updateDataModel {
            handleUpdateDataModel(udm)
        }
        if message.deleteSurface != nil {
            handleDeleteSurface()
        }
    }

    // MARK: - Message Handlers

    private func handleCreateSurface(_ message: CreateSurfaceMessage_V09) {
        surfaceId = message.surfaceId
        catalogId = message.catalogId
        sendDataModel = message.sendDataModel ?? false

        if let theme = message.theme, case .dictionary(let themeDict) = theme {
            var styles: [String: String] = [:]
            for (key, value) in themeDict {
                if let s = value.stringValue {
                    styles[key] = s
                }
            }
            a2uiStyle = A2UIStyle(from: styles)
        }

        rebuildComponentTree()
    }

    private func handleUpdateComponents(_ message: UpdateComponentsMessage_V09) throws {
        for component in message.components {
            components[component.id] = component
            if component.id == Self.defaultRootId {
                rootComponentId = Self.defaultRootId
            }
        }
        rebuildComponentTree()
    }

    private func handleUpdateDataModel(_ message: UpdateDataModelMessage_V09) {
        dataStore.handleUpdateDataModel(path: message.path, value: message.value)
        rebuildComponentTreeIfNeeded()
    }

    private func handleDeleteSurface() {
        rootComponentId = nil
        components.removeAll()
        dataStore.removeAll()
        a2uiStyle = A2UIStyle()
        componentTree = nil
    }

    // MARK: - Data Binding (v0.9 DynamicValue resolution)

    /// Resolve a `DynamicString_V09` to a string value.
    public func resolveString(_ value: DynamicString_V09, dataContextPath: String = "/") -> String {
        switch value {
        case .literal(let s):
            return s
        case .dataBinding(let path):
            let fullPath = dataStore.resolvePath(path, context: dataContextPath)
            if let data = dataStore.getDataByPath(fullPath) {
                switch data {
                case .string(let s): return s
                case .number(let n): return String(n)
                case .bool(let b): return String(b)
                default: return ""
                }
            }
            return ""
        case .functionCall:
            // Function calls not yet fully implemented
            return ""
        }
    }

    /// Resolve a `DynamicNumber_V09` to a number value.
    public func resolveNumber(_ value: DynamicNumber_V09, dataContextPath: String = "/") -> Double? {
        switch value {
        case .literal(let n):
            return n
        case .dataBinding(let path):
            let fullPath = dataStore.resolvePath(path, context: dataContextPath)
            return dataStore.getDataByPath(fullPath)?.numberValue
        case .functionCall:
            return nil
        }
    }

    /// Resolve a `DynamicBoolean_V09` to a boolean value.
    public func resolveBoolean(_ value: DynamicBoolean_V09, dataContextPath: String = "/") -> Bool? {
        switch value {
        case .literal(let b):
            return b
        case .dataBinding(let path):
            let fullPath = dataStore.resolvePath(path, context: dataContextPath)
            return dataStore.getDataByPath(fullPath)?.boolValue
        case .functionCall:
            return nil
        }
    }

    // MARK: - Action Resolution

    /// Resolve a v0.9 action to a ResolvedAction (shared type).
    public func resolveAction(
        _ action: Action_V09,
        sourceComponentId: String,
        dataContextPath: String = "/"
    ) -> ResolvedAction? {
        switch action {
        case .event(let name, let context):
            var resolved: [String: AnyCodable] = [:]
            if let ctx = context {
                for (key, dynamicVal) in ctx {
                    resolved[key] = resolveDynamicValue(dynamicVal, dataContextPath: dataContextPath)
                }
            }
            return ResolvedAction(
                name: name,
                sourceComponentId: sourceComponentId,
                context: resolved
            )
        case .functionCall(let fc):
            // Client-side function calls (e.g., openUrl) — not yet fully implemented
            return ResolvedAction(
                name: fc.call,
                sourceComponentId: sourceComponentId,
                context: [:]
            )
        }
    }

    /// Resolve a general DynamicValue to AnyCodable.
    private func resolveDynamicValue(_ value: DynamicValue_V09, dataContextPath: String) -> AnyCodable {
        switch value {
        case .string(let s): return .string(s)
        case .number(let n): return .number(n)
        case .bool(let b): return .bool(b)
        case .array(let arr): return .array(arr)
        case .dataBinding(let path):
            let fullPath = dataStore.resolvePath(path, context: dataContextPath)
            return dataStore.getDataByPath(fullPath) ?? .null
        case .functionCall:
            return .null
        }
    }

    // MARK: - Component Node Builder (Public API for Custom Renderers)

    public func buildComponentNode(
        for componentId: String,
        dataContextPath: String = "/"
    ) -> ComponentNode_V09? {
        guard let instance = components[componentId] else { return nil }
        return ComponentNode_V09(
            id: componentId,
            baseComponentId: componentId,
            type: instance.componentType,
            dataContextPath: dataContextPath,
            weight: instance.weight,
            instance: instance,
            children: []
        )
    }

    // MARK: - Component Tree Building

    public func rebuildComponentTree() {
        guard let rootId = rootComponentId else {
            componentTree = nil
            return
        }

        var oldStateMap: [String: any ComponentUIState] = [:]
        if let oldTree = componentTree {
            collectUIStates(from: oldTree, into: &oldStateMap)
        }

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

        migrateUIStates(node: newTree, from: oldStateMap)

        if let existingTree = componentTree {
            if updateTreeInPlace(existing: existingTree, from: newTree) {
                return
            }
        }

        componentTree = newTree
    }

    private func rebuildComponentTreeIfNeeded() {
        guard let rootId = rootComponentId else {
            componentTree = nil
            return
        }
        guard componentTree != nil else {
            rebuildComponentTree()
            return
        }

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
            return
        }

        rebuildComponentTree()
    }

    private func treeStructureMatches(existing: ComponentNode_V09, candidate: ComponentNode_V09) -> Bool {
        guard existing.id == candidate.id,
              existing.children.count == candidate.children.count else { return false }
        for i in existing.children.indices {
            if !treeStructureMatches(existing: existing.children[i], candidate: candidate.children[i]) {
                return false
            }
        }
        return true
    }

    private func updateTreeInPlace(existing: ComponentNode_V09, from newNode: ComponentNode_V09) -> Bool {
        guard existing.id == newNode.id,
              existing.children.count == newNode.children.count else { return false }
        existing.instance = newNode.instance
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

    private func buildNodeRecursive(
        baseComponentId: String,
        visited: inout Set<String>,
        dataContextPath: String,
        idSuffix: String
    ) -> ComponentNode_V09? {
        guard !visited.contains(baseComponentId) else { return nil }
        guard let instance = components[baseComponentId] else { return nil }

        let type = instance.componentType

        visited.insert(baseComponentId)
        defer { visited.remove(baseComponentId) }

        let fullId = baseComponentId + idSuffix
        let children = resolveNodeChildren(
            type: type,
            instance: instance,
            visited: &visited,
            dataContextPath: dataContextPath,
            idSuffix: idSuffix
        )

        let node = ComponentNode_V09(
            id: fullId,
            baseComponentId: baseComponentId,
            type: type,
            dataContextPath: dataContextPath,
            weight: instance.weight,
            instance: instance,
            children: children,
            uiState: createDefaultUIState(for: type)
        )
        return node
    }

    /// Dispatch child resolution by component type.
    private func resolveNodeChildren(
        type: ComponentType_V09,
        instance: RawComponentInstance_V09,
        visited: inout Set<String>,
        dataContextPath: String,
        idSuffix: String
    ) -> [ComponentNode_V09] {
        switch type {
        case .Column:
            guard let props = try? instance.typedProperties(ColumnProperties_V09.self) else { return [] }
            return resolveChildList(
                props.children, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            )
        case .Row:
            guard let props = try? instance.typedProperties(RowProperties_V09.self) else { return [] }
            return resolveChildList(
                props.children, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            )
        case .List:
            guard let props = try? instance.typedProperties(ListProperties_V09.self) else { return [] }
            return resolveChildList(
                props.children, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            )
        case .Card:
            guard let props = try? instance.typedProperties(CardProperties_V09.self) else { return [] }
            if let child = buildNodeRecursive(
                baseComponentId: props.child, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            ) { return [child] }
            return []
        case .Button:
            guard let props = try? instance.typedProperties(ButtonProperties_V09.self) else { return [] }
            if let child = buildNodeRecursive(
                baseComponentId: props.child, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            ) { return [child] }
            return []
        case .Tabs:
            guard let props = try? instance.typedProperties(TabsProperties_V09.self) else { return [] }
            return props.tabs.compactMap { item in
                buildNodeRecursive(
                    baseComponentId: item.child, visited: &visited,
                    dataContextPath: dataContextPath, idSuffix: idSuffix
                )
            }
        case .Modal:
            guard let props = try? instance.typedProperties(ModalProperties_V09.self) else { return [] }
            var children: [ComponentNode_V09] = []
            if let trigger = buildNodeRecursive(
                baseComponentId: props.trigger, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            ) { children.append(trigger) }
            if let content = buildNodeRecursive(
                baseComponentId: props.content, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            ) { children.append(content) }
            return children
        default:
            if case .custom = type {
                return resolveCustomChildren(
                    instance: instance, visited: &visited,
                    dataContextPath: dataContextPath, idSuffix: idSuffix
                )
            }
            return []
        }
    }

    /// Resolve a `ChildList_V09` into child nodes.
    private func resolveChildList(
        _ children: ChildList_V09,
        visited: inout Set<String>,
        dataContextPath: String,
        idSuffix: String
    ) -> [ComponentNode_V09] {
        switch children {
        case .staticList(let ids):
            return ids.compactMap { childId in
                buildNodeRecursive(
                    baseComponentId: childId, visited: &visited,
                    dataContextPath: dataContextPath, idSuffix: idSuffix
                )
            }
        case .template(let componentId, let path):
            return resolveTemplateChildren(
                componentId: componentId, path: path,
                visited: &visited, dataContextPath: dataContextPath
            )
        }
    }

    /// Expand a template against data model.
    private func resolveTemplateChildren(
        componentId: String,
        path: String,
        visited: inout Set<String>,
        dataContextPath: String
    ) -> [ComponentNode_V09] {
        let fullDataPath = dataStore.resolvePath(path, context: dataContextPath)
        guard let data = dataStore.getDataByPath(fullDataPath) else { return [] }

        switch data {
        case .array(let items):
            return items.indices.compactMap { index in
                let childContext = "\(fullDataPath)/\(index)"
                let suffix = templateSuffix(dataContextPath: dataContextPath, index: index)
                return buildNodeRecursive(
                    baseComponentId: componentId,
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
                    baseComponentId: componentId,
                    visited: &visited,
                    dataContextPath: childContext,
                    idSuffix: suffix
                )
            }
        default:
            return []
        }
    }

    private func resolveCustomChildren(
        instance: RawComponentInstance_V09,
        visited: inout Set<String>,
        dataContextPath: String,
        idSuffix: String
    ) -> [ComponentNode_V09] {
        guard let childrenRaw = instance.properties["children"] else { return [] }
        do {
            let data = try JSONEncoder().encode(childrenRaw)
            let ref = try JSONDecoder().decode(ChildList_V09.self, from: data)
            return resolveChildList(
                ref, visited: &visited,
                dataContextPath: dataContextPath, idSuffix: idSuffix
            )
        } catch {
            if let childId = childrenRaw.stringValue {
                if let child = buildNodeRecursive(
                    baseComponentId: childId, visited: &visited,
                    dataContextPath: dataContextPath, idSuffix: idSuffix
                ) { return [child] }
            }
            return []
        }
    }

    private func templateSuffix(dataContextPath: String, index: Int) -> String {
        let parentIndices = dataContextPath
            .split(separator: "/")
            .filter { $0.allSatisfy(\.isNumber) }
        let allIndices = parentIndices.map(String.init) + [String(index)]
        return ":\(allIndices.joined(separator: ":"))"
    }

    // MARK: - UI State

    private func collectUIStates(
        from node: ComponentNode_V09,
        into map: inout [String: any ComponentUIState]
    ) {
        if let state = node.uiState { map[node.id] = state }
        for child in node.children { collectUIStates(from: child, into: &map) }
    }

    private func migrateUIStates(
        node: ComponentNode_V09,
        from map: [String: any ComponentUIState]
    ) {
        if let oldState = map[node.id], let newState = node.uiState,
           type(of: oldState) == type(of: newState) {
            node.uiState = oldState
        }
        for child in node.children { migrateUIStates(node: child, from: map) }
    }

    private func createDefaultUIState(for type: ComponentType_V09) -> (any ComponentUIState)? {
        switch type {
        case .Tabs: return TabsUIState()
        case .Modal: return ModalUIState()
        case .AudioPlayer: return AudioPlayerUIState()
        case .Video: return VideoUIState()
        case .ChoicePicker: return MultipleChoiceUIState()
        case .custom: return nil
        default: return nil
        }
    }
}
