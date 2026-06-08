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

/// Modal opens when its trigger fires an action (no special trigger wiring).
final class A2UIModalTests: XCTestCase {

    private func find<T: PlatformView>(_ type: T.Type, in view: PlatformView) -> T? {
        for sub in view.subviews {
            if let hit = sub as? T { return hit }
            if let hit = find(type, in: sub) { return hit }
        }
        return nil
    }

    func testTriggerActionOpensModal() throws {
        let surface = SurfaceModel(id: "modal-test")
        try surface.componentsModel.addComponent(ComponentModel(
            id: "modal", type: "Modal",
            properties: ["trigger": .string("openBtn"), "content": .string("body")]
        ))
        try surface.componentsModel.addComponent(ComponentModel(
            id: "openBtn", type: "Button",
            properties: ["child": .string("openLbl"),
                         "action": .dictionary(["event": .dictionary(["name": .string("open")])])]
        ))
        try surface.componentsModel.addComponent(ComponentModel(
            id: "openLbl", type: "Text", properties: ["text": .string("Open")]))
        try surface.componentsModel.addComponent(ComponentModel(
            id: "body", type: "Text", properties: ["text": .string("Modal body")]))

        let host = A2UISurfaceHostView()
        host.render(surface: surface, rootComponentId: "modal")
        let modal = try XCTUnwrap(find(A2UIModal.self, in: host))
        let button = try XCTUnwrap(find(A2UIButton.self, in: modal))

        XCTAssertEqual(modal.subviews.count, 1, "Only the trigger is shown initially")

        // Simulate the trigger button being tapped → dispatches its action.
        button.handleTap()

        // With no host window in the test, the overlay attaches to the modal,
        // so its subviews grow from 1 (trigger) to 2 (trigger + dim overlay).
        XCTAssertEqual(modal.subviews.count, 2,
                       "Tapping the trigger should present the modal overlay")
    }
}

#endif
