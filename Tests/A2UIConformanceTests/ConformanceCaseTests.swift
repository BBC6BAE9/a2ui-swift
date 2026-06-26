// Tests/A2UIConformanceTests/ConformanceCaseTests.swift
import XCTest
import Foundation

final class ConformanceCaseTests: XCTestCase {

    func test_loadsParserSuite() throws {
        let cases = try loadConformanceCases(suite: "parser")
        XCTAssertEqual(cases.count, 19, "parser.yaml should have 19 test cases, got \(cases.count)")
        let names = cases.map(\.name)
        XCTAssertTrue(names.contains("test_parse_empty_response"),
            "Expected 'test_parse_empty_response' in parser suite")
    }

    func test_loadsAllSuites() throws {
        let suites = ["parser", "streaming_parser", "catalog", "validator", "schema_manager"]
        for suite in suites {
            let cases = try loadConformanceCases(suite: suite)
            XCTAssertGreaterThan(cases.count, 0, "\(suite) suite should have at least one case")
        }
    }

    func test_caseFieldsDecoded() throws {
        let cases = try loadConformanceCases(suite: "parser")
        let errCase = try XCTUnwrap(cases.first(where: { $0.name == "test_parse_empty_response" }),
            "Expected case 'test_parse_empty_response'")
        XCTAssertEqual(errCase.action, "parse_full")
        XCTAssertEqual(errCase.steps.count, 1)
        let step = errCase.steps[0]
        XCTAssertNotNil(step.expectError)
        XCTAssertEqual(step.expectError?.category, "ParseError")
    }

    func test_streamingParserCaseHasSteps() throws {
        let cases = try loadConformanceCases(suite: "streaming_parser")
        let multiStep = try XCTUnwrap(cases.first(where: { $0.steps.count > 1 }),
            "Expected a multi-step case in streaming_parser")
        XCTAssertGreaterThan(multiStep.steps.count, 1,
            "streaming_parser should have multi-step cases")
    }

    func test_catalogConfigDecoded() throws {
        let cases = try loadConformanceCases(suite: "streaming_parser")
        let caseWithCatalog = try XCTUnwrap(cases.first(where: { $0.catalog != nil }),
            "Expected a case with catalog in streaming_parser")
        let catalog = try XCTUnwrap(caseWithCatalog.catalog)
        XCTAssertTrue(catalog.version == "0.8" || catalog.version == "0.9",
            "Unexpected catalog version: \(catalog.version)")
    }

    func test_loadTestDataJSONWorks() throws {
        // The streaming_parser suite references "test_data/simplified_s2c_v08.json"
        let json = try loadTestDataJSON(path: "test_data/simplified_s2c_v08.json")
        XCTAssertTrue(json is [String: Any] || json is [Any],
            "Expected JSON object or array")
    }
}
