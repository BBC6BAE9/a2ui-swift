// Tests/A2UIConformanceTests/ConformanceHarness.swift
import Foundation
import XCTest
@testable import A2UISwiftCore

// MARK: - Agent-only actions (XCTSkip these)

private let agentOnlyActions: Set<String> = [
    "generate_prompt", "select_catalog", "handle_rpc", "execute_tool",
    "create_a2ui_part", "is_a2ui_part", "try_activate", "try_activate_extension",
    "get_extension", "convert_event", "select_newest", "verify_cuttable_keys",
    "render", "remove_strict_validation", "has_parts", "load_catalog",
    "prune", "load"
]

func skipAgentOnlyAction(_ action: String, testName: String) throws {
    if agentOnlyActions.contains(action) {
        throw XCTSkip("N/A for renderer: action '\(action)' is agent-side only (test: \(testName))")
    }
}

// MARK: - v0.8 cases (skip these)

/// `main` targets the v0.9.1 spec, whose server-to-client vocabulary is
/// `createSurface` / `updateComponents` / `updateDataModel` / `deleteSurface`.
/// The v0.8 spec uses a different vocabulary (`beginRendering` / `surfaceUpdate` /
/// `dataModelUpdate`) that this renderer intentionally does not speak, so v0.8
/// conformance cases are not applicable here.
///
/// Returns `true` when the case is v0.8 and should be skipped. Callers should
/// `continue` past the case rather than `throw`, so that the remaining v0.9
/// cases in the same suite still run (each suite executes all of its cases in a
/// single test method).
func shouldSkipV08Case(_ testCase: ConformanceCase) -> Bool {
    if testCase.catalog?.version == "0.8" {
        print("[conformance] skipping v0.8 case (N/A for v0.9.1 renderer): \(testCase.name)")
        return true
    }
    return false
}

// MARK: - Error matching (mirrors Python _align_error_match)

/// Transforms a YAML `message:` pattern into a regex that tolerates known phrasing
/// differences between Python and Swift error messages.
func alignErrorMatch(_ pattern: String) -> String {
    if pattern.isEmpty { return pattern }
    var p = pattern
    if p.contains("required property") {
        p = "(\(p)|Field required|missing value)"
    }
    if p.contains("'v0.9' was expected") {
        p = "(\(p)|version must be)"
    }
    if p.contains("is not of type") {
        p = "(\(p)|cannot convert|type mismatch)"
    }
    if p.contains("Validation failed") {
        p = "(\(p)|Field required|Extra inputs)"
    }
    return p
}

func assertErrorMatches(_ error: Error, expected: ConformanceExpectedError, testName: String) {
    let message = (error as? any A2uiError)?.message ?? error.localizedDescription
    if let pattern = expected.message, !pattern.isEmpty {
        let regex = alignErrorMatch(pattern)
        let matched = (try? NSRegularExpression(pattern: regex, options: .caseInsensitive))
            .map { $0.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)) != nil }
            ?? message.localizedCaseInsensitiveContains(pattern)
        XCTAssertTrue(matched,
            "[\(testName)] Error message '\(message)' did not match pattern '\(regex)'")
    }
}

// MARK: - process_chunk dispatcher

/// A single expected event flattened out of a YAML `expect` part.
///
/// The YAML models one "part" as a bundle that may carry conversational `text`
/// and/or an `a2ui` array of N protocol messages, whereas the Swift parser emits
/// each as its own ``ParsedEvent``. `.text` carries the expected (trimmed) string;
/// `.message` carries no payload because the harness only asserts event *shape*
/// (text vs message) and count, matching the upstream Python conformance harness.
private enum ExpectedEvent {
    case text(String)
    case message
}

/// Flattens the YAML `expect` array into the ordered sequence of ``ParsedEvent``
/// the parser must emit. A part with both `text` and `a2ui` expands to a text
/// event followed by one message event per entry in the `a2ui` array (upstream
/// yields the leading conversational text before the block's messages).
private func flattenExpectedEvents(_ parts: [[String: Any]]) -> [ExpectedEvent] {
    var out: [ExpectedEvent] = []
    for part in parts {
        if let text = part["text"] as? String {
            out.append(.text(text))
        }
        if let a2ui = part["a2ui"] as? [Any] {
            out.append(contentsOf: a2ui.map { _ in ExpectedEvent.message })
        } else if part["a2ui"] != nil {
            // Non-array a2ui value (defensive): treat as a single message.
            out.append(.message)
        }
    }
    return out
}

/// Builds the parser config from the conformance case's catalog: the required-fields map
/// (componentType → required property names) and any case-level custom cuttable keys.
/// Mirrors what the upstream Python parser reads off its catalog.
private func makeParserConfig(_ testCase: ConformanceCase) -> A2UIStreamParserConfig {
    var required: [String: Set<String>] = [:]
    if let schema = testCase.catalog?.catalogSchema as? [String: Any],
       let components = schema["components"] as? [String: Any] {
        for (componentType, def) in components {
            guard let def = def as? [String: Any],
                  let requiredList = def["required"] as? [Any] else { continue }
            required[componentType] = Set(requiredList.compactMap { $0 as? String })
        }
    }
    return A2UIStreamParserConfig(
        cuttableKeys: Set(testCase.customCuttableKeys),
        requiredFieldsByComponent: required
    )
}

func runProcessChunk(testCase: ConformanceCase) async throws {
    let parser = A2UIStreamParser(config: makeParserConfig(testCase))

    // Buffer collects ParsedEvent values emitted between steps.
    actor EventBuffer {
        var events: [ParsedEvent] = []
        func append(_ e: ParsedEvent) { events.append(e) }
        var count: Int { events.count }
        func drain() -> [ParsedEvent] { let r = events; events = []; return r }
    }
    let buffer = EventBuffer()

    let consumeTask = Task {
        for await event in parser.events {
            await buffer.append(event)
        }
    }

    // Drains events emitted after an `add(_:)`, waiting until the emitted-event
    // count stops growing across successive scheduler ticks. This is more robust
    // than a single fixed sleep: the actor + AsyncStream continuation hop means
    // events can arrive over several cooperative-scheduling turns, and a lone
    // 10ms sleep occasionally raced ahead of the last event.
    func drainStable() async -> [ParsedEvent] {
        var previous = -1
        // Poll until the count is stable for one interval, capped so a genuinely
        // empty step doesn't stall the suite.
        for _ in 0..<20 {
            let current = await buffer.count
            if current == previous { break }
            previous = current
            try? await Task.sleep(nanoseconds: 3_000_000)
        }
        return await buffer.drain()
    }

    for step in testCase.steps {
        guard let input = step.input else {
            XCTFail("[\(testCase.name)] process_chunk step missing 'input'"); return
        }

        await parser.add(input)
        let events = await drainStable()

        if let expectedError = step.expectError {
            let errorEvents = events.compactMap { e -> Error? in
                if case .error(let err) = e { return err } else { return nil }
            }
            if let err = errorEvents.first {
                assertErrorMatches(err, expected: expectedError, testName: testCase.name)
            } else {
                XCTFail("[\(testCase.name)] Expected error '\(expectedError.category)' but no error was emitted")
            }
            break
        }

        // Validate against step.expect.
        if let expectedParts = step.expect as? [[String: Any]] {
            // Flatten the YAML parts into the ordered event sequence the parser
            // must emit, then compare against the non-error events for this step.
            let expectedEvents = flattenExpectedEvents(expectedParts)
            let nonErrorEvents = events.filter { if case .error = $0 { return false } else { return true } }
            XCTAssertEqual(nonErrorEvents.count, expectedEvents.count,
                "[\(testCase.name)] Expected \(expectedEvents.count) event(s), got \(nonErrorEvents.count)")
            for (event, expected) in zip(nonErrorEvents, expectedEvents) {
                switch expected {
                case .text(let expectedText):
                    if case .text(let actual) = event {
                        XCTAssertEqual(
                            actual.trimmingCharacters(in: .whitespacesAndNewlines),
                            expectedText.trimmingCharacters(in: .whitespacesAndNewlines),
                            "[\(testCase.name)] Text event mismatch")
                    } else {
                        XCTFail("[\(testCase.name)] Expected .text event but got \(event)")
                    }
                case .message:
                    if case .message = event { /* ok */ } else {
                        XCTFail("[\(testCase.name)] Expected .message event but got \(event)")
                    }
                }
            }
        } else if let arr = step.expect as? [Any], arr.isEmpty {
            // Empty array means no events expected for this step.
            let nonErrorEvents = events.filter { if case .error = $0 { return false } else { return true } }
            XCTAssertTrue(nonErrorEvents.isEmpty,
                "[\(testCase.name)] Expected no events but got \(nonErrorEvents.count)")
        }
        // nil expect → no assertion (step only feeds data, output verified by later steps).
    }

    await parser.finish()
    await consumeTask.value
}

// MARK: - parse_full dispatcher

func runParseFull(testCase: ConformanceCase) async throws {
    for step in testCase.steps {
        guard let input = step.input else {
            XCTFail("[\(testCase.name)] parse_full step missing 'input'"); return
        }

        let results = await parseFullResponse(input)

        if let expectedError = step.expectError {
            XCTAssertFalse(results.errors.isEmpty,
                "[\(testCase.name)] Expected error '\(expectedError.category)' but no error was emitted")
            if let err = results.errors.first {
                assertErrorMatches(err, expected: expectedError, testName: testCase.name)
            }
            return
        }

        if let expectedParts = step.expect as? [[String: Any]] {
            let textParts = results.parts.filter { !$0.text.isEmpty }
            XCTAssertEqual(textParts.count, expectedParts.count,
                "[\(testCase.name)] Expected \(expectedParts.count) parts, got \(textParts.count)")
            for (actual, expected) in zip(textParts, expectedParts) {
                let expectedText = expected["text"] as? String ?? ""
                XCTAssertEqual(actual.text.trimmingCharacters(in: .whitespacesAndNewlines),
                               expectedText.trimmingCharacters(in: .whitespacesAndNewlines),
                               "[\(testCase.name)] Text mismatch")
            }
        }
    }
}

private struct ParseFullResult {
    var parts: [(text: String, a2ui: Any?)] = []
    var errors: [Error] = []
}

/// Wraps `A2UIStreamParser` for async full-response parsing.
private func parseFullResponse(_ input: String) async -> ParseFullResult {
    let parser = A2UIStreamParser()
    var result = ParseFullResult()

    let collectTask = Task {
        var localResult = ParseFullResult()
        for await event in parser.events {
            switch event {
            case .text(let t): localResult.parts.append((t, nil))
            case .message(let m): localResult.parts.append(("", encodeMessageToAny(m)))
            case .error(let e): localResult.errors.append(e)
            }
        }
        return localResult
    }

    await parser.add(input)
    await parser.finish()
    result = await collectTask.value
    return result
}

// MARK: - validate dispatcher

func runValidate(testCase: ConformanceCase) throws {
    let decoder = JSONDecoder()
    for step in testCase.steps {
        guard let payload = step.payload else {
            XCTFail("[\(testCase.name)] validate step missing 'payload'"); return
        }

        if let expectedError = step.expectError {
            XCTAssertThrowsError(try validatePayload(payload, decoder: decoder),
                "[\(testCase.name)] Expected error '\(expectedError.category)'") { err in
                assertErrorMatches(err, expected: expectedError, testName: testCase.name)
            }
        } else {
            XCTAssertNoThrow(try validatePayload(payload, decoder: decoder),
                "[\(testCase.name)] Unexpected validation error")
        }
    }
}

private func validatePayload(_ payload: Any, decoder: JSONDecoder) throws {
    guard let messages = payload as? [[String: Any]] else {
        throw A2uiValidationError("Payload must be an array of message objects")
    }
    for msg in messages {
        let data = try JSONSerialization.data(withJSONObject: msg)
        _ = try decoder.decode(A2uiMessage.self, from: data)
    }
}

// MARK: - Helpers

private func encodeMessageToAny(_ message: A2uiMessage) -> Any {
    guard let data = try? JSONEncoder().encode(message),
          let obj = try? JSONSerialization.jsonObject(with: data) else {
        return [String: Any]()
    }
    return obj
}
