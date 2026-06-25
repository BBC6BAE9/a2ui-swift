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
        // NOTE: WebCore casts this as any under JSON's type system,
        // but Swift guarantees enum exclusivity during JSON decoding,
        // so this is caught as a decoding failure (DecodingError).
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
        // WebCore checks for a missing 'id' at runtime and throws A2uiValidationError.
        // In Swift, RawComponent.id is a required Codable property,
        // so a missing id produces DecodingError during JSON decoding.
        // The result is equivalent because both prevent creating the invalid component, but the error type differs.
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

    // NOTE: WebCore's getClientCapabilities test does not apply in Swift.
    // getClientCapabilities generates JSON Schema based on Zod schemas, REF: syntax conversion, and related TypeScript-only machinery.
    // This is a TypeScript server-side capability used to describe available component structures to an LLM.
    // The Swift implementation is a pure client renderer and does not generate capabilities, so there is no corresponding implementation.

    // MARK: Version compatibility (v0.9 / v0.9.1)
    // v0.9.1 is a backward-compatible refinement of v0.9; schemas accept both
    // version strings. See specification/v0_9_1/docs/evolution_guide.md.

    @Test("accepts v0.9 version string")
    func acceptsV09Version() throws {
        let json = #"{"version":"v0.9","deleteSurface":{"surfaceId":"s1"}}"#
        let msg = try JSONDecoder().decode(A2uiMessage.self, from: json.data(using: .utf8)!)
        if case .deleteSurface(let payload) = msg {
            #expect(payload.surfaceId == "s1")
        } else {
            Issue.record("expected deleteSurface message")
        }
    }

    @Test("accepts v0.9.1 version string")
    func acceptsV091Version() throws {
        let json = #"{"version":"v0.9.1","deleteSurface":{"surfaceId":"s1"}}"#
        let msg = try JSONDecoder().decode(A2uiMessage.self, from: json.data(using: .utf8)!)
        if case .deleteSurface(let payload) = msg {
            #expect(payload.surfaceId == "s1")
        } else {
            Issue.record("expected deleteSurface message")
        }
    }

    @Test("rejects unsupported version string")
    func rejectsUnsupportedVersion() {
        let json = #"{"version":"v0.8","deleteSurface":{"surfaceId":"s1"}}"#
        #expect(throws: Error.self) {
            let _ = try JSONDecoder().decode(A2uiMessage.self, from: json.data(using: .utf8)!)
        }
    }

    // MARK: surfaceId uniqueness relaxation (v0.9.1)
    // The lifetime-global uniqueness constraint was removed: a surfaceId may be
    // reused once its surface is deleted. Re-creating a *live* surface is still
    // an error. See specification/v0_9_1/docs/evolution_guide.md §2.2.

    @Test("allows reusing a surfaceId after the surface is deleted")
    func reusesSurfaceIdAfterDelete() {
        let processor = makeProcessor()
        processor.processMessages([createSurfaceMsg(surfaceId: "s1")])
        processor.processMessages([.deleteSurface(DeleteSurfacePayload(surfaceId: "s1"))])
        #expect(processor.model.getSurface("s1") == nil)

        let errors = processor.processMessages([createSurfaceMsg(surfaceId: "s1")])
        #expect(errors.isEmpty)
        #expect(processor.model.getSurface("s1") != nil)
    }
}
