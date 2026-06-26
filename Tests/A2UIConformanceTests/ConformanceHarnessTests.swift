// Tests/A2UIConformanceTests/ConformanceHarnessTests.swift
import Testing
import Foundation
import XCTest

@Suite("ConformanceHarness")
struct ConformanceHarnessTests {

    // MARK: - alignErrorMatch

    @Test func alignErrorMatchPassthrough() {
        let pattern = "some other error"
        #expect(alignErrorMatch(pattern) == pattern)
    }

    @Test func alignErrorMatchRequiredProperty() {
        let result = alignErrorMatch("required property 'foo' missing")
        #expect(result.contains("Field required"))
        #expect(result.contains("missing value"))
        #expect(result.contains("required property 'foo' missing"))
    }

    @Test func alignErrorMatchVersionExpected() {
        let result = alignErrorMatch("'v0.9' was expected")
        #expect(result.contains("version must be"))
        #expect(result.contains("'v0.9' was expected"))
    }

    @Test func alignErrorMatchIsNotOfType() {
        let result = alignErrorMatch("is not of type 'string'")
        #expect(result.contains("cannot convert"))
        #expect(result.contains("type mismatch"))
        #expect(result.contains("is not of type 'string'"))
    }

    @Test func alignErrorMatchValidationFailed() {
        let result = alignErrorMatch("Validation failed for field")
        #expect(result.contains("Field required"))
        #expect(result.contains("Extra inputs"))
        #expect(result.contains("Validation failed for field"))
    }

    @Test func alignErrorMatchEmpty() {
        #expect(alignErrorMatch("") == "")
    }

    // MARK: - skipAgentOnlyAction

    @Test func skipAgentOnlyActionThrowsForKnownActions() throws {
        let agentActions = [
            "generate_prompt", "select_catalog", "handle_rpc", "execute_tool",
            "create_a2ui_part", "is_a2ui_part", "try_activate", "try_activate_extension",
            "get_extension", "convert_event", "select_newest", "verify_cuttable_keys",
            "render", "remove_strict_validation", "has_parts", "load_catalog",
            "prune", "load"
        ]
        for action in agentActions {
            var threw = false
            do {
                try skipAgentOnlyAction(action, testName: "test")
            } catch is XCTSkip {
                threw = true
            }
            #expect(threw, "Expected XCTSkip for agent-only action '\(action)'")
        }
    }

    @Test func skipAgentOnlyActionPassesForRendererActions() throws {
        let rendererActions = ["process_chunk", "parse_full", "validate", "unknown_action"]
        for action in rendererActions {
            // Should not throw
            try skipAgentOnlyAction(action, testName: "test")
        }
    }

    // MARK: - runParseFull (basic smoke test)

    @Test func parseFullPlainText() async throws {
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
        try await runParseFull(testCase: testCase)
    }

}
