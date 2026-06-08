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
// Minimal, slice-scoped resolver: `SurfaceModel` component definitions →
// `ComponentNode` tree. Handles ONLY static (explicit) children — enough for
// Text / Row / Column. Template (data-array) expansion is deliberately out of
// scope here; it belongs to the full tree runtime (mirroring SwiftUI's
// `SurfaceViewModel.resolveTemplateChildren`) and arrives with the List work.
//
// NOTE: this confirms an architecture finding — `buildNodeRecursive` lives in
// the SwiftUI target, not in Core, so the imperative renderers need their own
// (shared) runtime. This is the seed of it.

enum ComponentTreeBuilder {

    /// Builds the node subtree rooted at `componentId`, resolving static children
    /// recursively. Returns `nil` if the id is unknown or a cycle is detected.
    static func build(
        surface: SurfaceModel,
        componentId: String,
        dataContextPath: String = "/",
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

        let children = staticChildIds(of: model).compactMap {
            build(surface: surface, componentId: $0, dataContextPath: dataContextPath, visited: visited)
        }

        return ComponentNode(
            id: componentId,
            baseComponentId: componentId,
            type: type,
            dataContextPath: dataContextPath,
            weight: model.properties["weight"]?.numberValue,
            instance: instance,
            children: children
        )
    }

    /// Extracts explicit child ids from a `children` property. Template form
    /// (`{componentId, path}`) returns empty — handled by the full runtime later.
    private static func staticChildIds(of model: ComponentModel) -> [String] {
        guard let raw = model.properties["children"] else { return [] }
        guard let data = try? JSONEncoder().encode(raw),
              let childList = try? JSONDecoder().decode(ChildList.self, from: data) else { return [] }
        switch childList {
        case .staticList(let ids): return ids
        case .template: return []
        }
    }
}

#endif
