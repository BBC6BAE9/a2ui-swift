// Tests/A2UIConformanceTests/CatalogConformanceTests.swift
import XCTest
@testable import A2UISwiftCore

final class CatalogConformanceTests: XCTestCase {

    private static var cases: [ConformanceCase] = {
        (try? loadConformanceCases(suite: "catalog")) ?? []
    }()

    func test_catalog_conformance() throws {
        let cases = CatalogConformanceTests.cases
        XCTAssertFalse(cases.isEmpty, "No catalog conformance cases loaded")

        for testCase in cases {
            // All catalog actions are agent-side; skip with explanation
            throw XCTSkip("N/A for renderer: action '\(testCase.action)' in catalog suite is agent-side (test: \(testCase.name))")
        }
    }
}
