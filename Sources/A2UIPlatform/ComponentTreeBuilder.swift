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
// Mirrors the relevant parts of SwiftUI's `SurfaceViewModel.buildNodeRecursive`
// / `resolveTemplateChildren`, which live in the SwiftUI target (NOT in Core),
// so the imperative renderers need their own (shared) copy.
//
// Handles static (explicit) children AND template (data-array / -dictionary)
// expansion. Template resolution is non-reactive: when the bound data changes,
// the tree is rebuilt — exactly as SwiftUI does it.

enum ComponentTreeBuilder {

    /// Builds the node subtree rooted at `componentId`.
    /// - `dataContextPath`: JSON-Pointer scope for data bindings in this subtree.
    /// - `idSuffix`: makes node ids unique across template expansions
    ///   (node `id` = `componentId + idSuffix`; `baseComponentId` stays the template id).
    static func build(
        surface: SurfaceModel,
        componentId: String,
        dataContextPath: String = "/",
        idSuffix: String = "",
        visited: Set<String> = []
    ) -> ComponentNode? {
        guard !visited.contains(componentId),
              let model = surface.componentsModel.get(componentId) else { return nil }
        var visited = visited
        visited.insert(componentId)

        let type = ComponentType.from(model.type)
        let instance = RawComponent(
            id: model.id,
            component: model.type,
            properties: model.properties
        )
        let children = resolveChildren(
            surface: surface, model: model,
            dataContextPath: dataContextPath, idSuffix: idSuffix, visited: visited
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

    private static func resolveChildren(
        surface: SurfaceModel, model: ComponentModel,
        dataContextPath: String, idSuffix: String, visited: Set<String>
    ) -> [ComponentNode] {
        guard let childList = decodeChildList(model) else { return [] }
        switch childList {
        case .staticList(let ids):
            // Static children inherit the parent's suffix so they stay unique
            // inside a templated item.
            return ids.compactMap {
                build(surface: surface, componentId: $0,
                      dataContextPath: dataContextPath, idSuffix: idSuffix, visited: visited)
            }
        case .template(let componentId, let path):
            return resolveTemplate(
                surface: surface, componentId: componentId, path: path,
                dataContextPath: dataContextPath, visited: visited
            )
        }
    }

    /// Expands a template over the data at `path`: one child per array element
    /// (scoped to `<fullPath>/<index>`) or per sorted dictionary key.
    private static func resolveTemplate(
        surface: SurfaceModel, componentId: String, path: String,
        dataContextPath: String, visited: Set<String>
    ) -> [ComponentNode] {
        let dc = DataContext(surface: surface, path: dataContextPath)
        let fullPath = dc.resolvePath(path)
        guard let data = surface.dataModel.get(fullPath) else { return [] }

        switch data {
        case .array(let items):
            return items.indices.compactMap { index in
                build(surface: surface, componentId: componentId,
                      dataContextPath: "\(fullPath)/\(index)",
                      idSuffix: templateSuffix(dataContextPath: dataContextPath, index: index),
                      visited: visited)
            }
        case .dictionary(let dict):
            return dict.keys.sorted().compactMap { key in
                build(surface: surface, componentId: componentId,
                      dataContextPath: "\(fullPath)/\(key)", idSuffix: ":\(key)", visited: visited)
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
