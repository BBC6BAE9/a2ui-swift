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

@Suite("SurfaceComponentsModel")
struct SurfaceComponentsModelTests {

    @Test("starts empty")
    func startsEmpty() {
        let model = SurfaceComponentsModel()
        #expect(model.get("any") == nil)
    }

    @Test("adds a new component")
    func addsComponent() throws {
        let model = SurfaceComponentsModel()
        let c1 = ComponentModel(id: "c1", type: "Button", properties: ["label": .string("Click")])
        try model.addComponent(c1)

        let retrieved = model.get("c1")
        #expect(retrieved != nil)
        #expect(retrieved?.id == "c1")
        #expect(retrieved?.type == "Button")
        #expect(retrieved?.properties["label"] == .string("Click"))
    }

    @Test("updates an existing component")
    func updatesComponent() throws {
        let model = SurfaceComponentsModel()
        let c1 = ComponentModel(id: "c1", type: "Button", properties: ["label": .string("Initial")])
        try model.addComponent(c1)

        var updateCount = 0
        c1.onUpdated.subscribe { _ in updateCount += 1 }

        c1.properties = ["label": .string("Updated")]

        #expect(c1.properties["label"] == .string("Updated"))
        #expect(updateCount == 1)
    }

    @Test("notifies on component creation")
    func notifiesOnCreated() throws {
        let model = SurfaceComponentsModel()
        var createdComponent: ComponentModel?
        model.onCreated.subscribe { createdComponent = $0 }

        try model.addComponent(ComponentModel(id: "c1", type: "Button", properties: [:]))

        #expect(createdComponent != nil)
        #expect(createdComponent?.id == "c1")
    }

    @Test("throws when adding duplicate component")
    func throwsDuplicateComponent() throws {
        let model = SurfaceComponentsModel()
        try model.addComponent(ComponentModel(id: "c1", type: "Button", properties: [:]))

        #expect(throws: SurfaceComponentsError.self) {
            try model.addComponent(ComponentModel(id: "c1", type: "Button", properties: [:]))
        }
    }

    @Test("returns entries iterator")
    func entriesInsertionOrder() throws {
        let model = SurfaceComponentsModel()
        let c1 = ComponentModel(id: "c1", type: "Button", properties: [:])
        let c2 = ComponentModel(id: "c2", type: "Text", properties: [:])
        try model.addComponent(c1)
        try model.addComponent(c2)

        let entries = model.entries
        #expect(entries.count == 2)
        #expect(entries[0].0 == "c1")
        #expect(entries[0].1 === c1)
        #expect(entries[1].0 == "c2")
        #expect(entries[1].1 === c2)
    }

    @Test("disposes components during model dispose")
    func disposesChildComponents() throws {
        let model = SurfaceComponentsModel()
        let c1 = ComponentModel(id: "c1", type: "Button", properties: [:])
        try model.addComponent(c1)

        // Track whether onUpdated fires after dispose (it should not)
        var firedAfterDispose = false
        c1.onUpdated.subscribe { _ in firedAfterDispose = true }

        model.dispose()

        c1.properties["x"] = .number(1)
        #expect(firedAfterDispose == false)
    }

    @Test("safely attempts to remove non-existent component")
    func safeRemoveNonExistent() {
        let model = SurfaceComponentsModel()
        // Should not throw
        model.removeComponent("does-not-exist")
    }
}
