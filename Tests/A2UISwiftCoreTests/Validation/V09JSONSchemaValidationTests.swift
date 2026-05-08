// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0

import A2UISwiftCore
import Foundation
import Testing

@Suite("V09 JSON Schema validation")
struct V09JSONSchemaValidationTests {

    @Test("validateServerToClientMessage accepts minimal createSurface")
    func envelopeCreateSurfaceValid() throws {
        let json: [String: Any] = [
            "version": "v0.9",
            "createSurface": [
                "surfaceId": "s1",
                "catalogId": "https://a2ui.org/specification/v0_9/basic_catalog.json",
            ],
        ]
        try V09JSONSchemaValidation.validateServerToClientMessage(json)
    }

    @Test("validateServerToClientMessage rejects wrong version")
    func envelopeWrongVersion() throws {
        let json: [String: Any] = [
            "version": "v0.8",
            "createSurface": [
                "surfaceId": "s1",
                "catalogId": "https://a2ui.org/specification/v0_9/basic_catalog.json",
            ],
        ]
        #expect(throws: Error.self) {
            try V09JSONSchemaValidation.validateServerToClientMessage(json)
        }
    }

    @Test("validateServerToClientMessage rejects extra top-level keys")
    func envelopeExtraKeys() throws {
        let json: [String: Any] = [
            "version": "v0.9",
            "createSurface": [
                "surfaceId": "s1",
                "catalogId": "https://a2ui.org/specification/v0_9/basic_catalog.json",
            ],
            "oops": true,
        ]
        #expect(throws: Error.self) {
            try V09JSONSchemaValidation.validateServerToClientMessage(json)
        }
    }

    @Test("validateServerToClientMessage rejects empty updateComponents.components")
    func envelopeEmptyComponents() throws {
        let json: [String: Any] = [
            "version": "v0.9",
            "updateComponents": [
                "surfaceId": "s1",
                "components": [] as [Any],
            ],
        ]
        #expect(throws: Error.self) {
            try V09JSONSchemaValidation.validateServerToClientMessage(json)
        }
    }

    @Test("validateCatalogComponent accepts Text from basic catalog shape")
    func componentTextValid() throws {
        let json: [String: Any] = [
            "id": "root",
            "component": "Text",
            "text": "Hello",
            "variant": "body",
        ]
        try V09JSONSchemaValidation.validateCatalogComponent(json, componentType: "Text")
    }

    @Test("validateCatalogComponent rejects Text missing required fields")
    func componentTextInvalid() throws {
        let json: [String: Any] = [
            "id": "root",
            "component": "Text",
            "variant": "body",
        ]
        #expect(throws: Error.self) {
            try V09JSONSchemaValidation.validateCatalogComponent(json, componentType: "Text")
        }
    }

    @Test("A2uiMessage decode rejects unsupported version literal")
    func decodeWrongVersion() {
        let json = #"{"version":"v0.8","createSurface":{"surfaceId":"s","catalogId":"x"}}"#
            .data(using: .utf8)!
        #expect(throws: Error.self) {
            let _ = try JSONDecoder().decode(A2uiMessage.self, from: json)
        }
    }

    @Test("validateServerToClientMessageList accepts two messages")
    func listValid() throws {
        let list: [Any] = [
            [
                "version": "v0.9",
                "createSurface": [
                    "surfaceId": "s1",
                    "catalogId": "https://a2ui.org/specification/v0_9/basic_catalog.json",
                ],
            ],
            [
                "version": "v0.9",
                "deleteSurface": ["surfaceId": "s1"],
            ],
        ]
        try V09JSONSchemaValidation.validateServerToClientMessageList(list)
    }

    @Test("MessageProcessor with basicCatalog rejects invalid Button component")
    func processorRejectsInvalidButton() throws {
        let processor = MessageProcessor(catalogs: [basicCatalog])
        let surfaceErrors = processor.processMessages([
            createSurfaceForBasicCatalog(surfaceId: "s1"),
        ])
        #expect(surfaceErrors.isEmpty)

        let errs = processor.processMessages([
            .updateComponents(UpdateComponentsPayload(
                surfaceId: "s1",
                components: [
                    RawComponent(
                        id: "b1",
                        component: "Button",
                        properties: [
                            "label": .string("nope"),
                        ]
                    ),
                ]
            )),
        ])
        #expect(errs.count == 1)
        #expect(errs.first is A2uiValidationError)
    }

    @Test("MessageProcessor with basicCatalog accepts valid Text component")
    func processorAcceptsValidText() throws {
        let processor = MessageProcessor(catalogs: [basicCatalog])
        #expect(
            processor.processMessages([createSurfaceForBasicCatalog(surfaceId: "s1")]).isEmpty)

        let errs = processor.processMessages([
            .updateComponents(UpdateComponentsPayload(
                surfaceId: "s1",
                components: [
                    RawComponent(
                        id: "root",
                        component: "Text",
                        properties: [
                            "text": .string("Hi"),
                            "variant": .string("body"),
                        ]
                    ),
                ]
            )),
        ])
        #expect(errs.isEmpty)
        #expect(processor.model.getSurface("s1")?.componentsModel.get("root")?.type == "Text")
    }
}

private func createSurfaceForBasicCatalog(surfaceId: String) -> A2uiMessage {
    .createSurface(
        CreateSurfacePayload(
            surfaceId: surfaceId,
            catalogId: basicCatalog.id,
            sendDataModel: false
        )
    )
}
