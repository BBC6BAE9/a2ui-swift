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

@testable import A2UISwiftCore
import Testing
import Foundation

// MARK: - Helpers

private func makeProcessor(
    catalogId: String = "test-catalog",
    actionHandler: ((A2uiClientAction) -> Void)? = nil
) -> MessageProcessor {
    let catalog = Catalog(id: catalogId)
    return MessageProcessor(catalogs: [catalog], actionHandler: actionHandler)
}

private func createSurfaceMsg(
    surfaceId: String,
    catalogId: String = "test-catalog",
    sendDataModel: Bool = false
) -> A2uiMessage {
    .createSurface(CreateSurfacePayload(
        surfaceId: surfaceId,
        catalogId: catalogId,
        sendDataModel: sendDataModel
    ))
}

// MARK: - Tests

@Suite("MessageProcessor")
struct MessageProcessorTests {

    // MARK: Surface Creation

    @Test("creates surface")
    func createsSurface() {
        let processor = makeProcessor()
        processor.processMessages([createSurfaceMsg(surfaceId: "s1")])

        let surface = processor.model.getSurface("s1")
        #expect(surface != nil)
        #expect(surface?.id == "s1")
        #expect(surface?.sendDataModel == false)
    }

    @Test("creates surface with sendDataModel enabled")
    func createsSurfaceWithSendDataModel() {
        let processor = makeProcessor()
        processor.processMessages([createSurfaceMsg(surfaceId: "s1", sendDataModel: true)])

        #expect(processor.model.getSurface("s1")?.sendDataModel == true)
    }

    // MARK: getClientDataModel

    @Test("getClientDataModel filters surfaces correctly")
    func clientDataModelFilters() {
        let processor = makeProcessor()
        processor.processMessages([
            createSurfaceMsg(surfaceId: "s1", sendDataModel: true),
            createSurfaceMsg(surfaceId: "s2", sendDataModel: false),
            .updateDataModel(UpdateDataModelPayload(
                surfaceId: "s1",
                path: "/",
                value: .dictionary(["user": .string("Alice")])
            )),
            .updateDataModel(UpdateDataModelPayload(
                surfaceId: "s2",
                path: "/",
                value: .dictionary(["secret": .string("Bob")])
            )),
        ])

        let dm = processor.getClientDataModel()
        #expect(dm != nil)
        #expect(dm?.version == "v0.9")
        #expect(dm?.surfaces["s1"] != nil)
        #expect(dm?.surfaces["s2"] == nil)
    }

    @Test("getClientDataModel returns undefined if no surfaces have sendDataModel enabled")
    func clientDataModelNilWhenNoSendDataModel() {
        let processor = makeProcessor()
        processor.processMessages([createSurfaceMsg(surfaceId: "s1", sendDataModel: false)])

        #expect(processor.getClientDataModel() == nil)
    }

    @Test("getClientDataModel includes latest data model values")
    func clientDataModelIncludesLatestValues() {
        let processor = makeProcessor()
        processor.processMessages([
            createSurfaceMsg(surfaceId: "form", sendDataModel: true),
            .updateDataModel(UpdateDataModelPayload(
                surfaceId: "form",
                path: "/email",
                value: .string("user@example.com")
            )),
        ])

        let dm = processor.getClientDataModel()
        #expect(dm != nil)
        #expect(dm?.surfaces["form"] != nil)
    }

    // MARK: Component Updates

    @Test("updates components on correct surface")
    func updatesComponents() {
        let processor = makeProcessor()
        processor.processMessages([createSurfaceMsg(surfaceId: "s1")])
        processor.processMessages([
            .updateComponents(UpdateComponentsPayload(
                surfaceId: "s1",
                components: [RawComponent(id: "root", component: "Box")]
            ))
        ])

        #expect(processor.model.getSurface("s1")?.componentsModel.get("root") != nil)
    }

    @Test("updates existing components via message")
    func updatesExistingComponentProperties() {
        let processor = makeProcessor()
        processor.processMessages([createSurfaceMsg(surfaceId: "s1")])

        processor.processMessages([
            .updateComponents(UpdateComponentsPayload(
                surfaceId: "s1",
                components: [RawComponent(id: "btn", component: "Button",
                                          properties: ["label": .string("Initial")])]
            ))
        ])

        let btn = processor.model.getSurface("s1")?.componentsModel.get("btn")
        #expect(btn?.properties["label"] == .string("Initial"))

        processor.processMessages([
            .updateComponents(UpdateComponentsPayload(
                surfaceId: "s1",
                components: [RawComponent(id: "btn", component: "Button",
                                          properties: ["label": .string("Updated")])]
            ))
        ])

        #expect(btn?.properties["label"] == .string("Updated"))
    }

    // MARK: Surface Deletion

    @Test("deletes surface")
    func deletesSurface() {
        let processor = makeProcessor()
        processor.processMessages([createSurfaceMsg(surfaceId: "s1")])
        #expect(processor.model.getSurface("s1") != nil)

        processor.processMessages([
            .deleteSurface(DeleteSurfacePayload(surfaceId: "s1"))
        ])
        #expect(processor.model.getSurface("s1") == nil)
    }

    // MARK: Data Model Updates

    @Test("routes data model updates")
    func routesDataModelUpdates() {
        let processor = makeProcessor()
        processor.processMessages([createSurfaceMsg(surfaceId: "s1")])

        processor.processMessages([
            .updateDataModel(UpdateDataModelPayload(
                surfaceId: "s1",
                path: "/foo",
                value: .string("bar")
            ))
        ])

        #expect(processor.model.getSurface("s1")?.dataModel.get("/foo") == .string("bar"))
    }

    // MARK: Lifecycle Listeners

    @Test("notifies lifecycle listeners")
    func lifecycleListeners() {
        let processor = makeProcessor()
        var created: SurfaceModel?
        var deletedId: String?

        let sub1 = processor.onSurfaceCreated { created = $0 }
        let sub2 = processor.onSurfaceDeleted { deletedId = $0 }

        processor.processMessages([createSurfaceMsg(surfaceId: "s1")])
        #expect(created?.id == "s1")

        processor.processMessages([.deleteSurface(DeleteSurfacePayload(surfaceId: "s1"))])
        #expect(deletedId == "s1")

        // Verify unsubscribe stops notifications
        created = nil
        sub1.unsubscribe()
        processor.processMessages([createSurfaceMsg(surfaceId: "s2")])
        #expect(created == nil)

        sub2.unsubscribe()
    }

    // MARK: throws on message with multiple update types

    @Test("throws on message with multiple update types")
    func throwsMultipleUpdateTypes() {
        // NOTE: WebCore は JSON の型システム上 as any でキャストして渡すが、
        // Swift では JSON デコード時点で enum の排他性が保証されるため、
        // デコード失敗（DecodingError）として捕捉される。
        let json = """
        {
            "version": "v0.9",
            "updateComponents": { "surfaceId": "s1", "components": [] },
            "updateDataModel": { "surfaceId": "s1", "path": "/" }
        }
        """
        #expect(throws: Error.self) {
            let _ = try JSONDecoder().decode(A2uiMessage.self, from: json.data(using: .utf8)!)
        }
    }

    // MARK: Recreate Component on Type Change

    @Test("recreates component when type changes")
    func recreatesComponentOnTypeChange() {
        let processor = makeProcessor()
        processor.processMessages([createSurfaceMsg(surfaceId: "s1")])

        processor.processMessages([
            .updateComponents(UpdateComponentsPayload(
                surfaceId: "s1",
                components: [RawComponent(id: "comp1", component: "Button",
                                          properties: ["label": .string("Btn")])]
            ))
        ])
        #expect(processor.model.getSurface("s1")?.componentsModel.get("comp1")?.type == "Button")

        processor.processMessages([
            .updateComponents(UpdateComponentsPayload(
                surfaceId: "s1",
                components: [RawComponent(id: "comp1", component: "Label",
                                          properties: ["text": .string("Lbl")])]
            ))
        ])

        let comp = processor.model.getSurface("s1")?.componentsModel.get("comp1")
        #expect(comp?.type == "Label")
        #expect(comp?.properties["text"] == .string("Lbl"))
        #expect(comp?.properties["label"] == nil)
    }

    // MARK: Error Cases
    // Per spec §76-82, processMessages no longer throws — errors are returned in the array.

    @Test("reports error when catalog not found")
    func throwsCatalogNotFound() {
        let processor = makeProcessor()
        let errors = processor.processMessages([
            createSurfaceMsg(surfaceId: "s1", catalogId: "unknown-catalog")
        ])
        #expect(errors.count == 1)
        #expect(errors.first is A2uiStateError)
    }

    @Test("reports error when duplicate surface created")
    func throwsDuplicateSurface() {
        let processor = makeProcessor()
        processor.processMessages([createSurfaceMsg(surfaceId: "s1")])

        let errors = processor.processMessages([createSurfaceMsg(surfaceId: "s1")])
        #expect(errors.count == 1)
        #expect(errors.first is A2uiStateError)
    }

    @Test("reports error when updating non-existent surface")
    func throwsUpdateComponentsNonExistentSurface() {
        let processor = makeProcessor()
        let errors = processor.processMessages([
            .updateComponents(UpdateComponentsPayload(surfaceId: "unknown-s", components: []))
        ])
        #expect(errors.count == 1)
        #expect(errors.first is A2uiStateError)
    }

    @Test("reports error when creating component without type")
    func throwsComponentWithoutType() {
        let processor = makeProcessor()
        processor.processMessages([createSurfaceMsg(surfaceId: "s1")])

        let errors = processor.processMessages([
            .updateComponents(UpdateComponentsPayload(
                surfaceId: "s1",
                components: [RawComponent(id: "comp1", component: "")]
            ))
        ])
        #expect(errors.count == 1)
        #expect(errors.first is A2uiValidationError)
        #expect(processor.model.getSurface("s1")?.componentsModel.get("comp1") == nil)
    }

    @Test("throws when component is missing id")
    func throwsComponentMissingId() {
        // WebCore 在运行时检查 missing 'id' 并抛出 A2uiValidationError。
        // Swift 中 RawComponent 的 id 字段是必需的 Codable 属性，
        // missing id 在 JSON 解码阶段就会产生 DecodingError，
        // 两者结果等价（均阻止无效组件被创建），但错误类型不同。
        let json = """
        [{
            "version": "v0.9",
            "updateComponents": {
                "surfaceId": "s1",
                "components": [{ "component": "Button" }]
            }
        }]
        """
        #expect(throws: Error.self) {
            let _ = try JSONDecoder().decode([A2uiMessage].self, from: json.data(using: .utf8)!)
        }
    }

    @Test("reports error when updating data on non-existent surface")
    func throwsUpdateDataModelNonExistentSurface() {
        let processor = makeProcessor()
        let errors = processor.processMessages([
            .updateDataModel(UpdateDataModelPayload(surfaceId: "unknown-s", path: "/"))
        ])
        #expect(errors.count == 1)
        #expect(errors.first is A2uiStateError)
    }

    // MARK: Root component validation (spec §179)

    @Test("dispatches error when root component missing")
    func warnsWhenRootMissing() {
        let processor = makeProcessor()
        var receivedError: A2uiClientError?
        processor.processMessages([createSurfaceMsg(surfaceId: "s1")])

        let sub = processor.model.getSurface("s1")!.onError.subscribe { receivedError = $0 }

        processor.processMessages([
            .updateComponents(UpdateComponentsPayload(
                surfaceId: "s1",
                components: [RawComponent(id: "btn", component: "Button")]
            ))
        ])
        
        #expect(receivedError != nil)
        #expect(receivedError?.code == "VALIDATION_FAILED")
        #expect(receivedError?.path == "/updateComponents/components")
        sub.unsubscribe()
    }

    @Test("does not error when root component present")
    func noErrorWhenRootPresent() {
        let processor = makeProcessor()
        var receivedError: A2uiClientError?
        processor.processMessages([createSurfaceMsg(surfaceId: "s1")])

        let sub = processor.model.getSurface("s1")!.onError.subscribe { receivedError = $0 }

        processor.processMessages([
            .updateComponents(UpdateComponentsPayload(
                surfaceId: "s1",
                components: [RawComponent(id: "root", component: "Column")]
            ))
        ])

        #expect(receivedError == nil)
        sub.unsubscribe()
    }

    // MARK: resolvePath

    @Test("resolves paths correctly via resolvePath")
    func resolvesPaths() {
        let processor = makeProcessor()
        #expect(processor.resolvePath("/foo", contextPath: "/bar") == "/foo")
        #expect(processor.resolvePath("foo", contextPath: "/bar") == "/bar/foo")
        #expect(processor.resolvePath("foo", contextPath: "/bar/") == "/bar/foo")
        #expect(processor.resolvePath("foo") == "/foo")
    }

    // NOTE: WebCore 的 getClientCapabilities 测试在 Swift 中不适用。
    // getClientCapabilities 生成 JSON Schema（基于 Zod schema、REF: 语法转换等），
    // 这是 TypeScript 服务端专属能力，用于向 LLM 描述可用组件结构。
    // Swift 实现作为纯客户端渲染器，不负责生成 capabilities，无对应实现。
}
