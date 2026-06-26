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

func runProcessChunk(testCase: ConformanceCase) async throws {
    let parser = A2UIStreamParser()

    // Buffer collects ParsedEvent values emitted between steps.
    actor EventBuffer {
        var events: [ParsedEvent] = []
        func append(_ e: ParsedEvent) { events.append(e) }
        func drain() -> [ParsedEvent] { let r = events; events = []; return r }
    }
    let buffer = EventBuffer()

    let consumeTask = Task {
        for await event in parser.events {
            await buffer.append(event)
        }
    }

    for step in testCase.steps {
        guard let input = step.input else {
            XCTFail("[\(testCase.name)] process_chunk step missing 'input'"); return
        }

        await parser.add(input)
        // Yield several times to let events propagate through the async stream.
        for _ in 0..<5 { await Task.yield() }
        let events = await buffer.drain()

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
            // Non-empty expected array: verify we got corresponding events.
            let nonErrorEvents = events.filter { if case .error = $0 { return false } else { return true } }
            XCTAssertEqual(nonErrorEvents.count, expectedParts.count,
                "[\(testCase.name)] Expected \(expectedParts.count) event(s), got \(nonErrorEvents.count)")
            for (event, expected) in zip(nonErrorEvents, expectedParts) {
                if let expectedText = expected["text"] as? String {
                    if case .text(let actual) = event {
                        XCTAssertEqual(
                            actual.trimmingCharacters(in: .whitespacesAndNewlines),
                            expectedText.trimmingCharacters(in: .whitespacesAndNewlines),
                            "[\(testCase.name)] Text event mismatch")
                    } else {
                        XCTFail("[\(testCase.name)] Expected .text event but got \(event)")
                    }
                } else if expected["a2ui"] != nil {
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
    consumeTask.cancel()
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
