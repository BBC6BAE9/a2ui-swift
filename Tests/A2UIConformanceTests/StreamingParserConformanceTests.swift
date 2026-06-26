// Tests/A2UIConformanceTests/StreamingParserConformanceTests.swift
import XCTest
@testable import A2UISwiftCore

final class StreamingParserConformanceTests: XCTestCase {

    private static var cases: [ConformanceCase] = {
        (try? loadConformanceCases(suite: "streaming_parser")) ?? []
    }()

    func test_streaming_parser_conformance() async throws {
        let cases = StreamingParserConformanceTests.cases
        XCTAssertFalse(cases.isEmpty, "No streaming_parser conformance cases loaded")

        for testCase in cases {
            try skipAgentOnlyAction(testCase.action, testName: testCase.name)
            try await runProcessChunk(testCase: testCase)
        }
    }
}
