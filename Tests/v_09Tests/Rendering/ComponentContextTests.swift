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

import Testing
@testable import v_09

@Suite("ComponentContext")
struct ComponentContextTests {

    @Test("initializes correctly")
    func initialization() throws {
        let surface = makeTestSurface()
        let comp = ComponentModel(id: "comp1", type: "TestComponent", properties: [:])
        try surface.componentsModel.addComponent(comp)
        let ctx = try ComponentContext(surface: surface, componentId: "comp1")

        #expect(ctx.componentModel === comp)
        #expect(ctx.dataContext.path == "/")
        #expect(ctx.surfaceComponents === surface.componentsModel)
    }

    @Test("dispatches actions")
    func dispatchAction() throws {
        var received: A2uiClientAction?
        let surface = makeTestSurface(onAction: { received = $0 })
        let comp = ComponentModel(id: "comp1", type: "TestComponent", properties: [:])
        try surface.componentsModel.addComponent(comp)
        let ctx = try ComponentContext(surface: surface, componentId: "comp1")

        ctx.dispatchAction(name: "test", context: ["a": .number(1)])

        #expect(received?.name == "test")
        #expect(received?.sourceComponentId == "comp1")
        #expect(received?.context["a"] == .number(1))
    }

    @Test("throws error if component not found")
    func componentNotFound() throws {
        let surface = makeTestSurface()

        #expect(throws: ComponentContextError.self) {
            try ComponentContext(surface: surface, componentId: "nonExistentId")
        }
    }

    @Test("creates data context with correct base path")
    func basePath() throws {
        let surface = makeTestSurface()
        let comp = ComponentModel(id: "comp1", type: "TestComponent", properties: [:])
        try surface.componentsModel.addComponent(comp)
        let ctx = try ComponentContext(
            surface: surface,
            componentId: "comp1",
            dataModelBasePath: "/foo/bar"
        )
        #expect(ctx.dataContext.path == "/foo/bar")
    }
}
