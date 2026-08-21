// Tests/A2UIConformanceTests/ValidatorConformanceTests.swift
import XCTest
@testable import A2UISwiftCore

final class ValidatorConformanceTests: XCTestCase {

    private static var cases: [ConformanceCase] = {
        (try? loadConformanceCases(suite: "validator")) ?? []
    }()

    func test_validator_conformance() throws {
        let cases = ValidatorConformanceTests.cases
        guard !cases.isEmpty else {
            throw XCTSkip("Could not load conformance cases for 'validator' — check Bundle.module resources")
        }

        for testCase in cases {
            if shouldSkipV08Case(testCase) { continue }
            try skipAgentOnlyAction(testCase.action, testName: testCase.name)
            switch testCase.action {
            case "validate":
                try runValidate(testCase: testCase)
            default:
                throw XCTSkip("N/A for renderer: action '\(testCase.action)' (test: \(testCase.name))")
            }
        }
    }
}
