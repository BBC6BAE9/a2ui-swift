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

    private func find<T: PlatformView>(_ type: T.Type, in view: PlatformView) -> T? {
        for sub in view.subviews {
            if let hit = sub as? T { return hit }
            if let hit = find(type, in: sub) { return hit }
        }
        return nil
    }

    private func button(in view: PlatformView) -> A2UIButton? { find(A2UIButton.self, in: view) }

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

    func testTextFieldWritesBackToBoundPath() throws {
        let surface = SurfaceModel(id: "surface-tf")
        try surface.componentsModel.addComponent(ComponentModel(
            id: "tf", type: "TextField",
            properties: ["value": .dictionary(["path": .string("/name")])]
        ))
        _ = try surface.dataModel.set("/name", value: .string("initial"))

        let host = A2UISurfaceHostView()
        host.render(surface: surface, rootComponentId: "tf")
        let field = try XCTUnwrap(find(A2UITextField.self, in: host))

        field.simulateEditForTesting("edited")

        XCTAssertEqual(surface.dataModel.get("/name")?.stringValue, "edited",
                       "Editing should write back to the bound data path")
    }
}

#endif
