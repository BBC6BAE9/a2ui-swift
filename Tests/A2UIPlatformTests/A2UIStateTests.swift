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

/// View-state persistence gate: Tabs selection (node.uiState) must survive a
/// structural rebuild, mirroring SwiftUI's uiState migration.
final class A2UIStateTests: XCTestCase {

    private func find<T: PlatformView>(_ type: T.Type, in view: PlatformView) -> T? {
        for sub in view.subviews {
            if let hit = sub as? T { return hit }
            if let hit = find(type, in: sub) { return hit }
        }
        return nil
    }

    func testTabsSelectionSurvivesRebuild() throws {
        let surface = SurfaceModel(id: "s-state")
        try surface.componentsModel.addComponent(ComponentModel(
            id: "tabs", type: "Tabs", properties: ["tabs": .array([
                .dictionary(["title": .string("A"), "child": .string("ta")]),
                .dictionary(["title": .string("B"), "child": .string("tb")]),
            ])]
        ))
        try surface.componentsModel.addComponent(ComponentModel(
            id: "ta", type: "Text", properties: ["text": .string("A")]))
        try surface.componentsModel.addComponent(ComponentModel(
            id: "tb", type: "Text", properties: ["text": .string("B")]))

        let host = A2UISurfaceHostView()
        host.render(surface: surface, rootComponentId: "tabs")
        try XCTUnwrap(find(A2UITabs.self, in: host)).select(1)

        // Force a structural rebuild (component created → host rebuilds the tree).
        try surface.componentsModel.addComponent(ComponentModel(
            id: "extra", type: "Text", properties: ["text": .string("x")]))

        let rebuilt = try XCTUnwrap(find(A2UITabs.self, in: host))
        XCTAssertEqual(rebuilt.currentIndex, 1,
                       "Tab selection should persist across rebuilds via migrated uiState")
    }
}

#endif
