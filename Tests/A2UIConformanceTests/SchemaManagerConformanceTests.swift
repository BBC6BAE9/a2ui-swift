// Tests/A2UIConformanceTests/SchemaManagerConformanceTests.swift
import XCTest
@testable import A2UISwiftCore

final class SchemaManagerConformanceTests: XCTestCase {

    private static var cases: [ConformanceCase] = {
        (try? loadConformanceCases(suite: "schema_manager")) ?? []
    }()

    func test_schema_manager_conformance() throws {
        let cases = SchemaManagerConformanceTests.cases
        XCTAssertFalse(cases.isEmpty, "No schema_manager conformance cases loaded")

        for testCase in cases {
            throw XCTSkip("N/A for renderer: '\(testCase.action)' is agent-side schema management (test: \(testCase.name))")
        }
    }
}
