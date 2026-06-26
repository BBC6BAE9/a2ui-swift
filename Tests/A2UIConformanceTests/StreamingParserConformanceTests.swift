// Tests/A2UIConformanceTests/StreamingParserConformanceTests.swift
import XCTest
@testable import A2UISwiftCore

final class StreamingParserConformanceTests: XCTestCase {

    private static var cases: [ConformanceCase] = {
        (try? loadConformanceCases(suite: "streaming_parser")) ?? []
    }()

    func test_streaming_parser_conformance() async throws {
        let cases = StreamingParserConformanceTests.cases
        guard !cases.isEmpty else {
            throw XCTSkip("Could not load conformance cases for 'streaming_parser' — check Bundle.module resources")
        }

        for testCase in cases {
            try skipAgentOnlyAction(testCase.action, testName: testCase.name)
            try await runProcessChunk(testCase: testCase)
        }
    }
}
