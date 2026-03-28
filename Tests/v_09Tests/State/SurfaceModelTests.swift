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
import Foundation
@testable import v_09

@Suite("SurfaceModel")
struct SurfaceModelTests {

    @Test("initializes with empty data model")
    func emptyDataModel() {
        let surface = SurfaceModel(id: "s1")
        #expect(surface.dataModel.get("/") == .dictionary([:]))
    }

    @Test("exposes components model")
    func componentsModel() throws {
        let surface = SurfaceModel(id: "s1")
        try surface.componentsModel.addComponent(
            ComponentModel(id: "c1", type: "Button", properties: [:])
        )
        #expect(surface.componentsModel.get("c1")?.type == "Button")
    }

    @Test("dispatches actions with metadata")
    func dispatchAction() {
        let surface = SurfaceModel(id: "surface-1")
        var received: A2uiClientAction?
        surface.onAction.subscribe { received = $0 }

        surface.dispatchAction(
            name: "click",
            sourceComponentId: "comp-1",
            context: ["foo": .string("bar")]
        )

        #expect(received?.name == "click")
        #expect(received?.surfaceId == "surface-1")
        #expect(received?.sourceComponentId == "comp-1")
        #expect(received?.context["foo"] == .string("bar"))
        #expect(received?.timestamp != nil)
    }

    @Test("dispatches actions with default context")
    func dispatchActionDefaultContext() {
        let surface = SurfaceModel(id: "s1")
        var received: A2uiClientAction?
        surface.onAction.subscribe { received = $0 }

        surface.dispatchAction(name: "click", sourceComponentId: "comp-1")

        #expect(received?.context.isEmpty == true)
    }

    @Test("dispatches errors")
    func dispatchError() {
        let surface = SurfaceModel(id: "surface-1")
        var received: A2uiClientError?
        surface.onError.subscribe { received = $0 }

        surface.dispatchError(code: "TEST_ERROR", message: "Something failed")

        #expect(received?.code == "TEST_ERROR")
        #expect(received?.message == "Something failed")
        #expect(received?.surfaceId == "surface-1")
    }

    @Test("creates a component context")
    func createComponentContext() throws {
        let surface = SurfaceModel(id: "s1")
        try surface.componentsModel.addComponent(
            ComponentModel(id: "root", type: "Box", properties: [:])
        )
        let ctx = try ComponentContext(surface: surface, componentId: "root", dataModelBasePath: "/mydata")
        #expect(ctx.dataContext.path == "/mydata")
    }

    @Test("disposes resources")
    func disposeStopsActions() {
        let surface = SurfaceModel(id: "s1")
        var actionReceived = false
        surface.onAction.subscribe { _ in actionReceived = true }

        surface.dispose()

        surface.dispatchAction(name: "click", sourceComponentId: "c1")
        #expect(actionReceived == false)
    }
}
