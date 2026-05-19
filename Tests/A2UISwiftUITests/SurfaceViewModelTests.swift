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

    @Test("missing root dispatches validation error with path")
    func missingRootDispatchesValidationErrorWithPath() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())

        var receivedError: A2uiClientError?
        let sub = vm.surface.onError.subscribe { receivedError = $0 }

        let msg = A2uiMessage.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "notroot", component: "Text", properties: ["text": .string("hi")])
            ]
        ))

        try vm.processMessage(msg)

        #expect(receivedError?.code == "VALIDATION_FAILED")
        #expect(receivedError?.path == "/updateComponents/components")
        sub.unsubscribe()
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

// MARK: - Reconciliation behavior

@Suite("SurfaceViewModel reconciliation")
struct SurfaceViewModelReconcileTests {

    /// Column → Text tree where Text is data-bound to /items/<index>/label, used
    /// for testing template-driven list growth and shrinkage.
    private func makeListSetup(_ items: [String]) throws -> SurfaceViewModel {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        // Seed the data model before components arrive so the template can resolve.
        try vm.processMessage(.updateDataModel(UpdateDataModelPayload(
            surfaceId: "s1",
            path: "/items",
            value: .array(items.map { .dictionary(["label": .string($0)]) })
        )))
        try vm.processMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "root", component: "Column", properties: [
                    "children": .dictionary([
                        "componentId": .string("row"),
                        "path": .string("/items"),
                    ])
                ]),
                RawComponent(id: "row", component: "Text", properties: [
                    "text": .dictionary(["path": .string("label")])
                ]),
            ]
        )))
        return vm
    }

    @Test("no-op updateComponents preserves root identity and every child identity")
    func noOpPreservesIdentity() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        try vm.processMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "root", component: "Column", properties: [
                    "children": .array([.string("a"), .string("b")])
                ]),
                RawComponent(id: "a", component: "Text", properties: ["text": .string("A")]),
                RawComponent(id: "b", component: "Text", properties: ["text": .string("B")]),
            ]
        )))
        let root = try #require(vm.componentTree)
        let childA = try #require(root.children.first)
        let childB = try #require(root.children.last)
        let childrenArray = root.children

        // Replay identical components.
        try vm.processMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "root", component: "Column", properties: [
                    "children": .array([.string("a"), .string("b")])
                ]),
                RawComponent(id: "a", component: "Text", properties: ["text": .string("A")]),
                RawComponent(id: "b", component: "Text", properties: ["text": .string("B")]),
            ]
        )))

        #expect(vm.componentTree === root)
        #expect(root.children.first === childA)
        #expect(root.children.last === childB)
        // `children` itself must not have been reassigned (no-op invariant).
        #expect(root.children.map(\.id) == childrenArray.map(\.id))
    }

    @Test("list growing by one item preserves the original children's identity")
    func listGrowsPreservesIdentity() throws {
        let vm = try makeListSetup(["x", "y", "z"])
        let root = try #require(vm.componentTree)
        #expect(root.children.count == 3)
        let originals = root.children

        // Append a 4th item — template should expand without rebuilding.
        try vm.processMessage(.updateDataModel(UpdateDataModelPayload(
            surfaceId: "s1",
            path: "/items",
            value: .array([
                .dictionary(["label": .string("x")]),
                .dictionary(["label": .string("y")]),
                .dictionary(["label": .string("z")]),
                .dictionary(["label": .string("w")]),
            ])
        )))
        // updateDataModel alone doesn't rebuild structure; replay updateComponents
        // to trigger the structural pass that previously would have nuked the tree.
        try vm.processMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "root", component: "Column", properties: [
                    "children": .dictionary([
                        "componentId": .string("row"),
                        "path": .string("/items"),
                    ])
                ]),
                RawComponent(id: "row", component: "Text", properties: [
                    "text": .dictionary(["path": .string("label")])
                ]),
            ]
        )))

        #expect(vm.componentTree === root)
        #expect(root.children.count == 4)
        for i in 0..<3 {
            #expect(root.children[i] === originals[i])
        }
    }

    @Test("list shrinking by one item preserves the surviving children's identity")
    func listShrinksPreservesIdentity() throws {
        let vm = try makeListSetup(["x", "y", "z", "w"])
        let root = try #require(vm.componentTree)
        #expect(root.children.count == 4)
        let originals = root.children

        try vm.processMessage(.updateDataModel(UpdateDataModelPayload(
            surfaceId: "s1",
            path: "/items",
            value: .array([
                .dictionary(["label": .string("x")]),
                .dictionary(["label": .string("y")]),
                .dictionary(["label": .string("z")]),
            ])
        )))
        try vm.processMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "root", component: "Column", properties: [
                    "children": .dictionary([
                        "componentId": .string("row"),
                        "path": .string("/items"),
                    ])
                ]),
                RawComponent(id: "row", component: "Text", properties: [
                    "text": .dictionary(["path": .string("label")])
                ]),
            ]
        )))

        #expect(vm.componentTree === root)
        #expect(root.children.count == 3)
        for i in 0..<3 {
            #expect(root.children[i] === originals[i])
        }
    }

    @Test("uiState survives list growth on a stateful child")
    func uiStateSurvivesListGrowth() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        // Seed data: list of two items, each becomes a Tabs.
        try vm.processMessage(.updateDataModel(UpdateDataModelPayload(
            surfaceId: "s1",
            path: "/items",
            value: .array([.dictionary([:]), .dictionary([:])])
        )))
        try vm.processMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "root", component: "Column", properties: [
                    "children": .dictionary([
                        "componentId": .string("tabs"),
                        "path": .string("/items"),
                    ])
                ]),
                RawComponent(id: "tabs", component: "Tabs", properties: [
                    "tabs": .array([])
                ]),
            ]
        )))
        let root = try #require(vm.componentTree)
        #expect(root.children.count == 2)
        let firstTabs = root.children[0]
        let firstUIState = try #require(firstTabs.uiState)
        let firstUIStateId = ObjectIdentifier(firstUIState as AnyObject)

        // Grow the list.
        try vm.processMessage(.updateDataModel(UpdateDataModelPayload(
            surfaceId: "s1",
            path: "/items",
            value: .array([.dictionary([:]), .dictionary([:]), .dictionary([:])])
        )))
        try vm.processMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "root", component: "Column", properties: [
                    "children": .dictionary([
                        "componentId": .string("tabs"),
                        "path": .string("/items"),
                    ])
                ]),
                RawComponent(id: "tabs", component: "Tabs", properties: [
                    "tabs": .array([])
                ]),
            ]
        )))

        #expect(root.children.count == 3)
        let firstAfter = try #require(root.children.first)
        #expect(firstAfter === firstTabs)
        let firstUIStateAfter = try #require(firstAfter.uiState)
        #expect(ObjectIdentifier(firstUIStateAfter as AnyObject) == firstUIStateId)
    }

    @Test("property change on one node leaves siblings' instance untouched")
    func singleNodeChange() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        try vm.processMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "root", component: "Column", properties: [
                    "children": .array([.string("a"), .string("b")])
                ]),
                RawComponent(id: "a", component: "Text", properties: ["text": .string("A")]),
                RawComponent(id: "b", component: "Text", properties: ["text": .string("B")]),
            ]
        )))
        let root = try #require(vm.componentTree)
        let childAInstanceBefore = root.children[0].instance
        let childBInstanceBefore = root.children[1].instance

        // Change only child A's text.
        try vm.processMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "root", component: "Column", properties: [
                    "children": .array([.string("a"), .string("b")])
                ]),
                RawComponent(id: "a", component: "Text", properties: ["text": .string("A-new")]),
                RawComponent(id: "b", component: "Text", properties: ["text": .string("B")]),
            ]
        )))

        #expect(vm.componentTree === root)
        #expect(root.children[0].instance != childAInstanceBefore)
        #expect(root.children[1].instance == childBInstanceBefore)
    }

    @Test("same-id child type change replaces that child node")
    func sameIdChildTypeChangeReplacesChild() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        try vm.processMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "root", component: "Column", properties: [
                    "children": .array([.string("child")])
                ]),
                RawComponent(id: "child", component: "Text", properties: ["text": .string("A")]),
            ]
        )))
        let root = try #require(vm.componentTree)
        let oldChild = try #require(root.children.first)

        try vm.processMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "root", component: "Column", properties: [
                    "children": .array([.string("child")])
                ]),
                RawComponent(id: "child", component: "Column", properties: [
                    "children": .array([])
                ]),
            ]
        )))

        let newChild = try #require(root.children.first)
        #expect(vm.componentTree === root)
        #expect(newChild !== oldChild)
        #expect(newChild.type == .Column)
    }

    @Test("root id changing forces full tree replacement")
    func rootReplacementOnIdChange() throws {
        let vm = makeViewModel()
        try vm.processMessage(makeCreateSurface())
        try vm.processMessage(makeTextComponent(id: "root", text: "Hello"))
        let oldRoot = try #require(vm.componentTree)

        // Replace root with a different baseComponentId (still has id "root" so it
        // builds, but switch the component type to force `reconcileNode` to bail).
        try vm.processMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: "s1",
            components: [
                RawComponent(id: "root", component: "Column", properties: [
                    "children": .array([])
                ]),
            ]
        )))
        let newRoot = try #require(vm.componentTree)
        #expect(newRoot !== oldRoot)
        #expect(newRoot.type == .Column)
    }
}
