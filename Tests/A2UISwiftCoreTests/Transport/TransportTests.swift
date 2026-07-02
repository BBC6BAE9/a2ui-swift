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

// MARK: - Test helpers

/// Actor-based event collector for safe concurrent test usage.
private actor EventCollector {
    private(set) var events: [ParsedEvent] = []
    func append(_ event: ParsedEvent) { events.append(event) }
}

/// Actor-based string collector.
private actor TextCollector {
    private(set) var items: [String] = []
    func append(_ s: String) { items.append(s) }
}

/// Actor-based message collector.
private actor MessageCollector {
    private(set) var items: [A2uiMessage] = []
    func append(_ m: A2uiMessage) { items.append(m) }
}

/// Actor-based single-value box for testing callbacks.
private actor ReceivedBox {
    private(set) var value: ChatMessage?
    func set(_ msg: ChatMessage) { value = msg }
}

/// Collects all `ParsedEvent`s emitted by `A2UIStreamParser` for the given chunks.
private func parseChunks(_ chunks: [String]) async -> [ParsedEvent] {
    let parser    = A2UIStreamParser()
    let collector = EventCollector()

    // Subscribe before feeding data so no early events are missed.
    let task = Task {
        for await event in parser.events {
            await collector.append(event)
        }
    }

    for chunk in chunks {
        await parser.add(chunk)
    }
    await parser.finish()
    await task.value
    return await collector.events
}

/// Convenience: parse a single string in one chunk.
private func parse(_ input: String) async -> [ParsedEvent] {
    await parseChunks([input])
}

/// Result of feeding chunks and direct messages to an `A2UITransportAdapter`.
private struct AdapterResult {
    let texts:    [String]
    let messages: [A2uiMessage]
}

/// Feeds chunks and direct messages to `adapter`, waits for both streams to complete,
/// and returns the collected texts and messages.
/// Mirrors the two-stream structure of Flutter `A2uiTransportAdapter`.
private func collectAdapter(
    _ adapter: A2UITransportAdapter,
    chunks: [String] = [],
    direct: [A2uiMessage] = []
) async -> AdapterResult {
    let texts    = TextCollector()
    let messages = MessageCollector()

    let textTask = Task {
        for await t in adapter.incomingText    { await texts.append(t) }
    }
    let msgTask  = Task {
        for await m in adapter.incomingMessages { await messages.append(m) }
    }

    for chunk in chunks { await adapter.addChunk(chunk) }
    for msg   in direct { adapter.addMessage(msg) }
    await adapter.finish()

    await textTask.value
    await msgTask.value

    return AdapterResult(
        texts:    await texts.items,
        messages: await messages.items
    )
}

/// A minimal valid `createSurface` JSON — always a legal A2UI message.
private let createSurfaceJSON = """
{"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"basic","sendDataModel":false}}
"""

// MARK: - A2UIStreamParserTests

@Suite("A2UIStreamParser")
struct A2UIStreamParserTests {

    // MARK: Single complete message

    @Test("Single complete JSON message in one chunk")
    func singleCompleteMessage() async {
        let events = await parse(createSurfaceJSON)
        #expect(events.count == 1)
        if case .message(let msg) = events[0],
           case .createSurface(let p) = msg {
            #expect(p.surfaceId == "s1")
            #expect(p.catalogId == "basic")
        } else {
            Issue.record("Expected .message(.createSurface), got \(events)")
        }
    }

    // MARK: JSON split across chunks

    @Test("JSON message split across two chunks")
    func messageSplitAcrossChunks() async {
        let mid   = createSurfaceJSON.count / 2
        let part1 = String(createSurfaceJSON.prefix(mid))
        let part2 = String(createSurfaceJSON.suffix(createSurfaceJSON.count - mid))

        let events   = await parseChunks([part1, part2])
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }
        #expect(messages.count == 1)
        if case .createSurface(let p) = messages.first {
            #expect(p.surfaceId == "s1")
        }
    }

    @Test("JSON message split across many single-character chunks")
    func messageSingleCharChunks() async {
        let chunks   = createSurfaceJSON.map { String($0) }
        let events   = await parseChunks(chunks)
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }
        #expect(messages.count == 1)
    }

    // MARK: Mixed text + message

    @Test("A2UI message mixed in plain text")
    func messageMixedInText() async {
        let input    = "Hello! \(createSurfaceJSON) Goodbye!"
        let events   = await parse(input)
        let texts    = events.compactMap { if case .text(let t) = $0 { t } else { nil } }
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }

        #expect(messages.count == 1)
        let allText = texts.joined()
        #expect(allText.contains("Hello!"))
        #expect(allText.contains("Goodbye!"))
    }

    // MARK: Markdown JSON block format

    @Test("Markdown JSON block (```json ... ```) is parsed as A2UI message")
    func markdownJsonBlock() async {
        let input = """
        Here is the UI:
        ```json
        \(createSurfaceJSON)
        ```
        Done.
        """
        let events   = await parse(input)
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }
        #expect(messages.count == 1)
        if case .createSurface(let p) = messages.first {
            #expect(p.surfaceId == "s1")
        }
    }

    @Test("Markdown block without language tag is also parsed")
    func markdownBlockNoLang() async {
        let input = """
        ```
        \(createSurfaceJSON)
        ```
        """
        let events   = await parse(input)
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }
        #expect(messages.count == 1)
    }

    // MARK: Multiple consecutive messages

    @Test("Two A2UI messages back-to-back")
    func twoConsecutiveMessages() async {
        let updateJSON = """
        {"version":"v0.9","updateDataModel":{"surfaceId":"s1","path":"/name","value":"Alice"}}
        """
        let input    = createSurfaceJSON + "\n" + updateJSON
        let events   = await parse(input)
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }
        #expect(messages.count == 2)
    }

    // MARK: Non-A2UI JSON → text

    @Test("Non-A2UI JSON object is emitted as text, not as a message")
    func nonA2uiJsonEmittedAsText() async {
        let input    = """
        {"foo":"bar","count":42}
        """
        let events   = await parse(input)
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }
        let texts    = events.compactMap { if case .text(let t) = $0 { t } else { nil } }
        #expect(messages.isEmpty)
        #expect(!texts.isEmpty)
    }

    // MARK: Invalid JSON → no stall

    @Test("Malformed JSON does not stall the parser")
    func malformedJsonNoStall() async {
        let input  = "Some text {broken json: true,} more text"
        let events = await parse(input)
        let texts  = events.compactMap { if case .text(let t) = $0 { t } else { nil } }
        let combined = texts.joined()
        #expect(combined.contains("Some text"))
        #expect(combined.contains("more text"))
    }

    // MARK: <a2ui-json> tag delimiter

    @Test("<a2ui-json> tags are stripped; inner JSON is parsed as a message")
    func a2uiJsonTagsStrippedFromText() async {
        let input    = "<a2ui-json>[\(createSurfaceJSON)]</a2ui-json>"
        let events   = await parse(input)
        let texts    = events.compactMap { if case .text(let t) = $0 { t } else { nil } }
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }
        #expect(!texts.joined().contains("<a2ui-json>"))
        #expect(!texts.joined().contains("</a2ui-json>"))
        #expect(messages.count == 1)
    }

    @Test("Conversational text outside <a2ui-json> is emitted as text, inside is parsed")
    func interleavedConversationalText() async {
        // Mirrors upstream test_interleaved_conversational_text.
        let events = await parseChunks([
            "Here is your UI: <a2ui-json>",
            "[\(createSurfaceJSON)]",
            "</a2ui-json> That's all!",
        ])
        let texts    = events.compactMap { if case .text(let t) = $0 { t } else { nil } }
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }

        #expect(messages.count == 1)
        let allText = texts.joined()
        #expect(allText.contains("Here is your UI:"))
        #expect(allText.contains("That's all!"))
        // The tag literals must never leak into the text stream.
        #expect(!allText.contains("<a2ui-json>"))
        #expect(!allText.contains("</a2ui-json>"))
    }

    @Test("Open tag split across chunks is buffered, not emitted as text")
    func splitTagHandlingForText() async {
        // Mirrors upstream test_split_tag_handling_for_text:
        // "Talking <a2u" + "i-json>" must hold back the partial tag.
        let events = await parseChunks([
            "Talking <a2u",
            "i-json>",
            "[\(createSurfaceJSON)]</a2ui-json> End.",
        ])
        let texts    = events.compactMap { if case .text(let t) = $0 { t } else { nil } }
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }

        #expect(messages.count == 1)
        let allText = texts.joined()
        #expect(allText.contains("Talking "))
        #expect(allText.contains("End."))
        // The partial tag prefix must not appear as conversational text.
        #expect(!allText.contains("<a2u"))
        #expect(!allText.contains("<a2ui-json>"))
        #expect(!allText.contains("</a2ui-json>"))
    }

    @Test("Multiple <a2ui-json> blocks interleaved with text")
    func multipleA2uiBlocks() async {
        // Mirrors upstream test_multiple_a2ui_blocks.
        let updateJSON = """
        {"version":"v0.9","updateDataModel":{"surfaceId":"s1","path":"/name","value":"Alice"}}
        """
        let input = "Some text here <a2ui-json>[\(createSurfaceJSON)]</a2ui-json>"
            + " mid text <a2ui-json>[\(updateJSON)]</a2ui-json> trailing text"
        let events   = await parse(input)
        let texts    = events.compactMap { if case .text(let t) = $0 { t } else { nil } }
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }

        #expect(messages.count == 2)
        let allText = texts.joined()
        #expect(allText.contains("Some text here"))
        #expect(allText.contains("mid text"))
        #expect(allText.contains("trailing text"))
        #expect(!allText.contains("<a2ui-json>"))
        #expect(!allText.contains("</a2ui-json>"))
    }

    @Test("Untagged markdown/bare JSON still parses (structure fallback)")
    func untaggedStructureFallbackStillWorks() async {
        // No <a2ui-json> tag present — the structural fallback must still parse.
        let events   = await parse("Intro \(createSurfaceJSON) outro")
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }
        #expect(messages.count == 1)
    }

    @Test("A held-back partial open tag that turns out to be plain text is flushed on finish()")
    func partialOpenTagThatIsActuallyText() async {
        // "<a2u" looks like the start of <a2ui-json> and is buffered, but the stream ends
        // without completing the tag — finish() must surface it as plain text, not drop it.
        let events   = await parse("Talking about <a2u")
        let texts    = events.compactMap { if case .text(let t) = $0 { t } else { nil } }
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }
        #expect(messages.isEmpty)
        #expect(texts.joined() == "Talking about <a2u")
    }

    @Test("A partial-tag prefix followed by non-tag text is emitted as text")
    func partialTagPrefixResolvedAsText() async {
        // First chunk holds back "<a2u"; the next chunk reveals it was not a tag.
        let events   = await parseChunks(["Talking <a2u", "tomic stuff"])
        let texts    = events.compactMap { if case .text(let t) = $0 { t } else { nil } }
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }
        #expect(messages.isEmpty)
        #expect(texts.joined() == "Talking <a2utomic stuff")
    }

    // MARK: finish() flushes remaining buffer

    @Test("finish() flushes remaining plain text in buffer")
    func finishFlushesBuffer() async {
        let events = await parse("Hello, world!")
        let texts  = events.compactMap { if case .text(let t) = $0 { t } else { nil } }
        #expect(texts.joined().contains("Hello, world!"))
    }

    @Test("finish() with empty buffer produces no events")
    func finishWithEmptyBuffer() async {
        let events = await parseChunks([])
        #expect(events.isEmpty)
    }

    // MARK: updateComponents

    @Test("updateComponents message is parsed correctly")
    func updateComponents() async {
        let json = """
        {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[{"id":"btn1","component":"Button","label":"Click me"}]}}
        """
        let events   = await parse(json)
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }
        #expect(messages.count == 1)
        if case .updateComponents(let p) = messages.first {
            #expect(p.surfaceId == "s1")
            #expect(p.components.count == 1)
            #expect(p.components[0].id == "btn1")
        } else {
            Issue.record("Expected .updateComponents")
        }
    }

    // MARK: deleteSurface

    @Test("deleteSurface message is parsed correctly")
    func deleteSurface() async {
        let json = """
        {"version":"v0.9","deleteSurface":{"surfaceId":"s1"}}
        """
        let events   = await parse(json)
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }
        #expect(messages.count == 1)
        if case .deleteSurface(let p) = messages.first {
            #expect(p.surfaceId == "s1")
        } else {
            Issue.record("Expected .deleteSurface")
        }
    }

    // MARK: Validation error propagation

    @Test("A2UI JSON with invalid field type emits .error, not .text or .message")
    func validationErrorEmittedAsError() async {
        // surfaceId must be a String; passing a Number triggers A2uiValidationError
        let json = """
        {"version":"v0.9","createSurface":{"surfaceId":123,"catalogId":"basic","sendDataModel":false}}
        """
        let events = await parse(json)
        let errors   = events.compactMap { if case .error(let e) = $0 { e } else { nil } }
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }
        #expect(errors.count == 1,   "Expected exactly one .error event")
        #expect(messages.isEmpty,    "Should not produce a .message event")
    }

    @Test("Stream continues producing events after a .error event")
    func streamContinuesAfterError() async {
        // First message: invalid (surfaceId is a number)
        let badJSON  = """
        {"version":"v0.9","createSurface":{"surfaceId":999,"catalogId":"basic","sendDataModel":false}}
        """
        // Second message: valid
        let goodJSON = createSurfaceJSON
        let events   = await parse(badJSON + "\n" + goodJSON)
        let errors   = events.compactMap { if case .error(let e) = $0 { e } else { nil } }
        let messages = events.compactMap { if case .message(let m) = $0 { m } else { nil } }
        #expect(errors.count   == 1, "Expected one .error from the invalid message")
        #expect(messages.count == 1, "Expected one .message from the valid message — stream must continue")
    }
}

// MARK: - A2UITransportAdapterTests

@Suite("A2UITransportAdapter")
struct A2UITransportAdapterTests {

    @Test("addChunk routes parsed A2UI messages through incomingMessages")
    func addChunkRoutesMessages() async {
        let adapter = A2UITransportAdapter()
        let result  = await collectAdapter(adapter, chunks: [createSurfaceJSON])
        #expect(result.messages.count == 1)
        if case .createSurface(let p) = result.messages.first {
            #expect(p.surfaceId == "s1")
        } else {
            Issue.record("Expected .createSurface")
        }
    }

    @Test("addMessage injects A2uiMessage directly into incomingMessages")
    func addMessageInjectsDirect() async {
        let adapter = A2UITransportAdapter()
        let msg     = A2uiMessage.deleteSurface(DeleteSurfacePayload(surfaceId: "x"))
        let result  = await collectAdapter(adapter, direct: [msg])
        #expect(result.messages.count == 1)
        if case .deleteSurface(let p) = result.messages.first {
            #expect(p.surfaceId == "x")
        } else {
            Issue.record("Expected .deleteSurface")
        }
    }

    @Test("sendRequest calls onSend callback with the correct ChatMessage")
    func sendRequestCallsCallback() async throws {
        let box     = ReceivedBox()
        let adapter = A2UITransportAdapter { message in
            await box.set(message)
        }
        try await adapter.sendRequest(ChatMessage(role: "user", content: "Hello"))
        let received = await box.value
        #expect(received?.role == "user")
        #expect(received?.content == "Hello")
    }

    @Test("sendRequest throws A2UITransportError.noSendCallback when no callback provided")
    func sendRequestThrowsWithoutCallback() async {
        let adapter = A2UITransportAdapter()
        await #expect(throws: A2UITransportError.noSendCallback) {
            try await adapter.sendRequest(ChatMessage(role: "user", content: "Hi"))
        }
    }

    @Test("Plain text chunks appear in incomingText, trimmed and non-empty")
    func plainTextAppearsInIncomingText() async {
        let adapter = A2UITransportAdapter()
        let result  = await collectAdapter(adapter, chunks: ["  Hello there  "])
        #expect(result.texts.joined().contains("Hello there"))
        // Trimming: leading/trailing whitespace must be stripped
        for t in result.texts { #expect(t == t.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    @Test("Whitespace-only text is not emitted in incomingText")
    func whitespaceOnlyTextNotEmitted() async {
        let adapter = A2UITransportAdapter()
        // A JSON message surrounded only by newlines — the surrounding whitespace should be suppressed
        let result  = await collectAdapter(adapter, chunks: ["\n\n" + createSurfaceJSON + "\n\n"])
        #expect(result.messages.count == 1)
        // All emitted text items must be non-empty after trimming (they should already be trimmed)
        for t in result.texts { #expect(!t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
    }

    @Test("incomingText and incomingMessages are independent — each has the right content")
    func streamsAreIndependent() async {
        let adapter = A2UITransportAdapter()
        let input   = "Before \(createSurfaceJSON) After"
        let result  = await collectAdapter(adapter, chunks: [input])
        #expect(result.messages.count == 1)
        let allText = result.texts.joined()
        #expect(allText.contains("Before"))
        #expect(allText.contains("After"))
    }
}


// MARK: - ChatMessageTests

@Suite("ChatMessage")
struct ChatMessageTests {

    @Test("ChatMessage encodes and decodes via Codable correctly")
    func codableRoundTrip() throws {
        let original = ChatMessage(role: "user", content: "What is 2+2?")
        let data     = try JSONEncoder().encode(original)
        let decoded  = try JSONDecoder().decode(ChatMessage.self, from: data)
        #expect(decoded.role == original.role)
        #expect(decoded.content == original.content)
    }

    @Test("ChatMessage conforms to Equatable")
    func equatable() {
        let a = ChatMessage(role: "user",      content: "Hi")
        let b = ChatMessage(role: "user",      content: "Hi")
        let c = ChatMessage(role: "assistant", content: "Hi")
        #expect(a == b)
        #expect(a != c)
    }
}
