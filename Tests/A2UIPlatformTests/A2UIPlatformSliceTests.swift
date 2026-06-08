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

/// Vertical-slice gate for the shared Apple-substrate renderer.
/// Validates: tree build → factory dispatch → container layout → reactive text
/// binding, on whichever Apple framework the test happens to compile for.
final class A2UIPlatformSliceTests: XCTestCase {

    private func makeSurface() throws -> SurfaceModel {
        let surface = SurfaceModel(id: "surface-1")
        // Column { Text("Hello, "), Text(bind /name) }
        try surface.componentsModel.addComponent(ComponentModel(
            id: "root", type: "Column",
            properties: ["children": .array([.string("greeting"), .string("name")])]
        ))
        try surface.componentsModel.addComponent(ComponentModel(
            id: "greeting", type: "Text",
            properties: ["text": .string("Hello, ")]
        ))
        try surface.componentsModel.addComponent(ComponentModel(
            id: "name", type: "Text",
            properties: ["text": .dictionary(["path": .string("/name")])]
        ))
        _ = try surface.dataModel.set("/name", value: .string("World"))
        return surface
    }

    /// Collects every rendered Text leaf under a view, depth-first.
    private func texts(in view: PlatformView) -> [A2UIText] {
        var found: [A2UIText] = []
        for sub in view.subviews {
            if let t = sub as? A2UIText { found.append(t) }
            found.append(contentsOf: texts(in: sub))
        }
        return found
    }

    func testRendersTreeWithStaticChildren() throws {
        let surface = try makeSurface()
        let host = A2UISurfaceHostView()
        let root = host.render(surface: surface, rootComponentId: "root")

        XCTAssertNotNil(root, "Root Column should resolve and render")
        let leaves = texts(in: host)
        XCTAssertEqual(leaves.count, 2, "Column should expand both static Text children")
    }

    func testLiteralAndBoundTextResolve() throws {
        let surface = try makeSurface()
        let host = A2UISurfaceHostView()
        host.render(surface: surface, rootComponentId: "root")

        let rendered = Set(texts(in: host).map(\.currentText))
        XCTAssertTrue(rendered.contains("Hello, "), "Literal text should render")
        XCTAssertTrue(rendered.contains("World"), "Bound text should resolve initial value")
    }

    func testBoundTextIsReactive() throws {
        let surface = try makeSurface()
        let host = A2UISurfaceHostView()
        host.render(surface: surface, rootComponentId: "root")

        // Mutate the bound data path — the subscription should push synchronously.
        _ = try surface.dataModel.set("/name", value: .string("Claude"))

        let rendered = Set(texts(in: host).map(\.currentText))
        XCTAssertTrue(rendered.contains("Claude"),
                      "Bound Text must update reactively when its data path changes")
        XCTAssertFalse(rendered.contains("World"), "Stale value should be replaced")
    }
}

#endif
