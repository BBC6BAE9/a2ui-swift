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

/// Expression-binding reactivity gate: a function-call binding must update when
/// any data path it references changes (the fan-in the renderer adds explicitly).
final class A2UIExpressionTests: XCTestCase {

    private func texts(in view: PlatformView) -> [A2UIText] {
        var found: [A2UIText] = []
        for sub in view.subviews {
            if let t = sub as? A2UIText { found.append(t) }
            found.append(contentsOf: texts(in: sub))
        }
        return found
    }

    func testFunctionCallBindingIsReactive() throws {
        let surface = SurfaceModel(
            id: "s-expr",
            catalog: Catalog(id: "test", functions: BASIC_FUNCTIONS)
        )
        // Text bound to capitalize(/name)
        try surface.componentsModel.addComponent(ComponentModel(
            id: "t", type: "Text",
            properties: ["text": .dictionary([
                "call": .string("capitalize"),
                "args": .dictionary(["value": .dictionary(["path": .string("/name")])]),
            ])]
        ))
        _ = try surface.dataModel.set("/name", value: .string("hello"))

        let host = A2UISurfaceHostView()
        host.render(surface: surface, rootComponentId: "t")
        XCTAssertEqual(texts(in: host).first?.currentText, "Hello",
                       "Expression should resolve initially")

        // Change a path the expression references — no template, no manual render.
        _ = try surface.dataModel.set("/name", value: .string("world"))
        XCTAssertEqual(texts(in: host).first?.currentText, "World",
                       "Expression must re-resolve when a referenced path changes")
    }
}

#endif
