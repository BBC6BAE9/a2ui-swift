// Tests/A2UIConformanceTests/ConformanceHarnessTests.swift
import Foundation
import XCTest
@testable import A2UISwiftCore

final class ConformanceHarnessTests: XCTestCase {

    // MARK: - alignErrorMatch

    func testAlignErrorMatchPassthrough() {
        let pattern = "some other error"
        XCTAssertEqual(alignErrorMatch(pattern), pattern)
    }

    func testAlignErrorMatchRequiredProperty() {
        let result = alignErrorMatch("required property 'foo' missing")
        XCTAssertTrue(result.contains("Field required"))
        XCTAssertTrue(result.contains("missing value"))
        XCTAssertTrue(result.contains("required property 'foo' missing"))
    }

    func testAlignErrorMatchVersionExpected() {
        let result = alignErrorMatch("'v0.9' was expected")
        XCTAssertTrue(result.contains("version must be"))
        XCTAssertTrue(result.contains("'v0.9' was expected"))
    }

    func testAlignErrorMatchIsNotOfType() {
        let result = alignErrorMatch("is not of type 'string'")
        XCTAssertTrue(result.contains("cannot convert"))
        XCTAssertTrue(result.contains("type mismatch"))
        XCTAssertTrue(result.contains("is not of type 'string'"))
    }

    func testAlignErrorMatchValidationFailed() {
        let result = alignErrorMatch("Validation failed for field")
        XCTAssertTrue(result.contains("Field required"))
        XCTAssertTrue(result.contains("Extra inputs"))
        XCTAssertTrue(result.contains("Validation failed for field"))
    }

    func testAlignErrorMatchEmpty() {
        XCTAssertEqual(alignErrorMatch(""), "")
    }

    // MARK: - skipAgentOnlyAction

    func testSkipAgentOnlyActionThrowsForKnownActions() {
        let agentActions = [
            "generate_prompt", "select_catalog", "handle_rpc", "execute_tool",
            "create_a2ui_part", "is_a2ui_part", "try_activate", "try_activate_extension",
            "get_extension", "convert_event", "select_newest", "verify_cuttable_keys",
            "render", "remove_strict_validation", "has_parts", "load_catalog",
            "prune", "load"
        ]
        for action in agentActions {
            XCTAssertThrowsError(
                try skipAgentOnlyAction(action, testName: "test"),
                "Expected error for agent-only action '\(action)'"
            ) { err in
                XCTAssertTrue(err is XCTSkip, "Expected XCTSkip for agent-only action '\(action)', got \(type(of: err))")
            }
        }
    }

    func testSkipAgentOnlyActionPassesForRendererActions() {
        let rendererActions = ["process_chunk", "parse_full", "validate", "unknown_action"]
        for action in rendererActions {
            // Should not throw
            do {
                try skipAgentOnlyAction(action, testName: "test")
            } catch {
                XCTFail("skipAgentOnlyAction should not throw for renderer action '\(action)', got: \(error)")
            }
        }
    }

    // MARK: - runParseFull (basic smoke test)

    func testParseFullPlainText() async {
        let step = ConformanceStep(
            input: "Hello world",
            payload: nil,
            args: nil,
            expect: nil,
            expectOutput: nil,
            expectError: nil,
            expectSelected: nil
        )
        let testCase = ConformanceCase(
            name: "test_plain_text",
            description: nil,
            catalog: nil,
            action: "parse_full",
            steps: [step]
        )
        // Should not throw — plain text produces text events only
        do {
            try await runParseFull(testCase: testCase)
        } catch {
            XCTFail("runParseFull should not throw for plain text input, got: \(error)")
        }
    }

}
