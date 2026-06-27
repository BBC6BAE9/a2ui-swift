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
            try skipAgentOnlyAction(testCase.action, testName: testCase.name)
            switch testCase.action {
            case "parse_full", "fix_payload":
                try await runParseFull(testCase: testCase)
            default:
                throw XCTSkip("N/A for renderer: action '\(testCase.action)' (test: \(testCase.name))")
            }
        }
    }
}
