// Tests/A2UIConformanceTests/ConformanceCaseTests.swift
import Testing
import Foundation

@Suite("ConformanceCase")
struct ConformanceCaseTests {

    @Test func loadsParserSuite() throws {
        let cases = try loadConformanceCases(suite: "parser")
        #expect(cases.count == 19, "parser.yaml should have 19 test cases, got \(cases.count)")
        let names = cases.map(\.name)
        #expect(names.contains("test_parse_empty_response"), "Expected 'test_parse_empty_response' in parser suite")
    }

    @Test func loadsAllSuites() throws {
        let suites = ["parser", "streaming_parser", "catalog", "validator", "schema_manager"]
        for suite in suites {
            let cases = try loadConformanceCases(suite: suite)
            #expect(cases.count > 0, "\(suite) suite should have at least one case")
        }
    }

    @Test func caseFieldsDecoded() throws {
        let cases = try loadConformanceCases(suite: "parser")
        // Find a case with expect_error at top level
        let errCase = try #require(cases.first(where: { $0.name == "test_parse_empty_response" }))
        #expect(errCase.action == "parse_full")
        #expect(errCase.steps.count == 1)
        let step = errCase.steps[0]
        #expect(step.expectError != nil)
        #expect(step.expectError?.category == "ParseError")
    }

    @Test func streamingParserCaseHasSteps() throws {
        let cases = try loadConformanceCases(suite: "streaming_parser")
        let multiStep = try #require(cases.first(where: { $0.steps.count > 1 }))
        #expect(multiStep.steps.count > 1, "streaming_parser should have multi-step cases")
    }

    @Test func catalogConfigDecoded() throws {
        let cases = try loadConformanceCases(suite: "streaming_parser")
        // All streaming_parser cases have a catalog block with s2c_schema referencing a test_data file
        let caseWithCatalog = try #require(cases.first(where: { $0.catalog != nil }))
        let catalog = try #require(caseWithCatalog.catalog)
        #expect(catalog.version == "0.8" || catalog.version == "0.9")
    }

    @Test func loadTestDataJSONWorks() throws {
        // The streaming_parser suite references "test_data/simplified_s2c_v08.json"
        // loadTestDataJSON should resolve it
        let json = try loadTestDataJSON(path: "test_data/simplified_s2c_v08.json")
        #expect(json is [String: Any] || json is [Any], "Expected JSON object or array")
    }
}
