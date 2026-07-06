// Tests/A2UIConformanceTests/ParserConformanceTests.swift
import XCTest
@testable import A2UISwiftCore

final class ParserConformanceTests: XCTestCase {

    private static var cases: [ConformanceCase] = {
        (try? loadConformanceCases(suite: "parser")) ?? []
    }()

    func test_parser_conformance() async throws {
        let cases = ParserConformanceTests.cases
        guard !cases.isEmpty else {
            throw XCTSkip("Could not load conformance cases for 'parser' — check Bundle.module resources")
        }

        for testCase in cases {
            if shouldSkipV08Case(testCase) { continue }
            // Handle the renderer-relevant actions this suite exercises. `has_parts`
            // is normally agent-only, but the parser suite ships explicit
            // `has_a2ui_parts` cases that the renderer can satisfy via
            // `A2UIResponseParser.hasA2uiParts`, so route it here rather than
            // skipping (a mid-loop XCTSkip would abort the remaining cases).
            switch testCase.action {
            case "parse_full", "fix_payload":
                try await runParseFull(testCase: testCase)
            case "has_parts":
                runHasParts(testCase: testCase)
            default:
                try skipAgentOnlyAction(testCase.action, testName: testCase.name)
                throw XCTSkip("N/A for renderer: action '\(testCase.action)' (test: \(testCase.name))")
            }
        }
    }
}
