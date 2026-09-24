// Tests/A2UIConformanceTests/SchemaManagerConformanceTests.swift
import XCTest
@testable import A2UISwiftCore

final class SchemaManagerConformanceTests: XCTestCase {

    private static var cases: [ConformanceCase] = {
        (try? loadConformanceCases(suite: "schema_manager")) ?? []
    }()

    func test_schema_manager_conformance() throws {
        let cases = SchemaManagerConformanceTests.cases
        guard !cases.isEmpty else {
            throw XCTSkip("Could not load conformance cases for 'schema_manager' — check Bundle.module resources")
        }
        throw XCTSkip("N/A for renderer: all schema_manager suite actions are agent-side")
    }
}
