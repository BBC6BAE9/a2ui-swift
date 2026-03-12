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

final class DataBindingTests: XCTestCase {

    private func loadTestJSON(_ filename: String) throws -> [ServerToClientMessage] {
        let url = Bundle.module.url(
            forResource: filename,
            withExtension: "json",
            subdirectory: "TestData"
        )!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([ServerToClientMessage].self, from: data)
    }

    // MARK: - Path Resolution

    func testResolveStringLiteral() throws {
        let vm = SurfaceViewModel()
        let value = StringValue(literalString: "Hello")
        XCTAssertEqual(vm.resolveString(value), "Hello")
    }

    func testResolveStringWithLiteralField() throws {
        let vm = SurfaceViewModel()
        let value = StringValue(literal: "World")
        XCTAssertEqual(vm.resolveString(value), "World")
    }

    func testBoundValueSeedsDataModelWhenBothPresent() throws {
        let vm = SurfaceViewModel()

        let strValue = StringValue(path: "userName", literalString: "Alice")
        XCTAssertEqual(vm.resolveString(strValue), "Alice")
        XCTAssertEqual(vm.getDataByPath("/userName")?.stringValue, "Alice",
                       "literal should be written into dataModel at path")

        let numValue = NumberValue(path: "score", literalNumber: 95)
        XCTAssertEqual(vm.resolveNumber(numValue), 95)
        XCTAssertEqual(vm.getDataByPath("/score")?.numberValue, 95)

        let boolValue = BooleanValue(path: "active", literalBoolean: true)
        XCTAssertEqual(vm.resolveBoolean(boolValue), true)
        XCTAssertEqual(vm.getDataByPath("/active")?.boolValue, true)
    }

    func testBoundValueDoesNotOverwriteExistingData() throws {
        let vm = SurfaceViewModel()

        vm.setData(path: "userName", value: .string("Bob"))

        let strValue = StringValue(path: "userName", literalString: "Alice")
        XCTAssertEqual(vm.resolveString(strValue), "Bob",
                       "existing data model value should take priority over literal")

        vm.setData(path: "score", value: .number(50))
        let numValue = NumberValue(path: "score", literalNumber: 95)
        XCTAssertEqual(vm.resolveNumber(numValue), 50)

        vm.setData(path: "active", value: .bool(false))
        let boolValue = BooleanValue(path: "active", literalBoolean: true)
        XCTAssertEqual(vm.resolveBoolean(boolValue), false)
    }

    func testResolveStringNestedPath() throws {
        let vm = SurfaceViewModel()
        vm.dataModel["user"] = .dictionary([
            "profile": .dictionary([
                "displayName": .string("Jane Smith")
            ])
        ])

        let value = StringValue(path: "/user/profile/displayName")
        XCTAssertEqual(vm.resolveString(value), "Jane Smith")
    }

    func testResolveNumber() throws {
        let vm = SurfaceViewModel()
        vm.dataModel["count"] = .number(42)

        let literal = NumberValue(literalNumber: 99)
        XCTAssertEqual(vm.resolveNumber(literal), 99)

        let pathValue = NumberValue(path: "count")
        XCTAssertEqual(vm.resolveNumber(pathValue), 42)
    }

    func testResolveBoolean() throws {
        let vm = SurfaceViewModel()
        vm.dataModel["isActive"] = .bool(true)

        let literal = BooleanValue(literalBoolean: false)
        XCTAssertEqual(vm.resolveBoolean(literal), false)

        let pathValue = BooleanValue(path: "isActive")
        XCTAssertEqual(vm.resolveBoolean(pathValue), true)
    }

    func testGetDataByPathWithArrayIndex() throws {
        let vm = SurfaceViewModel()
        vm.dataModel["items"] = .array([
            .dictionary(["title": .string("Item A")]),
            .dictionary(["title": .string("Item B")])
        ])

        let result = vm.getDataByPath("/items/0/title")
        XCTAssertEqual(result?.stringValue, "Item A")

        let result2 = vm.getDataByPath("/items/1/title")
        XCTAssertEqual(result2?.stringValue, "Item B")
    }

    func testResolvePathRelative() {
        let vm = SurfaceViewModel()
        XCTAssertEqual(vm.resolvePath("name", context: "/"), "/name")
        XCTAssertEqual(vm.resolvePath("name", context: "/user"), "/user/name")
        XCTAssertEqual(vm.resolvePath("/absolute", context: "/user"), "/absolute")
        XCTAssertEqual(vm.resolvePath(".", context: "/user"), "/user")
    }

    func testResolveStringFromContactCard() throws {
        let messages = try loadTestJSON("contact_card")
        let vm = SurfaceViewModel()
        try vm.processMessages(messages)

        vm.dataModel["name"] = .string("John Doe")
        vm.dataModel["calendar"] = .string("March 15, 2026")

        let userHeading = vm.components["user_heading"]!
        let textProps = try userHeading.component!.typedProperties(TextProperties.self)
        XCTAssertEqual(vm.resolveString(textProps.text), "John Doe")

        let calendarText = vm.components["calendar_primary_text"]!
        let calProps = try calendarText.component!.typedProperties(TextProperties.self)
        XCTAssertEqual(vm.resolveString(calProps.text), "March 15, 2026")

        let calendarLabel = vm.components["calendar_secondary_text"]!
        let labelProps = try calendarLabel.component!.typedProperties(TextProperties.self)
        XCTAssertEqual(vm.resolveString(labelProps.text), "Calendar")
    }

    // MARK: - normalizePath

    func testNormalizePath() {
        let vm = SurfaceViewModel()

        XCTAssertEqual(vm.normalizePath("name"), "name")
        XCTAssertEqual(vm.normalizePath("/name"), "/name")

        XCTAssertEqual(vm.normalizePath("items[0]"), "items/0")
        XCTAssertEqual(vm.normalizePath("/items[0]/title"), "/items/0/title")
        XCTAssertEqual(vm.normalizePath("bookRecommendations[0].title"),
                       "bookRecommendations/0/title")

        XCTAssertEqual(vm.normalizePath("book.0.title"), "book/0/title")
        XCTAssertEqual(vm.normalizePath("user.profile.name"), "user/profile/name")
    }

    func testGetDataByPathWithNormalization() {
        let vm = SurfaceViewModel()
        vm.dataModel["items"] = .array([
            .dictionary(["title": .string("First")]),
            .dictionary(["title": .string("Second")])
        ])

        XCTAssertEqual(vm.getDataByPath("items[0].title")?.stringValue, "First")
        XCTAssertEqual(vm.getDataByPath("items[1].title")?.stringValue, "Second")
    }

    func testResolveStringWithDataContextPath() throws {
        let vm = SurfaceViewModel()
        vm.dataModel["items"] = .dictionary([
            "item1": .dictionary([
                "name": .string("The Fancy Place"),
                "rating": .number(4.8)
            ])
        ])

        let nameValue = StringValue(path: "name")
        XCTAssertEqual(
            vm.resolveString(nameValue, dataContextPath: "/items/item1"),
            "The Fancy Place"
        )

        let ratingValue = NumberValue(path: "rating")
        XCTAssertEqual(
            vm.resolveNumber(ratingValue, dataContextPath: "/items/item1"),
            4.8
        )
    }

    // MARK: - Template (Dynamic List)

    func testTemplateWithDictionaryData() throws {
        let messages = try loadTestJSON("single_column_list")
        let vm = SurfaceViewModel()
        try vm.processMessages(messages)

        XCTAssertEqual(vm.rootComponentId, "root-column")

        XCTAssertNil(vm.dataModel["title"])
        let titleValue = StringValue(path: "title")
        XCTAssertEqual(vm.resolveString(titleValue), "")

        let items = vm.getDataByPath("/items")
        XCTAssertNotNil(items?.dictionaryValue)
        XCTAssertEqual(items?.dictionaryValue?.count, 2)

        XCTAssertEqual(
            vm.getDataByPath("/items/item1/name")?.stringValue,
            "The Fancy Place"
        )
        XCTAssertEqual(
            vm.getDataByPath("/items/item2/name")?.stringValue,
            "Quick Bites"
        )
        XCTAssertEqual(
            vm.getDataByPath("/items/item1/rating")?.numberValue,
            4.8
        )
        XCTAssertEqual(
            vm.getDataByPath("/items/item2/rating")?.numberValue,
            4.2
        )

        let nameValue = StringValue(path: "name")
        XCTAssertEqual(
            vm.resolveString(nameValue, dataContextPath: "/items/item1"),
            "The Fancy Place"
        )
        XCTAssertEqual(
            vm.resolveString(nameValue, dataContextPath: "/items/item2"),
            "Quick Bites"
        )

        let detailValue = StringValue(path: "detail")
        XCTAssertEqual(
            vm.resolveString(detailValue, dataContextPath: "/items/item1"),
            "Fine dining experience"
        )
        XCTAssertEqual(
            vm.resolveString(detailValue, dataContextPath: "/items/item2"),
            "Casual and fast"
        )
    }

    func testTemplateWithArrayData() throws {
        let vm = SurfaceViewModel()
        vm.dataModel["todos"] = .array([
            .dictionary(["text": .string("Buy milk")]),
            .dictionary(["text": .string("Walk dog")]),
            .dictionary(["text": .string("Code review")])
        ])

        let textValue = StringValue(path: "text")

        XCTAssertEqual(
            vm.resolveString(textValue, dataContextPath: "/todos/0"),
            "Buy milk"
        )
        XCTAssertEqual(
            vm.resolveString(textValue, dataContextPath: "/todos/1"),
            "Walk dog"
        )
        XCTAssertEqual(
            vm.resolveString(textValue, dataContextPath: "/todos/2"),
            "Code review"
        )
    }

    // MARK: - Action Context Resolution

    func testActionContextResolution() throws {
        let messages = try loadTestJSON("single_column_list")
        let vm = SurfaceViewModel()
        try vm.processMessages(messages)

        let button = vm.components["template-book-button"]!
        let buttonProps = try button.component!.typedProperties(ButtonProperties.self)

        let resolved = vm.resolveAction(
            buttonProps.action,
            sourceComponentId: "template-book-button",
            dataContextPath: "/items/item1"
        )

        XCTAssertEqual(resolved.name, "book_restaurant")
        XCTAssertEqual(resolved.sourceComponentId, "template-book-button")
        XCTAssertEqual(resolved.context["restaurantName"]?.stringValue, "The Fancy Place")
        XCTAssertEqual(resolved.context["imageUrl"]?.stringValue, "https://example.com/fancy.jpg")
        XCTAssertEqual(resolved.context["address"]?.stringValue, "123 Main St")

        let resolved2 = vm.resolveAction(
            buttonProps.action,
            sourceComponentId: "template-book-button",
            dataContextPath: "/items/item2"
        )
        XCTAssertEqual(resolved2.context["restaurantName"]?.stringValue, "Quick Bites")
        XCTAssertEqual(resolved2.context["address"]?.stringValue, "456 Oak Ave")
    }

    func testActionContextResolutionWithLiterals() throws {
        let vm = SurfaceViewModel()

        let action = Action(
            name: "test_action",
            context: [
                ActionContextEntry(
                    key: "label",
                    value: BoundValue(literalString: "hello")
                ),
                ActionContextEntry(
                    key: "count",
                    value: BoundValue(literalNumber: 42)
                ),
                ActionContextEntry(
                    key: "active",
                    value: BoundValue(literalBoolean: true)
                ),
            ]
        )

        let resolved = vm.resolveAction(
            action, sourceComponentId: "test-btn"
        )

        XCTAssertEqual(resolved.name, "test_action")
        XCTAssertEqual(resolved.context["label"]?.stringValue, "hello")
        XCTAssertEqual(resolved.context["count"]?.numberValue, 42)
        XCTAssertEqual(resolved.context["active"]?.boolValue, true)
    }

    func testActionContextResolutionBookingForm() throws {
        let messages = try loadTestJSON("booking_form")
        let vm = SurfaceViewModel()
        try vm.processMessages(messages)

        vm.setData(path: "partySize", value: .string("4"))

        let button = vm.components["submit-button"]!
        let buttonProps = try button.component!.typedProperties(ButtonProperties.self)

        let resolved = vm.resolveAction(
            buttonProps.action, sourceComponentId: "submit-button"
        )

        XCTAssertEqual(resolved.name, "submit_booking")
        XCTAssertEqual(resolved.context["partySize"]?.stringValue, "4")
        XCTAssertEqual(
            resolved.context["restaurantName"]?.stringValue,
            "[RestaurantName]"
        )
    }

    // MARK: - Input Component Write-back

    func testInputComponentWriteBack() throws {
        let vm = SurfaceViewModel()
        vm.dataModel["partySize"] = .string("2")

        vm.setData(path: "partySize", value: .string("5"))
        XCTAssertEqual(vm.getDataByPath("/partySize")?.stringValue, "5")

        vm.setData(path: "optIn", value: .bool(true))
        XCTAssertEqual(vm.getDataByPath("/optIn")?.boolValue, true)

        vm.setData(path: "rating", value: .number(4.5))
        XCTAssertEqual(vm.getDataByPath("/rating")?.numberValue, 4.5)
    }

    func testInputComponentWriteBackWithContext() throws {
        let vm = SurfaceViewModel()
        vm.dataModel["items"] = .dictionary([
            "item1": .dictionary(["qty": .string("1")])
        ])

        vm.setData(
            path: "qty",
            value: .string("3"),
            dataContextPath: "/items/item1"
        )
        XCTAssertEqual(
            vm.getDataByPath("/items/item1/qty")?.stringValue, "3"
        )
    }

    // MARK: - setData (Nested Path Write)

    func testSetDataTopLevel() {
        let vm = SurfaceViewModel()
        vm.setData(path: "/name", value: .string("Alice"))
        XCTAssertEqual(vm.getDataByPath("/name")?.stringValue, "Alice")
    }

    func testSetDataNestedPath() {
        let vm = SurfaceViewModel()
        vm.dataModel["user"] = .dictionary(["age": .number(30)])
        vm.setData(path: "/user/name", value: .string("Bob"))
        XCTAssertEqual(vm.getDataByPath("/user/name")?.stringValue, "Bob")
        XCTAssertEqual(vm.getDataByPath("/user/age")?.numberValue, 30)
    }

    func testSetDataDeepNestedCreatesIntermediates() {
        let vm = SurfaceViewModel()
        vm.setData(path: "/a/b/c", value: .string("deep"))
        XCTAssertEqual(vm.getDataByPath("/a/b/c")?.stringValue, "deep")
    }

    func testSetDataArrayIndex() {
        let vm = SurfaceViewModel()
        vm.dataModel["items"] = .array([.string("x"), .string("y")])
        vm.setData(path: "/items/1", value: .string("z"))
        XCTAssertEqual(vm.getDataByPath("/items/1")?.stringValue, "z")
        XCTAssertEqual(vm.getDataByPath("/items/0")?.stringValue, "x")
    }

    // MARK: - Incremental Updates

    func testIncrementalSurfaceUpdateOverwrites() throws {
        let vm = SurfaceViewModel()

        let br = ServerToClientMessage(
            beginRendering: BeginRenderingMessage(surfaceId: "s1", root: "root"),
            surfaceUpdate: nil, dataModelUpdate: nil, deleteSurface: nil
        )
        try vm.processMessage(br)

        let textJSON = RawComponentPayload.makeText("Hello")
        let su1 = ServerToClientMessage(
            beginRendering: nil,
            surfaceUpdate: SurfaceUpdateMessage(surfaceId: "s1", components: [
                RawComponentInstance(id: "t1", weight: nil, component: textJSON),
                RawComponentInstance(id: "t2", weight: nil, component: textJSON)
            ]),
            dataModelUpdate: nil, deleteSurface: nil
        )
        try vm.processMessage(su1)
        XCTAssertEqual(vm.components.count, 2)
        XCTAssertNotNil(vm.components["t1"])
        XCTAssertNotNil(vm.components["t2"])

        let textJSON2 = RawComponentPayload.makeText("Updated")
        let su2 = ServerToClientMessage(
            beginRendering: nil,
            surfaceUpdate: SurfaceUpdateMessage(surfaceId: "s1", components: [
                RawComponentInstance(id: "t1", weight: 2.0, component: textJSON2),
                RawComponentInstance(id: "t3", weight: nil, component: textJSON2)
            ]),
            dataModelUpdate: nil, deleteSurface: nil
        )
        try vm.processMessage(su2)

        XCTAssertEqual(vm.components.count, 3, "t1 overwritten, t2 kept, t3 added")
        XCTAssertEqual(vm.components["t1"]?.weight, 2.0)
        XCTAssertNotNil(vm.components["t2"])
        XCTAssertNotNil(vm.components["t3"])
    }

    func testIncrementalDataModelUpdateMerges() throws {
        let vm = SurfaceViewModel()

        let br = ServerToClientMessage(
            beginRendering: BeginRenderingMessage(surfaceId: "s1", root: "root"),
            surfaceUpdate: nil, dataModelUpdate: nil, deleteSurface: nil
        )
        try vm.processMessage(br)

        let dm1 = ServerToClientMessage(
            beginRendering: nil, surfaceUpdate: nil,
            dataModelUpdate: DataModelUpdateMessage(
                surfaceId: "s1", path: nil,
                contents: [
                    ValueMapEntry(key: "name", valueString: "Alice", valueNumber: nil, valueBoolean: nil, valueMap: nil),
                    ValueMapEntry(key: "age", valueString: nil, valueNumber: 30, valueBoolean: nil, valueMap: nil)
                ]
            ),
            deleteSurface: nil
        )
        try vm.processMessage(dm1)
        XCTAssertEqual(vm.getDataByPath("/name")?.stringValue, "Alice")
        XCTAssertEqual(vm.getDataByPath("/age")?.numberValue, 30)

        let dm2 = ServerToClientMessage(
            beginRendering: nil, surfaceUpdate: nil,
            dataModelUpdate: DataModelUpdateMessage(
                surfaceId: "s1", path: nil,
                contents: [
                    ValueMapEntry(key: "name", valueString: "Bob", valueNumber: nil, valueBoolean: nil, valueMap: nil)
                ]
            ),
            deleteSurface: nil
        )
        try vm.processMessage(dm2)
        XCTAssertEqual(vm.getDataByPath("/name")?.stringValue, "Bob", "name overwritten")
        XCTAssertEqual(vm.getDataByPath("/age")?.numberValue, 30, "age preserved from first update")
    }

    func testIncrementalDataModelSubPathMerge() throws {
        let vm = SurfaceViewModel()

        let br = ServerToClientMessage(
            beginRendering: BeginRenderingMessage(surfaceId: "s1", root: "root"),
            surfaceUpdate: nil, dataModelUpdate: nil, deleteSurface: nil
        )
        try vm.processMessage(br)

        let dm1 = ServerToClientMessage(
            beginRendering: nil, surfaceUpdate: nil,
            dataModelUpdate: DataModelUpdateMessage(
                surfaceId: "s1", path: nil,
                contents: [
                    ValueMapEntry(key: "user", valueString: nil, valueNumber: nil, valueBoolean: nil, valueMap: [
                        ValueMapEntry(key: "name", valueString: "Alice", valueNumber: nil, valueBoolean: nil, valueMap: nil),
                        ValueMapEntry(key: "email", valueString: "alice@test.com", valueNumber: nil, valueBoolean: nil, valueMap: nil)
                    ])
                ]
            ),
            deleteSurface: nil
        )
        try vm.processMessage(dm1)
        XCTAssertEqual(vm.getDataByPath("/user/name")?.stringValue, "Alice")
        XCTAssertEqual(vm.getDataByPath("/user/email")?.stringValue, "alice@test.com")

        let dm2 = ServerToClientMessage(
            beginRendering: nil, surfaceUpdate: nil,
            dataModelUpdate: DataModelUpdateMessage(
                surfaceId: "s1", path: "/user",
                contents: [
                    ValueMapEntry(key: "email", valueString: "bob@test.com", valueNumber: nil, valueBoolean: nil, valueMap: nil)
                ]
            ),
            deleteSurface: nil
        )
        try vm.processMessage(dm2)
        XCTAssertEqual(vm.getDataByPath("/user/email")?.stringValue, "bob@test.com", "email updated via sub-path")
    }

    func testIncrementalProcessMessageSequence() throws {
        let messages = try loadTestJSON("contact_card")

        let vmBatch = SurfaceViewModel()
        try vmBatch.processMessages(messages)

        let vmIncr = SurfaceViewModel()
        for msg in messages {
            try vmIncr.processMessage(msg)
        }

        XCTAssertEqual(vmBatch.rootComponentId, vmIncr.rootComponentId)
        XCTAssertEqual(vmBatch.components.count, vmIncr.components.count)
        XCTAssertEqual(vmBatch.dataModel.count, vmIncr.dataModel.count)
        XCTAssertEqual(vmBatch.styles, vmIncr.styles)

        for (key, batchComp) in vmBatch.components {
            let incrComp = vmIncr.components[key]
            XCTAssertNotNil(incrComp, "Component \(key) missing in incremental VM")
            XCTAssertEqual(batchComp.component?.typeName, incrComp?.component?.typeName)
        }
    }
}
