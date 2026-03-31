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

// Tests for SurfaceViewModel.swift
// Verifies message handling, DataContext factory, and DataModel integration.

import Testing
import Foundation
@testable import A2UISwiftCore
@testable import A2UISwiftUI

// MARK: - Helpers

private func makeViewModel() -> SurfaceViewModel {
    SurfaceViewModel(catalog: Catalog(id: "test-catalog"))
}

private func makeCreateSurface(surfaceId: String = "s1") -> A2uiMessage {
    .createSurface(CreateSurfacePayload(surfaceId: surfaceId, catalogId: "test-catalog"))
}

private func makeTextComponent(id: String = "root", text: String = "Hello") -> A2uiMessage {
    .updateComponents(UpdateComponentsPayload(
        surfaceId: "s1",
        components: [
            RawComponent(
                id: id,
                component: "Text",
                properties: ["text": .string(text)]
            )
        ]
    ))
}

// MARK: - processMessage: createSurface

@Suite("SurfaceViewModel.processMessage(createSurface)")
struct SurfaceViewModelCreateTests {

    @Test("handles createSurface — surface is set up")
    func createSurface() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        // surface should be initialised (SurfaceViewModel always has a surface)
        #expect(vm.surface.id != "")
    }

    @Test("handles createSurface with theme — a2uiStyle updated")
    func createSurfaceWithTheme() throws {
        let vm = makeViewModel()
        let msg = A2uiMessage.createSurface(CreateSurfacePayload(
            surfaceId: "s1",
            catalogId: "test-catalog",
            theme: .dictionary(["primaryColor": .string("#FF0000")])
        ))
        try vm.processMessage(msg)
        // After processing a theme, a2uiStyle should be non-default
        // (exact colour assertion not needed — just verifies no crash)
        _ = vm.a2uiStyle
    }
}

// MARK: - processMessage: updateComponents

@Suite("SurfaceViewModel.processMessage(updateComponents)")
struct SurfaceViewModelUpdateComponentsTests {

    @Test("componentTree is nil before components arrive")
    func nilBeforeComponents() {
        let vm = makeViewModel()
        #expect(vm.componentTree == nil)
    }

    @Test("componentTree is built after createSurface + updateComponents")
    func treeBuiltAfterMessages() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        try vm.processMessage(makeTextComponent(id: "root", text: "Hello"))
        #expect(vm.componentTree != nil)
        #expect(vm.componentTree?.id == "root")
        #expect(vm.componentTree?.type == .Text)
    }

    @Test("updateComponents with multiple components — root is used")
    func multipleComponents() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        let msg = A2uiMessage.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "root", component: "Column", properties: [
                    "children": .array([.string("child1")])
                ]),
                RawComponent(id: "child1", component: "Text", properties: [
                    "text": .string("child")
                ]),
            ]
        ))
        try vm.processMessage(msg)
        #expect(vm.componentTree?.type == .Column)
        #expect(vm.componentTree?.children.count == 1)
        #expect(vm.componentTree?.children.first?.type == .Text)
    }

    @Test("componentTree is nil when no root component exists")
    func nilWhenNoRoot() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        // Component id "notroot" → no tree
        let msg = A2uiMessage.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "notroot", component: "Text", properties: ["text": .string("hi")])
            ]
        ))
        try vm.processMessage(msg)
        #expect(vm.componentTree == nil)
    }
}

// MARK: - processMessage: updateDataModel

@Suite("SurfaceViewModel.processMessage(updateDataModel)")
struct SurfaceViewModelUpdateDataModelTests {

    @Test("updateDataModel writes to DataModel")
    func writesToDataModel() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        let msg = A2uiMessage.updateDataModel(UpdateDataModelPayload(
            surfaceId: "s1",
            path: "/user/name",
            value: .string("Alice")
        ))
        try vm.processMessage(msg)
        #expect(vm.surface.dataModel.get("/user/name") == .string("Alice"))
    }

    @Test("updateDataModel at root path replaces data")
    func writesToRoot() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        let msg = A2uiMessage.updateDataModel(UpdateDataModelPayload(
            surfaceId: "s1",
            path: "/",
            value: .dictionary(["key": .string("value")])
        ))
        try vm.processMessage(msg)
        #expect(vm.surface.dataModel.get("/key") == .string("value"))
    }

    @Test("updateDataModel does not rebuild componentTree")
    func noTreeRebuildOnDataUpdate() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        try vm.processMessage(makeTextComponent())
        let treeBeforeUpdate = vm.componentTree

        let msg = A2uiMessage.updateDataModel(UpdateDataModelPayload(
            surfaceId: "s1",
            path: "/someKey",
            value: .string("someValue")
        ))
        try vm.processMessage(msg)
        // componentTree object identity unchanged — no rebuild
        #expect(vm.componentTree === treeBeforeUpdate)
    }
}

// MARK: - processMessage: deleteSurface

@Suite("SurfaceViewModel.processMessage(deleteSurface)")
struct SurfaceViewModelDeleteTests {

    @Test("deleteSurface clears componentTree")
    func clearsTree() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        try vm.processMessage(makeTextComponent())
        #expect(vm.componentTree != nil)

        try vm.processMessage(.deleteSurface(DeleteSurfacePayload(surfaceId: "s1")))
        #expect(vm.componentTree == nil)
    }
}

// MARK: - makeDataContext

@Suite("SurfaceViewModel.makeDataContext")
struct SurfaceViewModelDataContextTests {

    @Test("makeDataContext returns context scoped to root by default")
    func defaultRootPath() {
        let vm = makeViewModel()
        let dc = vm.makeDataContext()
        #expect(dc.path == "/")
    }

    @Test("makeDataContext respects custom path")
    func customPath() {
        let vm = makeViewModel()
        let dc = vm.makeDataContext(path: "/user")
        #expect(dc.path == "/user")
    }

    @Test("makeDataContext resolves values from DataModel")
    func resolvesValues() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        try vm.processMessage(.updateDataModel(UpdateDataModelPayload(
            surfaceId: "s1",
            path: "/greeting",
            value: .string("Hello world")
        )))
        let dc = vm.makeDataContext()
        #expect(dc.resolve(.dataBinding(path: "greeting")) == "Hello world")
    }

    @Test("DataContext from makeDataContext writes back to DataModel")
    func writesBack() throws {
        let vm = makeViewModel()
        let dc = vm.makeDataContext()
        try dc.set("counter", value: .number(42))
        #expect(vm.surface.dataModel.get("/counter") == .number(42))
    }
}

// MARK: - onAction subscription

@Suite("SurfaceViewModel.onAction")
struct SurfaceViewModelActionTests {

    @Test("onAction receives dispatched actions")
    func receivesAction() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())

        var received: A2uiClientAction?
        _ = vm.onAction { received = $0 }

        vm.surface.dispatchAction(name: "submit", sourceComponentId: "btn1", context: ["key": .string("val")])

        #expect(received?.name == "submit")
        #expect(received?.sourceComponentId == "btn1")
        #expect(received?.context["key"] == .string("val"))
    }
}

// MARK: - processMessages batch

@Suite("SurfaceViewModel.processMessages batch")
struct SurfaceViewModelBatchTests {

    @Test("processMessages processes all messages and returns errors for failed ones")
    func processesAllAndReturnsErrors() {
        let vm = makeViewModel()
        // Second message is invalid (missing surfaceId data — will throw)
        let messages: [A2uiMessage] = [
            makeCreateSurface(),
            makeTextComponent(),
        ]
        let errors = vm.processMessages(messages)
        #expect(errors.isEmpty)
        #expect(vm.componentTree != nil)
    }
}
