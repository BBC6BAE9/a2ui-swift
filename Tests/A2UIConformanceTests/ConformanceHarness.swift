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
    // The v0.9 loading placeholder is a `Row`; a partial parent with an unseen child can only
    // be yielded when that placeholder component type is defined by the catalog.
    var canSynthesizePlaceholder = false
    if let schema = testCase.catalog?.catalogSchema as? [String: Any],
       let components = schema["components"] as? [String: Any] {
        for (componentType, def) in components {
            guard let def = def as? [String: Any],
                  let requiredList = def["required"] as? [Any] else { continue }
            required[componentType] = Set(requiredList.compactMap { $0 as? String })
        }
        canSynthesizePlaceholder = components["Row"] != nil
    }

    return A2UIStreamParserConfig(
        cuttableKeys: Set(testCase.customCuttableKeys),
        requiredFieldsByComponent: required,
        canSynthesizePlaceholder: canSynthesizePlaceholder
    )
}

func runProcessChunk(testCase: ConformanceCase) async throws {
    let parser = A2UIStreamParser(config: makeParserConfig(testCase))

    // Buffer collects ParsedEvent values emitted between steps.
    actor EventBuffer {
        private var events: [ParsedEvent] = []
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
    func drainStable(expectedCount: Int? = nil) async -> [ParsedEvent] {
        // When the step declares how many events it expects, wait for that many
        // first (bounded at ~1s): the stability window alone can drain early if
        // a busy CI scheduler delays an in-flight event past one interval.
        if let expectedCount, expectedCount > 0 {
            for _ in 0..<200 {
                if await buffer.count >= expectedCount { break }
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
        }
        var previous = -1
        // Poll until the count is stable for one interval, capped so a genuinely
        // empty step doesn't stall the suite. Also catches events beyond the
        // expected count so over-emission still fails the assertion below.
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

        // Flatten expectations up front so the drain can wait for the exact
        // event count this step declares.
        let expectedEvents = (step.expect as? [[String: Any]]).map(flattenExpectedEvents)

        await parser.add(input)
        let events = await drainStable(expectedCount: expectedEvents?.count)

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

        // Validate against step.expect: compare the flattened expected event
        // sequence against the non-error events for this step.
        if let expectedEvents {
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
        }
        // An empty `expect` array flattens to zero expected events and is asserted
        // above; nil expect → no assertion (step only feeds data, output verified
        // by later steps).
    }

    await parser.finish()
    await consumeTask.value
}

// MARK: - parse_full / fix_payload dispatcher

/// Dispatches both `parse_full` and `fix_payload` conformance actions against the
/// non-streaming ``A2UIResponseParser``. Both actions live here because they share
/// the same YAML `expect` / `expect_error` shapes and the same JSON-equality
/// assertions.
func runParseFull(testCase: ConformanceCase) async throws {
    for step in testCase.steps {
        guard let input = step.input else {
            XCTFail("[\(testCase.name)] \(testCase.action) step missing 'input'"); return
        }

        switch testCase.action {
        case "fix_payload":
            runFixPayloadStep(input: input, step: step, testName: testCase.name)
        default: // "parse_full"
            runParseFullStep(input: input, step: step, testName: testCase.name)
        }
    }
}

/// Runs one `parse_full` step: parse the complete response, then assert the
/// thrown ``A2uiParseError`` (when `expect_error` is set) or the decoded
/// ``A2uiResponsePart`` list against `expect`.
private func runParseFullStep(input: String, step: ConformanceStep, testName: String) {
    do {
        let parts = try A2UIResponseParser.parseFull(input)

        if let expectedError = step.expectError {
            XCTFail("[\(testName)] Expected error '\(expectedError.category)' but parse succeeded with \(parts.count) part(s)")
            return
        }

        guard let expectedParts = step.expect as? [[String: Any]] else {
            // No structured expectation for this step (e.g. harness smoke tests).
            return
        }

        XCTAssertEqual(parts.count, expectedParts.count,
            "[\(testName)] Expected \(expectedParts.count) part(s), got \(parts.count)")

        for (actual, expected) in zip(parts, expectedParts) {
            let expectedText = expected["text"] as? String ?? ""
            XCTAssertEqual(actual.text, expectedText, "[\(testName)] Text part mismatch")

            // `a2ui` in the YAML may be absent (trailing text-only part) or a
            // JSON value that must match the decoded block exactly.
            if let expectedA2ui = expected["a2ui"] {
                XCTAssertTrue(jsonEqual(actual.a2ui, expectedA2ui),
                    "[\(testName)] a2ui mismatch: got \(String(describing: actual.a2ui)), expected \(expectedA2ui)")
            } else {
                XCTAssertNil(actual.a2ui, "[\(testName)] Expected no a2ui payload for trailing text part")
            }
        }
    } catch {
        if let expectedError = step.expectError {
            assertErrorMatches(error, expected: expectedError, testName: testName)
        } else if step.expect != nil {
            XCTFail("[\(testName)] Unexpected parse error: \(error)")
        }
        // No expectation at all (harness smoke tests) → tolerate the throw.
    }
}

/// Dispatches the `has_parts` action: asserts ``A2UIResponseParser/hasA2uiParts(_:)``
/// matches the boolean `expect` for each step.
func runHasParts(testCase: ConformanceCase) {
    for step in testCase.steps {
        guard let input = step.input else {
            XCTFail("[\(testCase.name)] has_parts step missing 'input'"); return
        }
        guard let expected = step.expect as? Bool else {
            XCTFail("[\(testCase.name)] has_parts step missing boolean 'expect'"); return
        }
        XCTAssertEqual(A2UIResponseParser.hasA2uiParts(input), expected,
            "[\(testCase.name)] has_a2ui_parts mismatch for input \(input.debugDescription)")
    }
}

/// Runs one `fix_payload` step: repair the payload, decode it to JSON, and assert
/// it equals the expected (always-array) `expect` value.
private func runFixPayloadStep(input: String, step: ConformanceStep, testName: String) {
    let fixed = A2UIResponseParser.fixPayload(input)

    guard let data = fixed.data(using: .utf8),
          let decoded = try? JSONSerialization.jsonObject(with: data) else {
        XCTFail("[\(testName)] fix_payload produced unparseable JSON: \(fixed)")
        return
    }

    guard let expected = step.expect else {
        return // No expectation (defensive).
    }
    XCTAssertTrue(jsonEqual(decoded, expected),
        "[\(testName)] fix_payload mismatch: got \(decoded), expected \(expected)")
}

// MARK: - JSON structural equality

/// Compares two `JSONSerialization`-shaped values (`[Any]`, `[String: Any]`,
/// `String`, `NSNumber`, `Bool`, `NSNull`) for structural equality, independent
/// of dictionary key order. Numeric values compare by their `Double` value so
/// `1` and `1.0` are equal.
func jsonEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
        return true
    case (.some(let l), .some(let r)):
        return jsonEqualNonNil(l, r)
    default:
        return false
    }
}

private func jsonEqualNonNil(_ lhs: Any, _ rhs: Any) -> Bool {
    if lhs is NSNull && rhs is NSNull { return true }

    if let l = lhs as? [Any], let r = rhs as? [Any] {
        guard l.count == r.count else { return false }
        return zip(l, r).allSatisfy { jsonEqualNonNil($0, $1) }
    }

    if let l = lhs as? [String: Any], let r = rhs as? [String: Any] {
        guard l.count == r.count else { return false }
        for (key, lv) in l {
            guard let rv = r[key], jsonEqualNonNil(lv, rv) else { return false }
        }
        return true
    }

    if let l = lhs as? String, let r = rhs as? String { return l == r }

    // Distinguish Bool from numeric: NSNumber bridges both, so check Bool first
    // only when both sides are genuine booleans.
    if let l = lhs as? Bool, let r = rhs as? Bool,
       isBoolNumber(lhs), isBoolNumber(rhs) {
        return l == r
    }

    if let l = lhs as? NSNumber, let r = rhs as? NSNumber {
        return l.doubleValue == r.doubleValue
    }

    return false
}

/// True when `value` is an `NSNumber` that actually represents a boolean
/// (`kCFBooleanTrue`/`kCFBooleanFalse`), so it is not mistaken for `0`/`1`.
private func isBoolNumber(_ value: Any) -> Bool {
    guard let number = value as? NSNumber else { return false }
    return CFGetTypeID(number) == CFBooleanGetTypeID()
}

// MARK: - validate dispatcher

func runValidate(testCase: ConformanceCase) throws {
    let decoder = JSONDecoder()
    // One semantic validator per case so that incremental-update steps validate against
    // the component ids accumulated from earlier steps in the SAME case.
    let semanticValidator = A2uiPayloadValidator(catalogSchema: testCase.catalog?.catalogSchema)

    for step in testCase.steps {
        guard let payload = step.payload else {
            XCTFail("[\(testCase.name)] validate step missing 'payload'"); return
        }

        if let expectedError = step.expectError {
            XCTAssertThrowsError(
                try validatePayload(payload, decoder: decoder, semanticValidator: semanticValidator),
                "[\(testCase.name)] Expected error '\(expectedError.category)'") { err in
                assertErrorMatches(err, expected: expectedError, testName: testCase.name)
            }
        } else {
            XCTAssertNoThrow(
                try validatePayload(payload, decoder: decoder, semanticValidator: semanticValidator),
                "[\(testCase.name)] Unexpected validation error")
        }
    }
}

private func validatePayload(
    _ payload: Any,
    decoder: JSONDecoder,
    semanticValidator: A2uiPayloadValidator
) throws {
    guard let messages = payload as? [[String: Any]] else {
        throw A2uiValidationError("Payload must be an array of message objects")
    }
    // 1. Envelope decode (version + key shape) via the message Codable layer.
    for msg in messages {
        let data = try JSONSerialization.data(withJSONObject: msg)
        _ = try decoder.decode(A2uiMessage.self, from: data)
    }
    // 2. Semantic / graph validation (duplicates, roots, references, cycles, depth, paths,
    //    catalog property schemas). Carries state across steps within the case.
    try semanticValidator.validate(payload)
}
