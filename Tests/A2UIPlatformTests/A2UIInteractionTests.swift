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

/// Interaction / action-dispatch gate.
final class A2UIInteractionTests: XCTestCase {

    private func button(in view: PlatformView) -> A2UIButton? {
        for sub in view.subviews {
            if let b = sub as? A2UIButton { return b }
            if let b = button(in: sub) { return b }
        }
        return nil
    }

    func testButtonDispatchesEventAction() throws {
        let surface = SurfaceModel(id: "surface-btn")
        try surface.componentsModel.addComponent(ComponentModel(
            id: "btn", type: "Button",
            properties: [
                "child": .string("label"),
                "action": .dictionary([
                    "event": .dictionary(["name": .string("submit")]),
                ]),
            ]
        ))
        try surface.componentsModel.addComponent(ComponentModel(
            id: "label", type: "Text", properties: ["text": .string("Go")]
        ))

        var dispatched: [String] = []
        let token = surface.onAction.subscribe { dispatched.append($0.name) }
        defer { token.unsubscribe() }

        let host = A2UISurfaceHostView()
        host.render(surface: surface, rootComponentId: "btn")

        let btn = try XCTUnwrap(button(in: host), "Button should render")
        btn.handleTap()

        XCTAssertEqual(dispatched, ["submit"], "Tap should dispatch the event action by name")
    }
}

#endif
