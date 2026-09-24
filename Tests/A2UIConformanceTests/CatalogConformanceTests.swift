// Tests/A2UIConformanceTests/CatalogConformanceTests.swift
import XCTest
@testable import A2UISwiftCore

final class CatalogConformanceTests: XCTestCase {

    private static var cases: [ConformanceCase] = {
        (try? loadConformanceCases(suite: "catalog")) ?? []
    }()

    func test_catalog_conformance() throws {
        let cases = CatalogConformanceTests.cases
        guard !cases.isEmpty else {
            throw XCTSkip("Could not load conformance cases for 'catalog' — check Bundle.module resources")
        }
        throw XCTSkip("N/A for renderer: all catalog suite actions are agent-side")
    }
}
