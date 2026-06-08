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

/// Investigates the reconcile runtime's lifecycle: when the host rebuilds, do the
/// old component views deallocate (no leak / no dangling subscriptions), and are
/// they replaced by new instances (the mechanism behind focus loss on rebuild)?
final class A2UIRebuildLifecycleTests: XCTestCase {

    private func makeSurface(items: [String]) throws -> SurfaceModel {
        let surface = SurfaceModel(id: "lifecycle")
        try surface.componentsModel.addComponent(ComponentModel(
            id: "list", type: "List",
            properties: ["children": .dictionary([
                "componentId": .string("itemTpl"), "path": .string("/items")])]
        ))
        try surface.componentsModel.addComponent(ComponentModel(
            id: "itemTpl", type: "Text",
            properties: ["text": .dictionary(["path": .string("label")])]
        ))
        _ = try surface.dataModel.set("/items", value: .array(
            items.map { .dictionary(["label": .string($0)]) }))
        return surface
    }

    private func texts(in view: PlatformView) -> [A2UIText] {
        var found: [A2UIText] = []
        for sub in view.subviews {
            if let t = sub as? A2UIText { found.append(t) }
            found.append(contentsOf: texts(in: sub))
        }
        return found
    }

    /// After a template-driven rebuild, the OLD component views must deallocate
    /// (proves no leak and that deinit-based subscription cleanup actually runs).
    func testOldViewsDeallocateAfterRebuild() throws {
        let surface = try makeSurface(items: ["A", "B"])
        let host = A2UISurfaceHostView()

        weak var weakOldText: A2UIText?
        try autoreleasepool {
            host.render(surface: surface, rootComponentId: "list")
            let old = self.texts(in: host)
            XCTAssertEqual(old.count, 2)
            weakOldText = old.first
            XCTAssertNotNil(weakOldText)

            // Mutate the bound array → host auto-rebuilds, tearing down old views.
            _ = try surface.dataModel.set("/items", value: .array([
                .dictionary(["label": .string("A")]),
                .dictionary(["label": .string("B")]),
                .dictionary(["label": .string("C")]),
            ]))
        }

        // The old text view must be gone (no retain cycle / no leaked subscription).
        XCTAssertNil(weakOldText, "Old component views must deallocate after a rebuild")
    }

    /// Confirms rebuild replaces view instances (so any first-responder / edit
    /// state on the old views is lost — the known limitation of full rebuild).
    func testRebuildReplacesViewInstances() throws {
        let surface = try makeSurface(items: ["A", "B"])
        let host = A2UISurfaceHostView()
        host.render(surface: surface, rootComponentId: "list")
        let before = ObjectIdentifier(try XCTUnwrap(texts(in: host).first))

        _ = try surface.dataModel.set("/items", value: .array([
            .dictionary(["label": .string("A")]),
            .dictionary(["label": .string("B")]),
            .dictionary(["label": .string("C")]),
        ]))

        let after = ObjectIdentifier(try XCTUnwrap(texts(in: host).first))
        XCTAssertNotEqual(before, after,
            "Rebuild creates fresh view instances (confirms focus/edit state is lost on rebuild)")
    }
}

#endif
