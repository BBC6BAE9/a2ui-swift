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
import A2UISwiftCore

// MARK: - SurfaceViewModel

/// SwiftUI-specific wrapper around `SurfaceModel`.
///
/// This class has a single responsibility: maintain the `ComponentNode` tree that
/// SwiftUI views use to render. All data storage and resolution lives in `SurfaceModel`
/// (and its `DataModel` + `DataContext`), which are the same protocol-layer objects
/// that `MessageProcessor` manages.
///
/// # Why this class exists (Swift-specific, no WebCore equivalent)
/// SwiftUI needs an `@Observable` object to trigger structural re-renders when the
/// component tree changes (e.g. new components arrive, list template expands). React/Angular
/// handle this natively in their rendering loops; SwiftUI does not. `SurfaceViewModel`
/// fills that gap — and nothing else.
///
/// # Data flow
/// ```
/// MessageProcessor.processMessages()
///   → SurfaceModel.dataModel (PathSlot @Observable)  ← data lives here
///   → SurfaceModel.componentsModel                   ← component definitions live here
///
/// SurfaceViewModel.processMessage()
///   → updates componentTree (@Observable)             ← tree structure lives here
///
/// SwiftUI View.body
///   → reads componentTree for structure
///   → creates DataContext(surface: surfaceModel, path: node.dataContextPath)
///   → calls dataContext.resolve(props.text)
///        → reads PathSlot.value (@Observable)
///        → SwiftUI tracks per-path dependency automatically
/// ```
@Observable
public final class SurfaceViewModel {

    // MARK: - Public state

    /// The rendered component tree. Views use this to walk and render the hierarchy.
    public var componentTree: ComponentNode?

    /// Theme styles parsed from `createSurface.theme`.
    public var a2uiStyle = A2UIStyle()

    /// The underlying surface. Views create `DataContext(surface: surface, ...)` from this.
    public private(set) var surface: SurfaceModel

    // MARK: - Private

    private var components: [String: RawComponent] = [:]
    private var rootComponentId: String?
    private static let defaultRootId = "root"

    // MARK: - Init

    /// Creates a SurfaceViewModel backed by an existing SurfaceModel.
    /// Use this when `MessageProcessor` owns the surface lifecycle.
    public init(surface: SurfaceModel) {
        self.surface = surface
    }

    /// Creates a SurfaceViewModel with a new SurfaceModel for the given catalog.
    /// Convenience for simple single-surface apps.
    public convenience init(catalog: Catalog) {
        self.init(surface: SurfaceModel(id: UUID().uuidString, catalog: catalog))
    }

    // MARK: - Message Processing

    /// Processes a batch of server-to-client messages.
    /// Per spec §76-82: if one message fails, logs the error and continues with the rest.
    /// Returns any errors that occurred during processing (empty if all succeeded).
    @discardableResult
    public func processMessages(_ messages: [A2uiMessage]) -> [Error] {
        var errors: [Error] = []
        for message in messages {
            do {
                try processMessage(message)
            } catch {
                errors.append(error)
            }
        }
        return errors
    }

    public func processMessage(_ message: A2uiMessage) throws {
        switch message {
        case .createSurface(let payload):
            handleCreateSurface(payload)
        case .updateComponents(let payload):
            try handleUpdateComponents(payload)
        case .updateDataModel(let payload):
            try handleUpdateDataModel(payload)
        case .deleteSurface:
            handleDeleteSurface()
        }
    }

    // MARK: - Action subscription

    /// Subscribe to actions dispatched from components on this surface.
    /// Returns a `Subscription` token — keep it alive for as long as you want to receive events.
    @discardableResult
    public func onAction(_ handler: @escaping (A2uiClientAction) -> Void) -> Subscription {
        surface.onAction.subscribe(handler)
    }

    /// Returns the client data model for this surface if `sendDataModel` is enabled.
    /// Per spec §515-583: attach this as `a2uiClientDataModel` in transport metadata
    /// alongside every outgoing action from this surface.
    /// Returns `nil` if `sendDataModel` is false for this surface.
    public func getClientDataModel() -> A2uiClientDataModel? {
        guard surface.sendDataModel else { return nil }
        return A2uiClientDataModel(
            version: "v0.9",
            surfaces: [surface.id: surface.dataModel.get("/") ?? .null]
        )
    }

    // MARK: - DataContext factory

    /// Creates a `DataContext` scoped to the given path.
    /// Views should call this inside `body` so SwiftUI tracks per-path dependencies.
    public func makeDataContext(path: String = "/") -> DataContext {
        DataContext(surface: surface, path: path)
    }

    // MARK: - Message Handlers

    private func handleCreateSurface(_ payload: CreateSurfacePayload) {
        if let theme = payload.theme, case .dictionary(let themeDict) = theme {
            var styles: [String: String] = [:]
            for (key, value) in themeDict {
                if let s = value.stringValue { styles[key] = s }
            }
            a2uiStyle = A2UIStyle(from: styles)
        }
        rebuildComponentTree()
    }

    private func handleUpdateComponents(_ payload: UpdateComponentsPayload) throws {
        for component in payload.components {
            components[component.id] = component
            if component.id == Self.defaultRootId {
                rootComponentId = Self.defaultRootId
            }
        }
        rebuildComponentTree()
    }

    private func handleUpdateDataModel(_ payload: UpdateDataModelPayload) throws {
        // Forward to the protocol-layer DataModel — PathSlots update here,
        // and SwiftUI views that read those slots re-render automatically.
        let path = payload.path ?? "/"
        try surface.dataModel.set(path, value: payload.value)
        // Data-only update: tree structure unchanged, no rebuild needed.
    }

    private func handleDeleteSurface() {
        rootComponentId = nil
        components.removeAll()
        a2uiStyle = A2UIStyle()
        componentTree = nil
        surface.dispose()
    }

    // MARK: - Component Tree Building

    public func rebuildComponentTree() {
        guard let rootId = rootComponentId else {
            // Per spec §179: if components exist but root is not yet defined,
            // report a validation error and render nothing.
            if !components.isEmpty {
                surface.dispatchError(
                    code: "VALIDATION_FAILED",
                    message: "Root component not found. At least one component must have id=\"root\"."
                )
            }
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

        if let existingTree = componentTree,
           updateTreeInPlace(existing: existingTree, from: newTree) {
            return
        }

        componentTree = newTree
    }

    private func buildNodeRecursive(
        baseComponentId: String,
        visited: inout Set<String>,
        dataContextPath: String,
        idSuffix: String
    ) -> ComponentNode? {
        guard !visited.contains(baseComponentId) else { return nil }
        guard let instance = components[baseComponentId] else { return nil }

        let type = instance.componentType
        visited.insert(baseComponentId)
        defer { visited.remove(baseComponentId) }

        let fullId = baseComponentId + idSuffix
        let children = resolveNodeChildren(
            type: type, instance: instance,
            visited: &visited, dataContextPath: dataContextPath, idSuffix: idSuffix
        )
        return ComponentNode(
            id: fullId, baseComponentId: baseComponentId,
            type: type, dataContextPath: dataContextPath,
            weight: instance.weight, instance: instance,
            children: children, uiState: createDefaultUIState(for: type),
            accessibility: instance.accessibility
        )
    }

    private func resolveNodeChildren(
        type: ComponentType, instance: RawComponent,
        visited: inout Set<String>, dataContextPath: String, idSuffix: String
    ) -> [ComponentNode] {
        switch type {
        case .Column:
            guard let props = try? instance.typedProperties(ColumnProperties.self) else { return [] }
            return resolveChildList(props.children, visited: &visited, dataContextPath: dataContextPath, idSuffix: idSuffix)
        case .Row:
            guard let props = try? instance.typedProperties(RowProperties.self) else { return [] }
            return resolveChildList(props.children, visited: &visited, dataContextPath: dataContextPath, idSuffix: idSuffix)
        case .List:
            guard let props = try? instance.typedProperties(ListProperties.self) else { return [] }
            return resolveChildList(props.children, visited: &visited, dataContextPath: dataContextPath, idSuffix: idSuffix)
        case .Card:
            guard let props = try? instance.typedProperties(CardProperties.self) else { return [] }
            return buildNodeRecursive(baseComponentId: props.child, visited: &visited, dataContextPath: dataContextPath, idSuffix: idSuffix).map { [$0] } ?? []
        case .Button:
            guard let props = try? instance.typedProperties(ButtonProperties.self) else { return [] }
            return buildNodeRecursive(baseComponentId: props.child, visited: &visited, dataContextPath: dataContextPath, idSuffix: idSuffix).map { [$0] } ?? []
        case .Tabs:
            guard let props = try? instance.typedProperties(TabsProperties.self) else { return [] }
            return props.tabs.compactMap { buildNodeRecursive(baseComponentId: $0.child, visited: &visited, dataContextPath: dataContextPath, idSuffix: idSuffix) }
        case .Modal:
            guard let props = try? instance.typedProperties(ModalProperties.self) else { return [] }
            var children: [ComponentNode] = []
            if let t = buildNodeRecursive(baseComponentId: props.trigger, visited: &visited, dataContextPath: dataContextPath, idSuffix: idSuffix) { children.append(t) }
            if let c = buildNodeRecursive(baseComponentId: props.content, visited: &visited, dataContextPath: dataContextPath, idSuffix: idSuffix) { children.append(c) }
            return children
        default:
            if case .custom = type {
                return resolveCustomChildren(instance: instance, visited: &visited, dataContextPath: dataContextPath, idSuffix: idSuffix)
            }
            return []
        }
    }

    private func resolveChildList(
        _ children: ChildList, visited: inout Set<String>,
        dataContextPath: String, idSuffix: String
    ) -> [ComponentNode] {
        switch children {
        case .staticList(let ids):
            return ids.compactMap { buildNodeRecursive(baseComponentId: $0, visited: &visited, dataContextPath: dataContextPath, idSuffix: idSuffix) }
        case .template(let componentId, let path):
            return resolveTemplateChildren(componentId: componentId, path: path, visited: &visited, dataContextPath: dataContextPath)
        }
    }

    private func resolveTemplateChildren(
        componentId: String, path: String,
        visited: inout Set<String>, dataContextPath: String
    ) -> [ComponentNode] {
        // Resolve the data path directly from DataModel (non-reactive; tree rebuild handles updates).
        let dc = DataContext(surface: surface, path: dataContextPath)
        let fullPath = dc.resolvePath(path)
        guard let data = surface.dataModel.get(fullPath) else { return [] }

        switch data {
        case .array(let items):
            return items.indices.compactMap { index in
                let childContext = "\(fullPath)/\(index)"
                let suffix = templateSuffix(dataContextPath: dataContextPath, index: index)
                return buildNodeRecursive(baseComponentId: componentId, visited: &visited, dataContextPath: childContext, idSuffix: suffix)
            }
        case .dictionary(let dict):
            return dict.keys.sorted().compactMap { key in
                buildNodeRecursive(baseComponentId: componentId, visited: &visited, dataContextPath: "\(fullPath)/\(key)", idSuffix: ":\(key)")
            }
        default:
            return []
        }
    }

    private func resolveCustomChildren(
        instance: RawComponent, visited: inout Set<String>,
        dataContextPath: String, idSuffix: String
    ) -> [ComponentNode] {
        // 1. Resolve explicit "children" property (existing logic).
        var resolvedIds = Set<String>()
        var result: [ComponentNode] = []

        if let childrenRaw = instance.properties["children"] {
            do {
                let data = try JSONEncoder().encode(childrenRaw)
                let ref = try JSONDecoder().decode(ChildList.self, from: data)
                let nodes = resolveChildList(ref, visited: &visited, dataContextPath: dataContextPath, idSuffix: idSuffix)
                for node in nodes {
                    resolvedIds.insert(node.baseComponentId)
                }
                result.append(contentsOf: nodes)
            } catch {
                if let childId = childrenRaw.stringValue,
                   let child = buildNodeRecursive(baseComponentId: childId, visited: &visited, dataContextPath: dataContextPath, idSuffix: idSuffix) {
                    resolvedIds.insert(child.baseComponentId)
                    result.append(child)
                }
            }
        }

        // 2. Deep-scan all properties for component ID references (e.g. imageChildId in TravelCarousel items).
        //    This ensures custom components that reference children via arbitrary property names
        //    (not just "children") get those child nodes resolved into the tree.
        var referencedIds = Set<String>()
        for (key, value) in instance.properties where key != "children" {
            collectStringValues(from: value, into: &referencedIds)
        }

        for refId in referencedIds where !resolvedIds.contains(refId) {
            if components[refId] != nil,
               let child = buildNodeRecursive(baseComponentId: refId, visited: &visited, dataContextPath: dataContextPath, idSuffix: idSuffix) {
                resolvedIds.insert(refId)
                result.append(child)
            }
        }

        return result
    }

    /// Recursively collects all string values from an `AnyCodable` value tree.
    private func collectStringValues(from value: AnyCodable, into result: inout Set<String>) {
        switch value {
        case .string(let s):
            result.insert(s)
        case .array(let items):
            for item in items {
                collectStringValues(from: item, into: &result)
            }
        case .dictionary(let dict):
            for (_, v) in dict {
                collectStringValues(from: v, into: &result)
            }
        default:
            break
        }
    }

    private func templateSuffix(dataContextPath: String, index: Int) -> String {
        let parentIndices = dataContextPath.split(separator: "/").filter { $0.allSatisfy(\.isNumber) }
        return ":\((parentIndices.map(String.init) + [String(index)]).joined(separator: ":"))"
    }

    // MARK: - In-place tree update (avoids full SwiftUI re-render for data-only changes)

    private func updateTreeInPlace(existing: ComponentNode, from new: ComponentNode) -> Bool {
        guard existing.id == new.id, existing.children.count == new.children.count else { return false }
        existing.instance = new.instance
        existing.weight = new.weight
        if let newState = new.uiState, existing.uiState == nil { existing.uiState = newState }
        for i in existing.children.indices {
            if !updateTreeInPlace(existing: existing.children[i], from: new.children[i]) { return false }
        }
        return true
    }

    // MARK: - UI State

    private func collectUIStates(from node: ComponentNode, into map: inout [String: any ComponentUIState]) {
        if let state = node.uiState { map[node.id] = state }
        for child in node.children { collectUIStates(from: child, into: &map) }
    }

    private func migrateUIStates(node: ComponentNode, from map: [String: any ComponentUIState]) {
        if let old = map[node.id], let new = node.uiState, type(of: old) == type(of: new) {
            node.uiState = old
        }
        for child in node.children { migrateUIStates(node: child, from: map) }
    }

    private func createDefaultUIState(for type: ComponentType) -> (any ComponentUIState)? {
        switch type {
        case .Tabs: return TabsUIState()
        case .Modal: return ModalUIState()
        case .AudioPlayer: return AudioPlayerUIState()
        case .Video: return VideoUIState()
        case .ChoicePicker: return MultipleChoiceUIState()
        default: return nil
        }
    }
}
