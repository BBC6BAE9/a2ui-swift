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

import XCTest
@testable import A2UI

// MARK: - Test Helpers

extension RawComponentPayload {
    /// Create a simple Text component payload for testing.
    static func makeText(_ literal: String) -> RawComponentPayload {
        let json: [String: Any] = [
            "Text": ["text": ["literalString": literal]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(RawComponentPayload.self, from: data)
    }
}

final class MessageDecodingTests: XCTestCase {

    private func loadTestJSON(_ filename: String) throws -> [ServerToClientMessage] {
        let url = Bundle.module.url(
            forResource: filename,
            withExtension: "json",
            subdirectory: "TestData"
        )!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([ServerToClientMessage].self, from: data)
    }

    // MARK: - Component Type Parsing

    func testComponentTypeParsing() throws {
        let messages = try loadTestJSON("contact_card")
        let vm = SurfaceViewModel()
        try vm.processMessages(messages)

        let mainCard = vm.components["main_card"]!
        XCTAssertEqual(mainCard.component?.componentType, .Card)
        let cardProps = try mainCard.component?.typedProperties(CardProperties.self)
        XCTAssertNotNil(cardProps)
        XCTAssertEqual(cardProps?.child, "main_column")

        let userHeading = vm.components["user_heading"]!
        XCTAssertEqual(userHeading.component?.componentType, .Text)
        let textProps = try userHeading.component?.typedProperties(TextProperties.self)
        XCTAssertNotNil(textProps)
        XCTAssertEqual(textProps?.usageHint, "h2")
        XCTAssertNotNil(textProps?.text.path)
        XCTAssertEqual(textProps?.text.path, "name")

        let button1 = vm.components["button_1"]!
        XCTAssertEqual(button1.component?.componentType, .Button)
        let buttonProps = try button1.component?.typedProperties(ButtonProperties.self)
        XCTAssertNotNil(buttonProps)
        XCTAssertEqual(buttonProps?.child, "button_1_text")
        XCTAssertEqual(buttonProps?.action.name, "follow_contact")
        XCTAssertEqual(buttonProps?.primary, true)

        let mainColumn = vm.components["main_column"]!
        XCTAssertEqual(mainColumn.component?.componentType, .Column)
        let columnProps = try mainColumn.component?.typedProperties(ColumnProperties.self)
        XCTAssertNotNil(columnProps)
        XCTAssertEqual(columnProps?.children.explicitList?.count, 6)
        XCTAssertEqual(columnProps?.alignment, "stretch")

        let infoRow1 = vm.components["info_row_1"]!
        XCTAssertEqual(infoRow1.component?.componentType, .Row)
        let rowProps = try infoRow1.component?.typedProperties(RowProperties.self)
        XCTAssertNotNil(rowProps)
        XCTAssertEqual(rowProps?.distribution, "start")

        let profileImage = vm.components["profile_image"]!
        XCTAssertEqual(profileImage.component?.componentType, .Image)
        let imageProps = try profileImage.component?.typedProperties(ImageProperties.self)
        XCTAssertNotNil(imageProps)
        XCTAssertEqual(imageProps?.usageHint, "avatar")
        XCTAssertEqual(imageProps?.fit, "cover")
    }

    func testListComponentParsing() throws {
        let messages = try loadTestJSON("single_column_list")
        let vm = SurfaceViewModel()
        try vm.processMessages(messages)

        let itemList = vm.components["item-list"]!
        XCTAssertEqual(itemList.component?.componentType, .List)
        let listProps = try itemList.component?.typedProperties(ListProperties.self)
        XCTAssertNotNil(listProps)
        XCTAssertEqual(listProps?.direction, "vertical")
        XCTAssertNotNil(listProps?.children.template)
        XCTAssertEqual(listProps?.children.template?.componentId, "item-card-template")
        XCTAssertEqual(listProps?.children.template?.dataBinding, "/items")
    }

    func testVideoPropertiesParsing() throws {
        let json: [String: AnyCodable] = [
            "url": .dictionary([
                "literalString": .string("https://example.com/video.mp4")
            ])
        ]
        let data = try! JSONEncoder().encode(json)
        let props = try! JSONDecoder().decode(VideoProperties.self, from: data)
        XCTAssertEqual(props.url.literalString, "https://example.com/video.mp4")
    }

    func testAudioPlayerPropertiesParsing() throws {
        let json: [String: AnyCodable] = [
            "url": .dictionary([
                "path": .string("/audio/url")
            ]),
            "description": .dictionary([
                "literalString": .string("Background music")
            ])
        ]
        let data = try! JSONEncoder().encode(json)
        let props = try! JSONDecoder().decode(AudioPlayerProperties.self, from: data)
        XCTAssertEqual(props.url.path, "/audio/url")
        XCTAssertEqual(props.description?.literalString, "Background music")
    }

    func testTabsPropertiesParsing() throws {
        let json: [String: AnyCodable] = [
            "tabItems": .array([
                .dictionary([
                    "title": .dictionary(["literalString": .string("Tab A")]),
                    "child": .string("child_a")
                ]),
                .dictionary([
                    "title": .dictionary(["literalString": .string("Tab B")]),
                    "child": .string("child_b")
                ])
            ])
        ]
        let data = try! JSONEncoder().encode(json)
        let props = try! JSONDecoder().decode(TabsProperties.self, from: data)
        XCTAssertEqual(props.tabItems.count, 2)
        XCTAssertEqual(props.tabItems[0].title.literalString, "Tab A")
        XCTAssertEqual(props.tabItems[0].child, "child_a")
        XCTAssertEqual(props.tabItems[1].title.literalString, "Tab B")
        XCTAssertEqual(props.tabItems[1].child, "child_b")
    }

    func testModalPropertiesParsing() throws {
        let json: [String: AnyCodable] = [
            "entryPointChild": .string("open_btn"),
            "contentChild": .string("modal_content")
        ]
        let data = try! JSONEncoder().encode(json)
        let props = try! JSONDecoder().decode(ModalProperties.self, from: data)
        XCTAssertEqual(props.entryPointChild, "open_btn")
        XCTAssertEqual(props.contentChild, "modal_content")
    }

    func testMultipleChoicePropertiesParsing() throws {
        let json: [String: AnyCodable] = [
            "selections": .dictionary([
                "path": .string("/selectedFruits")
            ]),
            "options": .array([
                .dictionary([
                    "label": .dictionary(["literalString": .string("Apple")]),
                    "value": .string("apple")
                ]),
                .dictionary([
                    "label": .dictionary(["literalString": .string("Banana")]),
                    "value": .string("banana")
                ]),
                .dictionary([
                    "label": .dictionary(["literalString": .string("Cherry")]),
                    "value": .string("cherry")
                ])
            ]),
            "variant": .string("chips"),
            "filterable": .bool(true)
        ]
        let data = try! JSONEncoder().encode(json)
        let props = try! JSONDecoder().decode(MultipleChoiceProperties.self, from: data)
        XCTAssertEqual(props.selections?.path, "/selectedFruits")
        XCTAssertNil(props.selections?.literalArray)
        XCTAssertEqual(props.options?.count, 3)
        XCTAssertEqual(props.options?[0].label.literalString, "Apple")
        XCTAssertEqual(props.options?[0].value, "apple")
        XCTAssertEqual(props.variant, "chips")
        XCTAssertEqual(props.filterable, true)
    }

    func testMultipleChoiceWriteBack() throws {
        let vm = SurfaceViewModel()
        vm.dataModel["selectedFruits"] = .array([.string("apple")])

        let selections = StringListValue(
            path: "/selectedFruits", literalArray: nil
        )
        var current = vm.resolveStringArray(selections)
        XCTAssertEqual(current, ["apple"])

        vm.setStringArray(path: "/selectedFruits", values: ["apple", "banana"])
        current = vm.resolveStringArray(selections)
        XCTAssertEqual(current, ["apple", "banana"])

        vm.setStringArray(path: "/selectedFruits", values: ["cherry"])
        current = vm.resolveStringArray(selections)
        XCTAssertEqual(current, ["cherry"])

        let literalSelections = StringListValue(
            path: nil, literalArray: ["x", "y"]
        )
        XCTAssertEqual(vm.resolveStringArray(literalSelections), ["x", "y"])
    }

    func testTextFieldPropertiesParsing() throws {
        let messages = try loadTestJSON("booking_form")
        let vm = SurfaceViewModel()
        try vm.processMessages(messages)

        let partySizeField = vm.components["party-size-field"]!
        XCTAssertEqual(partySizeField.component?.componentType, .TextField)

        let props = try partySizeField.component!.typedProperties(TextFieldProperties.self)
        XCTAssertNotNil(props)
        XCTAssertEqual(props.label.literalValue, "Party Size")
        XCTAssertEqual(props.text?.path, "partySize")
    }

    func testDateTimeInputPropertiesParsing() throws {
        let messages = try loadTestJSON("booking_form")
        let vm = SurfaceViewModel()
        try vm.processMessages(messages)

        let dtField = vm.components["datetime-field"]!
        XCTAssertEqual(dtField.component?.componentType, .DateTimeInput)

        let props = try dtField.component!.typedProperties(DateTimeInputProperties.self)
        XCTAssertNotNil(props)
        XCTAssertEqual(props.value.path, "reservationTime")
        XCTAssertEqual(props.enableDate, true)
        XCTAssertEqual(props.enableTime, true)
    }

    // MARK: - SurfaceViewModel

    func testSurfaceViewModelProcessMessages() throws {
        let messages = try loadTestJSON("contact_card")

        let vm = SurfaceViewModel()
        try vm.processMessages(messages)

        XCTAssertEqual(vm.rootComponentId, "main_card")
        XCTAssertEqual(vm.components.count, 36)

        XCTAssertNotNil(vm.dataModel["name"])
        XCTAssertNotNil(vm.dataModel["email"])
        XCTAssertNotNil(vm.dataModel["mobile"])
        XCTAssertNotNil(vm.dataModel["imageUrl"])

        let mainCard = vm.components["main_card"]
        XCTAssertNotNil(mainCard)
        XCTAssertEqual(mainCard?.component?.componentType, .Card)
    }

    func testSurfaceViewModelDeleteSurface() throws {
        let messages = try loadTestJSON("contact_card")

        let vm = SurfaceViewModel()
        try vm.processMessages(messages)

        XCTAssertEqual(vm.components.count, 36)

        let deleteMsg = ServerToClientMessage(
            beginRendering: nil,
            surfaceUpdate: nil,
            dataModelUpdate: nil,
            deleteSurface: DeleteSurfaceMessage(surfaceId: "contact-card")
        )
        try vm.processMessages([deleteMsg])

        XCTAssertNil(vm.rootComponentId)
        XCTAssertTrue(vm.components.isEmpty)
        XCTAssertTrue(vm.dataModel.isEmpty)
    }

    func testProcessMessageSingle() throws {
        let vm = SurfaceViewModel()

        let br = ServerToClientMessage(
            beginRendering: BeginRenderingMessage(
                surfaceId: "s1", root: "root1", styles: ["primaryColor": "#123456"]
            ),
            surfaceUpdate: nil,
            dataModelUpdate: nil,
            deleteSurface: nil
        )
        try vm.processMessage(br)
        XCTAssertEqual(vm.rootComponentId, "root1")
        XCTAssertEqual(vm.styles["primaryColor"], "#123456")
        XCTAssertNotNil(vm.a2uiStyle.primaryColor)
    }

    func testWeightProperty() throws {
        let messages = try loadTestJSON("contact_card")
        let vm = SurfaceViewModel()
        try vm.processMessages(messages)

        let withWeight = vm.components.values.filter { $0.weight != nil }
        let withoutWeight = vm.components.values.filter { $0.weight == nil }
        XCTAssertFalse(withWeight.isEmpty || withoutWeight.isEmpty,
                       "contact_card should have some components with weight and some without")
    }

    // MARK: - Error Reporting

    func testUnknownComponentAccepted() {
        let vm = SurfaceViewModel()
        vm.surfaceId = "test-surface"

        let unknownJSON: [String: AnyCodable] = ["FancyWidget": .dictionary(["label": .string("hi")])]
        let instance = RawComponentInstance(
            id: "widget_1",
            component: RawComponentPayload(typeName: "FancyWidget", properties: unknownJSON)
        )
        let message = ServerToClientMessage(
            surfaceUpdate: SurfaceUpdateMessage(
                surfaceId: "test-surface",
                components: [instance]
            )
        )

        XCTAssertNoThrow(try vm.processMessage(message))
        XCTAssertNotNil(vm.components["widget_1"])
        XCTAssertEqual(vm.components["widget_1"]?.component?.componentType, .custom("FancyWidget"))
    }

    func testMultiSurfaceDecoding() throws {
        let messages = try loadTestJSON("multi_surface")
        XCTAssertEqual(messages.count, 6)

        let beginRenderingCount = messages.filter { $0.beginRendering != nil }.count
        XCTAssertEqual(beginRenderingCount, 2)

        let surfaceUpdateCount = messages.filter { $0.surfaceUpdate != nil }.count
        XCTAssertEqual(surfaceUpdateCount, 2)

        let dataModelUpdateCount = messages.filter { $0.dataModelUpdate != nil }.count
        XCTAssertEqual(dataModelUpdateCount, 2)

        let surfaceIds = Set(
            messages.compactMap { $0.beginRendering?.surfaceId }
        )
        XCTAssertTrue(surfaceIds.contains("contact-card"))
        XCTAssertTrue(surfaceIds.contains("org-chart-view"))

        let manager = SurfaceManager()
        for message in messages {
            try manager.processMessage(message)
        }

        XCTAssertEqual(manager.surfaces.count, 2,
                       "multi_surface.json should create 2 independent surfaces")

        let contactCard = manager.surfaces["contact-card"]
        XCTAssertNotNil(contactCard)
        XCTAssertNotNil(contactCard?.rootComponentId)
        XCTAssertGreaterThan(contactCard?.components.count ?? 0, 20)
        XCTAssertNotNil(contactCard?.getDataByPath("/name"))
    }

    // MARK: - Async JSONL Stream

    func testAsyncStreamFromBytes() async throws {
        let jsonl = """
        {"beginRendering":{"surfaceId":"s1","root":"r1"}}
        {"surfaceUpdate":{"surfaceId":"s1","components":[{"id":"c1","component":{"Text":{"text":{"literalString":"Hi"}}}}]}}
        """
        let bytes = Array(jsonl.utf8)
        let stream = AsyncStream<UInt8> { cont in
            for b in bytes { cont.yield(b) }
            cont.finish()
        }
        let parser = JSONLStreamParser()
        var messages: [ServerToClientMessage] = []
        for try await msg in parser.messages(from: stream) {
            messages.append(msg)
        }
        XCTAssertEqual(messages.count, 2)
        XCTAssertNotNil(messages[0].beginRendering)
        XCTAssertNotNil(messages[1].surfaceUpdate)
    }

    func testAsyncStreamFromBytesNoTrailingNewline() async throws {
        let jsonl = """
        {"beginRendering":{"surfaceId":"s1","root":"r1"}}
        """
        let bytes = Array(jsonl.utf8)
        let stream = AsyncStream<UInt8> { cont in
            for b in bytes { cont.yield(b) }
            cont.finish()
        }
        let parser = JSONLStreamParser()
        var messages: [ServerToClientMessage] = []
        for try await msg in parser.messages(from: stream) {
            messages.append(msg)
        }
        XCTAssertEqual(messages.count, 1, "Should handle last line without trailing newline")
    }

    func testAsyncStreamFromLines() async throws {
        let lines = [
            "{\"beginRendering\":{\"surfaceId\":\"s1\",\"root\":\"r1\"}}",
            "{\"dataModelUpdate\":{\"surfaceId\":\"s1\",\"contents\":[{\"key\":\"x\",\"valueString\":\"y\"}]}}"
        ]
        let stream = AsyncStream<String> { cont in
            for l in lines { cont.yield(l) }
            cont.finish()
        }
        let parser = JSONLStreamParser()
        var messages: [ServerToClientMessage] = []
        for try await msg in parser.messages(fromLines: stream) {
            messages.append(msg)
        }
        XCTAssertEqual(messages.count, 2)
        XCTAssertNotNil(messages[0].beginRendering)
        XCTAssertNotNil(messages[1].dataModelUpdate)
    }

    func testAsyncStreamSkipsInvalidLines() async throws {
        let lines = [
            "{\"beginRendering\":{\"surfaceId\":\"s1\",\"root\":\"r1\"}}",
            "not valid json",
            "",
            "{\"dataModelUpdate\":{\"surfaceId\":\"s1\",\"contents\":[{\"key\":\"k\",\"valueString\":\"v\"}]}}"
        ]
        let stream = AsyncStream<String> { cont in
            for l in lines { cont.yield(l) }
            cont.finish()
        }
        let parser = JSONLStreamParser()
        var messages: [ServerToClientMessage] = []
        for try await msg in parser.messages(fromLines: stream) {
            messages.append(msg)
        }
        XCTAssertEqual(messages.count, 2, "Invalid and blank lines should be skipped")
    }

    // MARK: - Cross-sample Consistency Tests

    func testAllSamplesDecodeSuccessfully() throws {
        let files = [
            "contact_card", "booking_form", "single_column_list", "confirmation",
            "two_column_list", "follow_success", "contact_list",
            "action_confirmation", "recipe_a2ui",
        ]

        for file in files {
            let messages = try loadTestJSON(file)
            XCTAssertGreaterThan(messages.count, 0, "\(file) should have at least one message")

            let manager = SurfaceManager()
            try manager.processMessages(messages)
            XCTAssertGreaterThan(manager.surfaces.count, 0,
                                "\(file) should create at least one surface")

            for (id, vm) in manager.surfaces {
                XCTAssertNotNil(vm.rootComponentId,
                               "\(file) surface '\(id)' should set a rootComponentId")
                XCTAssertGreaterThan(vm.components.count, 0,
                                    "\(file) surface '\(id)' should have components")
            }
        }
    }

    func testAllSamplesJSONLRoundTrip() throws {
        let files = [
            "contact_card", "booking_form", "single_column_list", "confirmation",
            "two_column_list", "follow_success", "contact_list",
            "action_confirmation", "recipe_a2ui",
        ]
        let encoder = JSONEncoder()
        let parser = JSONLStreamParser()

        for file in files {
            let arrayMessages = try loadTestJSON(file)

            var jsonlLines: [String] = []
            for msg in arrayMessages {
                let data = try encoder.encode(msg)
                jsonlLines.append(String(data: data, encoding: .utf8)!)
            }
            let jsonlText = jsonlLines.joined(separator: "\n")
            let streamMessages = parser.parseLines(jsonlText)

            XCTAssertEqual(
                streamMessages.count, arrayMessages.count,
                "\(file): JSONL round-trip message count mismatch"
            )

            let mgrArray = SurfaceManager()
            try mgrArray.processMessages(arrayMessages)

            let mgrStream = SurfaceManager()
            for msg in streamMessages {
                try mgrStream.processMessage(msg)
            }

            XCTAssertEqual(
                mgrArray.surfaces.count, mgrStream.surfaces.count,
                "\(file): surface count mismatch after JSONL round-trip"
            )
            for (id, vmArray) in mgrArray.surfaces {
                let vmStream = mgrStream.surfaces[id]
                XCTAssertNotNil(vmStream, "\(file): surface '\(id)' missing after JSONL round-trip")
                XCTAssertEqual(
                    vmArray.rootComponentId, vmStream?.rootComponentId,
                    "\(file): rootComponentId mismatch for surface '\(id)'"
                )
                XCTAssertEqual(
                    vmArray.components.count, vmStream?.components.count,
                    "\(file): components count mismatch for surface '\(id)'"
                )
            }
        }
    }

    func testAllSamplesBatchVsIncrementalEquivalence() throws {
        let files = [
            "contact_card", "booking_form", "single_column_list", "confirmation",
            "two_column_list", "follow_success", "contact_list",
            "action_confirmation", "recipe_a2ui",
        ]

        for file in files {
            let messages = try loadTestJSON(file)

            let mgrBatch = SurfaceManager()
            try mgrBatch.processMessages(messages)

            let mgrIncr = SurfaceManager()
            for msg in messages {
                try mgrIncr.processMessage(msg)
            }

            XCTAssertEqual(
                mgrBatch.surfaces.count, mgrIncr.surfaces.count,
                "\(file): surface count differs between batch and incremental"
            )
            for (id, vmBatch) in mgrBatch.surfaces {
                let vmIncr = mgrIncr.surfaces[id]
                XCTAssertNotNil(vmIncr, "\(file): surface '\(id)' missing in incremental")
                XCTAssertEqual(
                    vmBatch.rootComponentId, vmIncr?.rootComponentId,
                    "\(file): rootComponentId differs for surface '\(id)'"
                )
                XCTAssertEqual(
                    vmBatch.components.count, vmIncr?.components.count,
                    "\(file): component count differs for surface '\(id)'"
                )
                XCTAssertEqual(
                    vmBatch.dataModel.count, vmIncr?.dataModel.count,
                    "\(file): dataModel count differs for surface '\(id)'"
                )
                XCTAssertEqual(
                    vmBatch.styles, vmIncr?.styles,
                    "\(file): styles differ for surface '\(id)'"
                )
            }
        }
    }
}
