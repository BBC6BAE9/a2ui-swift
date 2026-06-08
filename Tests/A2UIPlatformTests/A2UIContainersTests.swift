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

/// Container / complex-component gate (Card child resolution, Tabs, ChoicePicker).
final class A2UIContainersTests: XCTestCase {

    private func find<T: PlatformView>(_ type: T.Type, in view: PlatformView) -> T? {
        for sub in view.subviews {
            if let hit = sub as? T { return hit }
            if let hit = find(type, in: sub) { return hit }
        }
        return nil
    }

    private func texts(in view: PlatformView) -> [A2UIText] {
        var found: [A2UIText] = []
        for sub in view.subviews {
            if let t = sub as? A2UIText { found.append(t) }
            found.append(contentsOf: texts(in: sub))
        }
        return found
    }

    /// Validates the type-aware tree builder: Card uses `child`, not `children`.
    func testCardResolvesSingleChild() throws {
        let surface = SurfaceModel(id: "s-card")
        try surface.componentsModel.addComponent(ComponentModel(
            id: "card", type: "Card", properties: ["child": .string("inner")]
        ))
        try surface.componentsModel.addComponent(ComponentModel(
            id: "inner", type: "Text", properties: ["text": .string("Hi")]
        ))
        let host = A2UISurfaceHostView()
        host.render(surface: surface, rootComponentId: "card")
        XCTAssertEqual(texts(in: host).map(\.currentText), ["Hi"])
    }

    func testTabsSwitchPanels() throws {
        let surface = SurfaceModel(id: "s-tabs")
        try surface.componentsModel.addComponent(ComponentModel(
            id: "tabs", type: "Tabs", properties: ["tabs": .array([
                .dictionary(["title": .string("A"), "child": .string("ta")]),
                .dictionary(["title": .string("B"), "child": .string("tb")]),
            ])]
        ))
        try surface.componentsModel.addComponent(ComponentModel(
            id: "ta", type: "Text", properties: ["text": .string("PanelA")]))
        try surface.componentsModel.addComponent(ComponentModel(
            id: "tb", type: "Text", properties: ["text": .string("PanelB")]))

        let host = A2UISurfaceHostView()
        host.render(surface: surface, rootComponentId: "tabs")
        let tabs = try XCTUnwrap(find(A2UITabs.self, in: host))

        XCTAssertEqual(tabs.currentIndex, 0)
        XCTAssertEqual(texts(in: host).map(\.currentText), ["PanelA"])
        tabs.select(1)
        XCTAssertEqual(tabs.currentIndex, 1)
        XCTAssertEqual(texts(in: host).map(\.currentText), ["PanelB"])
    }

    func testChoicePickerWritesSelection() throws {
        let surface = SurfaceModel(id: "s-cp")
        try surface.componentsModel.addComponent(ComponentModel(
            id: "cp", type: "ChoicePicker", properties: [
                "variant": .string("multipleSelection"),
                "value": .dictionary(["path": .string("/sel")]),
                "options": .array([
                    .dictionary(["label": .string("X"), "value": .string("x")]),
                    .dictionary(["label": .string("Y"), "value": .string("y")]),
                ]),
            ]
        ))
        _ = try surface.dataModel.set("/sel", value: .array([]))

        let host = A2UISurfaceHostView()
        host.render(surface: surface, rootComponentId: "cp")
        let picker = try XCTUnwrap(find(A2UIChoicePicker.self, in: host))

        picker.toggle("x")
        XCTAssertEqual(picker.selectedValues, ["x"])
        XCTAssertEqual(surface.dataModel.get("/sel")?.arrayValue?.compactMap(\.stringValue), ["x"])
    }
}

#endif
