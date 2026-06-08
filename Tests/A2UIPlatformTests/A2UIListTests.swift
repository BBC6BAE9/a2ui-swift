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
import XCTest
import A2UISwiftCore
@testable import A2UIPlatform

/// List + template (data-array) expansion gate for the shared renderer.
final class A2UIListTests: XCTestCase {

    /// List → template(itemTpl over /items); itemTpl = Text bound to "label".
    private func makeSurface(items: [String]) throws -> SurfaceModel {
        let surface = SurfaceModel(id: "surface-list")
        try surface.componentsModel.addComponent(ComponentModel(
            id: "list", type: "List",
            properties: ["children": .dictionary([
                "componentId": .string("itemTpl"),
                "path": .string("/items"),
            ])]
        ))
        try surface.componentsModel.addComponent(ComponentModel(
            id: "itemTpl", type: "Text",
            properties: ["text": .dictionary(["path": .string("label")])]
        ))
        try setItems(surface, items)
        return surface
    }

    private func setItems(_ surface: SurfaceModel, _ items: [String]) throws {
        _ = try surface.dataModel.set("/items", value: .array(
            items.map { .dictionary(["label": .string($0)]) }
        ))
    }

    private func texts(in view: PlatformView) -> [A2UIText] {
        var found: [A2UIText] = []
        for sub in view.subviews {
            if let t = sub as? A2UIText { found.append(t) }
            found.append(contentsOf: texts(in: sub))
        }
        return found
    }

    private func list(in view: PlatformView) -> A2UIList? {
        for sub in view.subviews {
            if let l = sub as? A2UIList { return l }
            if let l = list(in: sub) { return l }
        }
        return nil
    }

    func testTemplateExpandsOneChildPerArrayElement() throws {
        let surface = try makeSurface(items: ["Apple", "Banana", "Cherry"])
        let host = A2UISurfaceHostView()
        host.render(surface: surface, rootComponentId: "list")

        let listView = try XCTUnwrap(list(in: host), "List should render")
        XCTAssertEqual(listView.arrangedChildren.count, 3, "One row per array element")
    }

    func testTemplateItemsResolveScopedBindings() throws {
        let surface = try makeSurface(items: ["Apple", "Banana"])
        let host = A2UISurfaceHostView()
        host.render(surface: surface, rootComponentId: "list")

        let rendered = texts(in: host).map(\.currentText)
        XCTAssertEqual(rendered, ["Apple", "Banana"],
                       "Each item's Text binds to its own scoped /items/<i>/label")
    }

    func testRebuildReflectsArrayChange() throws {
        let surface = try makeSurface(items: ["Apple", "Banana"])
        let host = A2UISurfaceHostView()
        host.render(surface: surface, rootComponentId: "list")
        XCTAssertEqual(texts(in: host).count, 2)

        // Grow the array, then re-render (auto-reconcile runtime is deferred).
        try setItems(surface, ["Apple", "Banana", "Cherry", "Date"])
        host.render(surface: surface, rootComponentId: "list")

        XCTAssertEqual(texts(in: host).map(\.currentText), ["Apple", "Banana", "Cherry", "Date"])
    }
}

#endif
