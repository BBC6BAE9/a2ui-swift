// Copyright 2025 GenUI Authors.

import XCTest
@testable import Primitives
final class GenAIPrimitivesTests: XCTestCase {

    // MARK: - Part helpers

    func testMimeTypeHelper() {
        // Test with extensions
        XCTAssertEqual(DataPart.mimeTypeForFile("test.png"), "image/png")

        // Test with header bytes (sniffing)
        let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        XCTAssertEqual(
            DataPart.mimeTypeForFile("unknown", headerBytes: pngHeader),
            "image/png"
        )

        let pdfHeader = Data([0x25, 0x50, 0x44, 0x46])
        XCTAssertEqual(
            DataPart.mimeTypeForFile("file", headerBytes: pdfHeader),
            "application/pdf"
        )
    }

    func testNameFromMimeType() {
        XCTAssertEqual(DataPart.nameFromMimeType("image/png"), "image.png")
        XCTAssertEqual(DataPart.nameFromMimeType("application/pdf"), "file.pdf")
        XCTAssertEqual(DataPart.nameFromMimeType("unknown/type"), "file.bin")
    }

    func testExtensionFromMimeType() {
        XCTAssertEqual(DataPart.extensionFromMimeType("image/png"), "png")
        XCTAssertEqual(DataPart.extensionFromMimeType("application/pdf"), "pdf")
        XCTAssertNil(DataPart.extensionFromMimeType("unknown/type"))
    }

    func testDefaultMimeType() {
        XCTAssertEqual(DataPart.defaultMimeType, "application/octet-stream")
    }

    func testUsesDefaultMimeTypeWhenUnknown() {
        XCTAssertEqual(
            DataPart.mimeTypeForFile("unknown_file_no_extension"),
            DataPart.defaultMimeType
        )
    }

    func testFromJsonThrowsOnUnknownType() {
        let json: [String: Any?] = ["type": "Unknown", "content": ""]
        XCTAssertThrowsError(
            try partFromJson(json, converterRegistry: defaultPartConverterRegistry)
        ) { error in
            XCTAssertTrue(error is PartError)
            if case PartError.unknownType(let type) = error as! PartError {
                XCTAssertEqual(type, "Unknown")
            } else {
                XCTFail("Expected unknownType error")
            }
        }
    }

    // MARK: - TextPart

    func testTextPartCreation() {
        let part = StandardPart.text("hello world")
        if case .text(let text) = part {
            XCTAssertEqual(text, "hello world")
        } else {
            XCTFail("Expected text part")
        }
        XCTAssertTrue(part.description.contains("TextPart(hello world)"))
    }

    func testTextPartEquality() {
        let part1 = StandardPart.text("hello")
        let part2 = StandardPart.text("hello")
        let part3 = StandardPart.text("world")

        XCTAssertEqual(part1, part2)
        XCTAssertEqual(part1.hashValue, part2.hashValue)
        XCTAssertNotEqual(part1, part3)
    }

    func testTextPartJsonSerialization() throws {
        let part = StandardPart.text("hello")
        let json = part.toJson()
        XCTAssertEqual(json["type"] as? String, "Text")
        XCTAssertEqual(json["content"] as? String, "hello")

        let reconstructed = try partFromJson(
            json, converterRegistry: defaultPartConverterRegistry
        )
        XCTAssertTrue(reconstructed is StandardPart)
        if let sp = reconstructed as? StandardPart, case .text(let text) = sp {
            XCTAssertEqual(text, "hello")
        } else {
            XCTFail("Expected TextPart reconstruction")
        }
    }

    // MARK: - DataPart

    func testDataPartCreation() {
        let bytes = Data([1, 2, 3, 4])
        let part = StandardPart.data(DataPartContent(bytes: bytes, mimeType: "image/png", name: "test.png"))
        if case .data(let content) = part {
            XCTAssertEqual(content.bytes, bytes)
            XCTAssertEqual(content.mimeType, "image/png")
            XCTAssertEqual(content.name, "test.png")
        } else {
            XCTFail("Expected data part")
        }
    }

    func testDataPartEquality() {
        let bytes = Data([1, 2, 3, 4])
        let part1 = StandardPart.data(DataPartContent(bytes: bytes, mimeType: "image/png"))
        let part2 = StandardPart.data(DataPartContent(bytes: bytes, mimeType: "image/png"))
        let part3 = StandardPart.data(DataPartContent(bytes: bytes, mimeType: "image/jpeg"))

        XCTAssertEqual(part1, part2)
        XCTAssertEqual(part1.hashValue, part2.hashValue)
        XCTAssertNotEqual(part1, part3)
    }

    func testDataPartJsonSerialization() throws {
        let bytes = Data([1, 2, 3, 4])
        let part = StandardPart.data(DataPartContent(bytes: bytes, mimeType: "image/png", name: "test.png"))
        let json = part.toJson()

        XCTAssertEqual(json["type"] as? String, "Data")
        let content = json["content"] as! [String: Any?]
        XCTAssertEqual(content["mimeType"] as? String, "image/png")
        XCTAssertEqual(content["name"] as? String, "test.png")
        XCTAssertTrue((content["bytes"] as! String).hasPrefix("data:image/png;base64,"))

        let reconstructed = try partFromJson(
            json, converterRegistry: defaultPartConverterRegistry
        )
        XCTAssertTrue(reconstructed is StandardPart)
        if let sp = reconstructed as? StandardPart, case .data(let dc) = sp {
            XCTAssertEqual(dc.mimeType, "image/png")
            XCTAssertEqual(dc.name, "test.png")
            XCTAssertEqual(dc.bytes, bytes)
        } else {
            XCTFail("Expected DataPart reconstruction")
        }
    }

    // MARK: - LinkPart

    func testLinkPartCreation() {
        let url = URL(string: "https://example.com/image.png")!
        let part = StandardPart.link(LinkPartContent(url: url, mimeType: "image/png", name: "image.png"))
        if case .link(let content) = part {
            XCTAssertEqual(content.url, url)
            XCTAssertEqual(content.mimeType, "image/png")
            XCTAssertEqual(content.name, "image.png")
        } else {
            XCTFail("Expected link part")
        }
    }

    func testLinkPartEquality() {
        let url = URL(string: "https://example.com/image.png")!
        let part1 = StandardPart.link(LinkPartContent(url: url, mimeType: "image/png"))
        let part2 = StandardPart.link(LinkPartContent(url: url, mimeType: "image/png"))
        let part3 = StandardPart.link(LinkPartContent(url: URL(string: "https://other.com")!))

        XCTAssertEqual(part1, part2)
        XCTAssertEqual(part1.hashValue, part2.hashValue)
        XCTAssertNotEqual(part1, part3)
    }

    func testLinkPartJsonSerialization() throws {
        let url = URL(string: "https://example.com/image.png")!
        let part = StandardPart.link(LinkPartContent(url: url, mimeType: "image/png", name: "image"))
        let json = part.toJson()

        XCTAssertEqual(json["type"] as? String, "Link")
        let content = json["content"] as! [String: Any?]
        XCTAssertEqual(content["url"] as? String, url.absoluteString)
        XCTAssertEqual(content["mimeType"] as? String, "image/png")
        XCTAssertEqual(content["name"] as? String, "image")

        let reconstructed = try partFromJson(
            json, converterRegistry: defaultPartConverterRegistry
        )
        XCTAssertTrue(reconstructed is StandardPart)
        if let sp = reconstructed as? StandardPart, case .link(let lc) = sp {
            XCTAssertEqual(lc.url, url)
            XCTAssertEqual(lc.mimeType, "image/png")
            XCTAssertEqual(lc.name, "image")
        } else {
            XCTFail("Expected LinkPart reconstruction")
        }
    }

    // MARK: - ToolPart Call

    func testToolPartCallCreation() {
        let part = ToolPart.call(
            callId: "call_1",
            toolName: "get_weather",
            arguments: ["city": .string("London")]
        )
        if case .tool(let content) = part {
            XCTAssertEqual(content.kind, .call)
            XCTAssertEqual(content.callId, "call_1")
            XCTAssertEqual(content.toolName, "get_weather")
            XCTAssertEqual(content.arguments, ["city": .string("London")])
            XCTAssertNil(content.result)
            XCTAssertTrue(content.argumentsRaw.contains("\"city\""))
            XCTAssertTrue(content.argumentsRaw.contains("\"London\""))
        } else {
            XCTFail("Expected tool part")
        }
    }

    func testToolPartCallJsonSerialization() throws {
        let part = ToolPart.call(
            callId: "call_1",
            toolName: "get_weather",
            arguments: ["city": .string("London")]
        )
        let json = part.toJson()
        XCTAssertEqual(json["type"] as? String, "Tool")
        let content = json["content"] as! [String: Any?]
        XCTAssertEqual(content["id"] as? String, "call_1")
        XCTAssertEqual(content["name"] as? String, "get_weather")
        let args = content["arguments"] as? [String: Any]
        XCTAssertEqual(args?["city"] as? String, "London")

        let reconstructed = try partFromJson(
            json, converterRegistry: defaultPartConverterRegistry
        )
        XCTAssertTrue(reconstructed is StandardPart)
        if let sp = reconstructed as? StandardPart, case .tool(let tc) = sp {
            XCTAssertEqual(tc.kind, .call)
            XCTAssertEqual(tc.callId, "call_1")
            XCTAssertEqual(tc.arguments, ["city": .string("London")])
        } else {
            XCTFail("Expected ToolPart.call reconstruction")
        }
    }

    func testToolPartCallToString() {
        let part = ToolPart.call(
            callId: "c1",
            toolName: "t1",
            arguments: ["a": .int(1)]
        )
        let desc = part.description
        XCTAssertTrue(desc.contains("ToolPart.call"))
        XCTAssertTrue(desc.contains("c1"))
    }

    func testToolPartArgumentsRaw() {
        let part1 = ToolPart.call(callId: "c1", toolName: "t1", arguments: [:])
        if case .tool(let tc1) = part1 {
            XCTAssertEqual(tc1.argumentsRaw, "{}")
        }

        let part2 = ToolPart.call(callId: "c2", toolName: "t2", arguments: ["a": .int(1)])
        if case .tool(let tc2) = part2 {
            XCTAssertEqual(tc2.argumentsRaw, "{\"a\":1}")
        }
    }

    // MARK: - ToolPart Result

    func testToolPartResultCreation() {
        let part = ToolPart.result(
            callId: "call_1",
            toolName: "get_weather",
            result: .object(["temp": .int(20)])
        )
        if case .tool(let content) = part {
            XCTAssertEqual(content.kind, .result)
            XCTAssertEqual(content.callId, "call_1")
            XCTAssertEqual(content.toolName, "get_weather")
            XCTAssertEqual(content.result, .object(["temp": .int(20)]))
            XCTAssertNil(content.arguments)
            XCTAssertEqual(content.argumentsRaw, "")
        } else {
            XCTFail("Expected tool part")
        }
    }

    func testToolPartResultToString() {
        let part = ToolPart.result(
            callId: "c1",
            toolName: "t1",
            result: .string("ok")
        )
        let desc = part.description
        XCTAssertTrue(desc.contains("ToolPart.result"))
        XCTAssertTrue(desc.contains("c1"))
    }

    func testToolPartResultJsonSerialization() throws {
        let part = ToolPart.result(
            callId: "call_1",
            toolName: "get_weather",
            result: .object(["temp": .int(20)])
        )
        let json = part.toJson()
        XCTAssertEqual(json["type"] as? String, "Tool")
        let content = json["content"] as! [String: Any?]
        XCTAssertEqual(content["id"] as? String, "call_1")
        XCTAssertEqual(content["name"] as? String, "get_weather")
        let resultDict = content["result"] as? [String: Any]
        XCTAssertEqual(resultDict?["temp"] as? Int, 20)

        let reconstructed = try partFromJson(
            json, converterRegistry: defaultPartConverterRegistry
        )
        XCTAssertTrue(reconstructed is StandardPart)
        if let sp = reconstructed as? StandardPart, case .tool(let tc) = sp {
            XCTAssertEqual(tc.kind, .result)
            XCTAssertEqual(tc.callId, "call_1")
            XCTAssertEqual(tc.result, .object(["temp": .int(20)]))
        } else {
            XCTFail("Expected ToolPart.result reconstruction")
        }
    }

    // MARK: - Message

    func testMessageFromParts() {
        let msg = ChatMessage(
            role: .user,
            parts: [.text("hello")]
        )
        XCTAssertEqual(msg.text, "hello")
    }

    // MARK: - Named constructors

    func testMessageSystem() {
        let message = ChatMessage.system(
            "instruction",
            parts: [.text(" extra")],
            metadata: ["a": .int(1)]
        )
        XCTAssertEqual(message.role, .system)
        XCTAssertEqual(message.text, "instruction extra")
        if case .text(let t) = message.parts.first {
            XCTAssertEqual(t, "instruction")
        } else {
            XCTFail("Expected TextPart")
        }
        if case .text(let t) = message.parts[1] {
            XCTAssertEqual(t, " extra")
        } else {
            XCTFail("Expected TextPart")
        }
        XCTAssertEqual(message.metadata, ["a": .int(1)])
    }

    func testMessageUser() {
        let message = ChatMessage.user(
            "hello",
            parts: [.text(" world")],
            metadata: ["b": .int(2)]
        )
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.text, "hello world")
        if case .text(let t) = message.parts.first {
            XCTAssertEqual(t, "hello")
        } else {
            XCTFail("Expected TextPart")
        }
        XCTAssertEqual(message.metadata, ["b": .int(2)])
    }

    func testMessageModel() {
        let message = ChatMessage.model(
            "response",
            parts: [
                ToolPart.call(callId: "id", toolName: "t", arguments: [:]),
            ],
            metadata: ["c": .int(3)]
        )
        XCTAssertEqual(message.role, .model)
        XCTAssertEqual(message.text, "response")
        if case .text(let t) = message.parts.first {
            XCTAssertEqual(t, "response")
        } else {
            XCTFail("Expected TextPart")
        }
        if case .tool = message.parts[1] {
            // ok
        } else {
            XCTFail("Expected ToolPart")
        }
        XCTAssertEqual(message.metadata, ["c": .int(3)])
    }

    func testMessageDefaultConstructor() {
        let message = ChatMessage.system("instructions")
        XCTAssertEqual(message.text, "instructions")
    }

    func testMessageHelpers() {
        let toolCall = ToolPart.call(
            callId: "1",
            toolName: "tool",
            arguments: [:]
        )
        let toolResult = ToolPart.result(
            callId: "1",
            toolName: "tool",
            result: .string("ok")
        )

        let msg1 = ChatMessage(
            role: .model,
            parts: [.text("Hi"), toolCall]
        )
        XCTAssertTrue(msg1.hasToolCalls)
        XCTAssertFalse(msg1.hasToolResults)
        XCTAssertEqual(msg1.toolCalls.count, 1)
        XCTAssertTrue(msg1.toolResults.isEmpty)
        XCTAssertEqual(msg1.text, "Hi")

        let msg2 = ChatMessage(role: .user, parts: [toolResult])
        XCTAssertFalse(msg2.hasToolCalls)
        XCTAssertTrue(msg2.hasToolResults)
        XCTAssertTrue(msg2.toolCalls.isEmpty)
        XCTAssertEqual(msg2.toolResults.count, 1)
    }

    func testMessageMetadata() throws {
        let msg = ChatMessage(
            role: .user,
            parts: [.text("hi")],
            metadata: ["key": .string("value")]
        )
        XCTAssertEqual(msg.metadata["key"], .string("value"))

        let json = msg.toJson()
        let metaDict = json["metadata"] as? [String: Any]
        XCTAssertEqual(metaDict?["key"] as? String, "value")

        let reconstructed = try ChatMessage.fromJson(json)
        XCTAssertEqual(reconstructed.metadata, ["key": .string("value")])
    }

    func testMessageJsonSerialization() throws {
        let msg = ChatMessage.model("response")
        let json = msg.toJson()

        let parts = json["parts"] as? [Any?]
        XCTAssertEqual(parts?.count, 1)

        let reconstructed = try ChatMessage.fromJson(json)
        XCTAssertEqual(reconstructed, msg)
    }

    func testMixedContentJsonRoundTrip() throws {
        let msg = ChatMessage(
            role: .model,
            parts: [
                .text("text"),
                ToolPart.call(
                    callId: "id",
                    toolName: "name",
                    arguments: ["a": .int(1)]
                ),
                ToolPart.result(
                    callId: "id",
                    toolName: "name",
                    result: .object(["success": .bool(true)])
                ),
            ]
        )

        let json = msg.toJson()
        let reconstructed = try ChatMessage.fromJson(json)

        XCTAssertEqual(reconstructed, msg)
        XCTAssertEqual(reconstructed.parts.count, 3)
        if case .text = reconstructed.parts[0] { } else { XCTFail("Expected TextPart") }
        if case .tool = reconstructed.parts[1] { } else { XCTFail("Expected ToolPart") }
        if case .tool = reconstructed.parts[2] { } else { XCTFail("Expected ToolPart") }
    }

    func testMessageEqualityAndHashCode() {
        let msg1 = ChatMessage(
            role: .user,
            parts: [.text("hi")],
            metadata: ["k": .string("v")]
        )
        let msg2 = ChatMessage(
            role: .user,
            parts: [.text("hi")],
            metadata: ["k": .string("v")]
        )
        let msg3 = ChatMessage(
            role: .user,
            parts: [.text("hello")]
        )
        let msg4 = ChatMessage(
            role: .user,
            parts: [.text("hi")],
            metadata: ["k": .string("other")]
        )

        XCTAssertEqual(msg1, msg2)
        XCTAssertEqual(msg1.hashValue, msg2.hashValue)
        XCTAssertNotEqual(msg1, msg3)
        XCTAssertNotEqual(msg1, msg4)
    }

    func testTextConcatenation() {
        let msg = ChatMessage(
            role: .model,
            parts: [
                .text("Part 1. "),
                ToolPart.call(callId: "1", toolName: "t", arguments: [:]),
                .text("Part 2."),
            ]
        )
        XCTAssertEqual(msg.text, "Part 1. Part 2.")
    }

    func testMessageToString() {
        let msg = ChatMessage.user("hi")
        XCTAssertTrue(msg.description.contains("Message"))
        XCTAssertTrue(msg.description.contains("TextPart(hi)"))
    }

    // MARK: - concatenate

    func testConcatenateCombinesParts() throws {
        let a = ChatMessage.model("hello ")
        let b = ChatMessage.model("world")
        let result = try a.concatenate(b)
        XCTAssertEqual(result.parts.count, 2)
        XCTAssertEqual(result.text, "hello world")
    }

    func testConcatenateFallsBackToSecondFinishStatus() throws {
        let a = ChatMessage(role: .model)
        let b = ChatMessage(
            role: .model,
            finishStatus: .completed()
        )
        let result = try a.concatenate(b)
        XCTAssertEqual(result.finishStatus, .completed())
    }

    func testConcatenateFinishStatusBothNull() throws {
        let a = ChatMessage(role: .model)
        let b = ChatMessage(role: .model)
        let result = try a.concatenate(b)
        XCTAssertNil(result.finishStatus)
    }

    func testConcatenateSameFinishStatusPreserved() throws {
        let a = ChatMessage(
            role: .model,
            finishStatus: .completed()
        )
        let b = ChatMessage(
            role: .model,
            finishStatus: .completed()
        )
        let result = try a.concatenate(b)
        XCTAssertEqual(result.finishStatus, .completed())
    }

    func testConcatenateEqualMetadataPreserved() throws {
        let a = ChatMessage(
            role: .model,
            metadata: ["k": .string("v")]
        )
        let b = ChatMessage(
            role: .model,
            metadata: ["k": .string("v")]
        )
        let result = try a.concatenate(b)
        XCTAssertEqual(result.metadata, ["k": .string("v")])
    }

    func testConcatenatePreservesNonTextParts() throws {
        let toolCall = ToolPart.call(
            callId: "c1",
            toolName: "t1",
            arguments: [:]
        )
        let toolResult = ToolPart.result(
            callId: "c1",
            toolName: "t1",
            result: .string("ok")
        )
        let a = ChatMessage(
            role: .model,
            parts: [.text("text"), toolCall]
        )
        let b = ChatMessage(role: .model, parts: [toolResult])
        let result = try a.concatenate(b)
        XCTAssertEqual(result.parts.count, 3)
        if case .text = result.parts[0] { } else { XCTFail("Expected TextPart") }
        if case .tool = result.parts[1] { } else { XCTFail("Expected ToolPart") }
        if case .tool = result.parts[2] { } else { XCTFail("Expected ToolPart") }
    }

    func testConcatenateThrowsOnRoleMismatch() {
        let a = ChatMessage.user("hi")
        let b = ChatMessage.model("there")
        XCTAssertThrowsError(try a.concatenate(b)) { error in
            XCTAssertTrue(error is ChatMessageError)
        }
    }

    func testConcatenateThrowsOnConflictingFinishStatuses() {
        let a = ChatMessage(
            role: .model,
            finishStatus: .completed()
        )
        let b = ChatMessage(
            role: .model,
            finishStatus: .notFinished()
        )
        XCTAssertThrowsError(try a.concatenate(b)) { error in
            XCTAssertTrue(error is ChatMessageError)
        }
    }

    func testConcatenateThrowsWhenMetadataValuesDiffer() {
        let a = ChatMessage(
            role: .model,
            metadata: ["key": .string("from-a")]
        )
        let b = ChatMessage(
            role: .model,
            metadata: ["key": .string("from-b")]
        )
        XCTAssertThrowsError(try a.concatenate(b)) { error in
            XCTAssertTrue(error is ChatMessageError)
        }
    }

    func testConcatenateThrowsWhenMetadataHaveDifferentKeys() {
        let a = ChatMessage(
            role: .model,
            metadata: ["only-a": .int(1)]
        )
        let b = ChatMessage(
            role: .model,
            metadata: ["only-b": .int(2)]
        )
        XCTAssertThrowsError(try a.concatenate(b)) { error in
            XCTAssertTrue(error is ChatMessageError)
        }
    }

    // MARK: - copyWith

    func testCopyWithNoArguments() {
        let original = ChatMessage(
            role: .user,
            parts: [.text("hello")],
            metadata: ["k": .string("v")],
            finishStatus: .completed()
        )
        XCTAssertEqual(original.copyWith(), original)
    }

    func testCopyWithReplacesRole() {
        let original = ChatMessage(
            role: .user,
            parts: [.text("hello")],
            metadata: ["k": .string("v")],
            finishStatus: .completed()
        )
        let result = original.copyWith(role: .model)
        XCTAssertEqual(result.role, .model)
        XCTAssertEqual(result.parts, original.parts)
        XCTAssertEqual(result.metadata, original.metadata)
        XCTAssertEqual(result.finishStatus, original.finishStatus)
    }

    func testCopyWithReplacesParts() {
        let original = ChatMessage(
            role: .user,
            parts: [.text("hello")],
            metadata: ["k": .string("v")],
            finishStatus: .completed()
        )
        let newParts: [StandardPart] = [.text("world")]
        let result = original.copyWith(parts: newParts)
        XCTAssertEqual(result.parts, newParts)
        XCTAssertEqual(result.role, original.role)
        XCTAssertEqual(result.metadata, original.metadata)
        XCTAssertEqual(result.finishStatus, original.finishStatus)
    }

    func testCopyWithReplacesMetadata() {
        let original = ChatMessage(
            role: .user,
            parts: [.text("hello")],
            metadata: ["k": .string("v")],
            finishStatus: .completed()
        )
        let result = original.copyWith(metadata: ["x": .int(1)])
        XCTAssertEqual(result.metadata, ["x": .int(1)])
        XCTAssertEqual(result.role, original.role)
        XCTAssertEqual(result.parts, original.parts)
        XCTAssertEqual(result.finishStatus, original.finishStatus)
    }

    func testCopyWithReplacesFinishStatus() {
        let original = ChatMessage(
            role: .user,
            parts: [.text("hello")],
            metadata: ["k": .string("v")],
            finishStatus: .completed()
        )
        let result = original.copyWith(finishStatus: .notFinished())
        XCTAssertEqual(result.finishStatus, .notFinished())
        XCTAssertEqual(result.role, original.role)
        XCTAssertEqual(result.parts, original.parts)
        XCTAssertEqual(result.metadata, original.metadata)
    }

    func testCopyWithReplacesMultipleFields() {
        let original = ChatMessage(
            role: .user,
            parts: [.text("hello")],
            metadata: ["k": .string("v")],
            finishStatus: .completed()
        )
        let result = original.copyWith(
            role: .model,
            parts: [.text("new")]
        )
        XCTAssertEqual(result.role, .model)
        XCTAssertEqual(result.parts, [.text("new")])
        XCTAssertEqual(result.metadata, original.metadata)
        XCTAssertEqual(result.finishStatus, original.finishStatus)
    }

    // MARK: - Parts

    func testPartsFromText() {
        let parts = Parts.fromText(
            "Hello",
            parts: [ToolPart.call(callId: "c1", toolName: "t1", arguments: [:])]
        )
        XCTAssertEqual(parts.count, 2)
        if case .text(let t) = parts.first {
            XCTAssertEqual(t, "Hello")
        } else {
            XCTFail("Expected TextPart")
        }
        if case .tool = parts.last {
            // ok
        } else {
            XCTFail("Expected ToolPart")
        }
    }

    func testPartsFromTextWithEmptyText() {
        let parts = Parts.fromText(
            "",
            parts: [ToolPart.call(callId: "c1", toolName: "t1", arguments: [:])]
        )
        XCTAssertEqual(parts.count, 1)
        if case .tool = parts.first {
            // ok
        } else {
            XCTFail("Expected ToolPart")
        }
    }

    func testPartsHelpers() {
        let parts = Parts([
            .text("Hello"),
            ToolPart.call(callId: "c1", toolName: "t1", arguments: [:]),
            ToolPart.result(callId: "c2", toolName: "t2", result: .string("r")),
        ])

        XCTAssertEqual(parts.toolResults.count, 1)
        XCTAssertEqual(parts.toolResults.first?.callId, "c2")
    }

    func testPartsEquality() {
        let parts1 = Parts([.text("a"), .text("b")])
        let parts2 = Parts([.text("a"), .text("b")])
        let parts3 = Parts([.text("a")])

        XCTAssertEqual(parts1, parts2)
        XCTAssertEqual(parts1.hashValue, parts2.hashValue)
        XCTAssertNotEqual(parts1, parts3)
    }

    func testPartsJsonSerialization() throws {
        let parts = Parts([
            .text("text"),
            ToolPart.call(callId: "1", toolName: "t", arguments: [:]),
        ])

        let json = parts.toJson()
        XCTAssertEqual(json.count, 2)

        let reconstructed = try Parts.fromJson(json)
        XCTAssertEqual(reconstructed, parts)
        if case .text = reconstructed.first {
            // ok
        } else {
            XCTFail("Expected TextPart")
        }
        if case .tool = reconstructed.last {
            // ok
        } else {
            XCTFail("Expected ToolPart")
        }
    }

    // MARK: - ToolDefinition

    func testToolDefinitionCreationAndSerialization() throws {
        let tool = ToolDefinition(
            name: "test",
            description: "desc",
            inputSchema: [
                "type": "object",
                "properties": [
                    "loc": [
                        "type": "string",
                        "description": "Location",
                    ] as [String: Any],
                ] as [String: Any],
            ]
        )

        let json = tool.toJson()
        XCTAssertEqual(json["name"] as? String, "test")
        XCTAssertEqual(json["description"] as? String, "desc")
        XCTAssertNotNil(json["inputSchema"] as Any?)

        let reconstructed = try ToolDefinition.fromJson(json)
        XCTAssertEqual(reconstructed.name, "test")
        XCTAssertEqual(reconstructed.description, "desc")
    }

    // MARK: - FinishStatus

    func testFinishStatusEquality() {
        let status1 = FinishStatus.completed()
        let status2 = FinishStatus.completed()
        let status3 = FinishStatus.notFinished()
        let status4 = FinishStatus.interrupted(details: "reason")
        let status5 = FinishStatus.interrupted(details: "reason")
        let status6 = FinishStatus.interrupted(details: "other")

        XCTAssertEqual(status1, status2)
        XCTAssertEqual(status1.hashValue, status2.hashValue)
        XCTAssertNotEqual(status1, status3)
        XCTAssertEqual(status4, status5)
        XCTAssertEqual(status4.hashValue, status5.hashValue)
        XCTAssertNotEqual(status4, status6)
    }

    func testFinishStatusJsonSerialization() throws {
        let status1 = FinishStatus.completed()
        XCTAssertEqual(try FinishStatus.fromJson(status1.toJson()), status1)

        let status2 = FinishStatus.interrupted(details: "reason")
        XCTAssertEqual(try FinishStatus.fromJson(status2.toJson()), status2)
    }

    // MARK: - ChatMessage Extended

    func testFinishStatusSerialization() throws {
        let msg = ChatMessage(
            role: .model,
            finishStatus: .completed()
        )
        let json = msg.toJson()
        XCTAssertNotNil(json["finishStatus"] as Any?)

        let reconstructed = try ChatMessage.fromJson(json)
        XCTAssertEqual(reconstructed.finishStatus, .completed())
    }

    func testRoleAndFinishStatusEquality() {
        let msg1 = ChatMessage(
            role: .user,
            finishStatus: .completed()
        )
        let msg2 = ChatMessage(
            role: .user,
            finishStatus: .completed()
        )
        let msg3 = ChatMessage(
            role: .model, // Different role
            finishStatus: .completed()
        )
        let msg4 = ChatMessage(
            role: .user,
            finishStatus: .notFinished() // Different status
        )

        XCTAssertEqual(msg1, msg2)
        XCTAssertEqual(msg1.hashValue, msg2.hashValue)
        XCTAssertNotEqual(msg1, msg3) // Role checking verified
        XCTAssertNotEqual(msg1, msg4) // FinishStatus checking verified
    }
}
