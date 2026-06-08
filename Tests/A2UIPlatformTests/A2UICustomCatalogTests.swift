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

/// Custom-component extension-point gate.
final class A2UICustomCatalogTests: XCTestCase {

    final class TestWidget: PlatformView, A2UIPlatformComponent {
        private(set) var configured = false
        func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
            configured = true
        }
    }

    final class TestCatalog: A2UICustomComponentCatalog {
        func makeView(typeName: String, node: ComponentNode, surface: SurfaceModel)
            -> (PlatformView & A2UIPlatformComponent)? {
            typeName == "MyWidget" ? TestWidget() : nil
        }
    }

    private func find<T: PlatformView>(_ type: T.Type, in view: PlatformView) -> T? {
        for sub in view.subviews {
            if let hit = sub as? T { return hit }
            if let hit = find(type, in: sub) { return hit }
        }
        return nil
    }

    func testCustomCatalogRendersCustomType() throws {
        let surface = SurfaceModel(id: "s-custom")
        try surface.componentsModel.addComponent(ComponentModel(
            id: "w", type: "MyWidget", properties: [:]
        ))

        let host = A2UISurfaceHostView()
        let catalog = TestCatalog()
        host.customCatalog = catalog
        host.render(surface: surface, rootComponentId: "w")

        let widget = try XCTUnwrap(find(TestWidget.self, in: host),
                                   "Custom catalog should render the custom type")
        XCTAssertTrue(widget.configured)
    }
}

#endif
