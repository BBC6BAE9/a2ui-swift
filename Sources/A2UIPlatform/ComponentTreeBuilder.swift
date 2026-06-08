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

#if (canImport(UIKit) && !os(watchOS)) || canImport(AppKit)
import Foundation
import A2UISwiftCore

// MARK: - ComponentTreeBuilder
//
// Resolves `SurfaceModel` component definitions → a `ComponentNode` tree.
// Mirrors the relevant parts of SwiftUI's `SurfaceViewModel` (which lives in the
// SwiftUI target, not Core), so the imperative renderers have their own shared copy.
//
// Type-aware children + template (data-array / -dictionary) expansion. Template
// resolution is non-reactive: the runtime rebuilds the tree when a template's
// bound data changes — `buildTree` reports those paths so the host can watch them.

enum ComponentTreeBuilder {

    struct Result {
        let root: ComponentNode?
        /// Data paths whose contents drive template expansion. The runtime
        /// subscribes to these and rebuilds when any of them changes.
        let templatePaths: Set<String>
    }

    static func buildTree(surface: SurfaceModel, rootComponentId: String) -> Result {
        var templatePaths = Set<String>()
        let root = build(surface: surface, componentId: rootComponentId,
                         dataContextPath: "/", idSuffix: "", visited: [],
                         templatePaths: &templatePaths)
        return Result(root: root, templatePaths: templatePaths)
    }

    /// Builds the node subtree rooted at `componentId`.
    /// - `idSuffix`: makes node ids unique across template expansions
    ///   (node `id` = `componentId + idSuffix`; `baseComponentId` stays the template id).
    static func build(
        surface: SurfaceModel,
        componentId: String,
        dataContextPath: String,
        idSuffix: String,
        visited: Set<String>,
        templatePaths: inout Set<String>
    ) -> ComponentNode? {
        guard !visited.contains(componentId),
              let model = surface.componentsModel.get(componentId) else { return nil }
        var visited = visited
        visited.insert(componentId)

        let type = ComponentType.from(model.type)
        let instance = RawComponent(id: model.id, component: model.type, properties: model.properties)
        let children = resolveChildren(
            surface: surface, model: model, type: type,
            dataContextPath: dataContextPath, idSuffix: idSuffix,
            visited: visited, templatePaths: &templatePaths
        )

        return ComponentNode(
            id: componentId + idSuffix,
            baseComponentId: componentId,
            type: type,
            dataContextPath: dataContextPath,
            weight: model.properties["weight"]?.numberValue,
            instance: instance,
            children: children
        )
    }

    // MARK: - Children

    /// Type-aware child resolution — mirrors SwiftUI's `resolveNodeChildren`.
    private static func resolveChildren(
        surface: SurfaceModel, model: ComponentModel, type: ComponentType,
        dataContextPath: String, idSuffix: String, visited: Set<String>,
        templatePaths: inout Set<String>
    ) -> [ComponentNode] {
        var paths = templatePaths
        defer { templatePaths = paths }

        func child(_ id: String?) -> [ComponentNode] {
            guard let id else { return [] }
            return build(surface: surface, componentId: id,
                         dataContextPath: dataContextPath, idSuffix: idSuffix,
                         visited: visited, templatePaths: &paths).map { [$0] } ?? []
        }

        switch type {
        case .Row, .Column, .List:
            guard let childList = decodeChildList(model) else { return [] }
            switch childList {
            case .staticList(let ids):
                return ids.compactMap {
                    build(surface: surface, componentId: $0,
                          dataContextPath: dataContextPath, idSuffix: idSuffix,
                          visited: visited, templatePaths: &paths)
                }
            case .template(let componentId, let path):
                return resolveTemplate(surface: surface, componentId: componentId, path: path,
                                       dataContextPath: dataContextPath, visited: visited,
                                       templatePaths: &paths)
            }

        case .Card, .Button:
            return child(model.properties["child"]?.stringValue)

        case .Modal:
            return child(model.properties["trigger"]?.stringValue)
                 + child(model.properties["content"]?.stringValue)

        case .Tabs:
            guard case .array(let items)? = model.properties["tabs"] else { return [] }
            return items.compactMap { $0.dictionaryValue?["child"]?.stringValue }.flatMap { child($0) }

        default:
            return [] // leaf components have no children
        }
    }

    /// Expands a template over the data at `path`: one child per array element
    /// (scoped to `<fullPath>/<index>`) or per sorted dictionary key.
    private static func resolveTemplate(
        surface: SurfaceModel, componentId: String, path: String,
        dataContextPath: String, visited: Set<String>, templatePaths: inout Set<String>
    ) -> [ComponentNode] {
        let dc = DataContext(surface: surface, path: dataContextPath)
        let fullPath = dc.resolvePath(path)
        templatePaths.insert(fullPath) // runtime watches this for changes
        guard let data = surface.dataModel.get(fullPath) else { return [] }

        switch data {
        case .array(let items):
            return items.indices.compactMap { index in
                build(surface: surface, componentId: componentId,
                      dataContextPath: "\(fullPath)/\(index)",
                      idSuffix: templateSuffix(dataContextPath: dataContextPath, index: index),
                      visited: visited, templatePaths: &templatePaths)
            }
        case .dictionary(let dict):
            return dict.keys.sorted().compactMap { key in
                build(surface: surface, componentId: componentId,
                      dataContextPath: "\(fullPath)/\(key)", idSuffix: ":\(key)",
                      visited: visited, templatePaths: &templatePaths)
            }
        default:
            return []
        }
    }

    // MARK: - Helpers

    private static func decodeChildList(_ model: ComponentModel) -> ChildList? {
        guard let raw = model.properties["children"],
              let data = try? JSONEncoder().encode(raw) else { return nil }
        return try? JSONDecoder().decode(ChildList.self, from: data)
    }

    /// Accumulates parent array indices into the suffix so nested-template ids
    /// stay unique (e.g. `:0:1`). Mirrors `SurfaceViewModel.templateSuffix`.
    private static func templateSuffix(dataContextPath: String, index: Int) -> String {
        let parentIndices = dataContextPath.split(separator: "/").filter { $0.allSatisfy(\.isNumber) }
        return ":\((parentIndices.map(String.init) + [String(index)]).joined(separator: ":"))"
    }
}

#endif
