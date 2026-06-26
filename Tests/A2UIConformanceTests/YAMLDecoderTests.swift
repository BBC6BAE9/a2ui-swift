// Tests/A2UIConformanceTests/YAMLDecoderTests.swift
import XCTest
import Foundation

final class YAMLDecoderTests: XCTestCase {

    /// Helper: locate the Resources bundle for this test target.
    private func suitesURL() throws -> URL {
        let bundle = Bundle.module
        let url = try XCTUnwrap(
            bundle.url(forResource: "suites", withExtension: nil),
            "Cannot find Resources/suites in test bundle"
        )
        return url
    }

    func test_parsesValidatorSuite() throws {
        let url = try suitesURL().appendingPathComponent("validator.yaml")
        let text = try String(contentsOf: url, encoding: .utf8)
        let result = try parseYAML(text)
        let cases = try XCTUnwrap(result as? [Any])
        XCTAssertGreaterThan(cases.count, 0, "validator.yaml should have at least one test case")
    }

    func test_parsesStreamingParserSuite() throws {
        let url = try suitesURL().appendingPathComponent("streaming_parser.yaml")
        let text = try String(contentsOf: url, encoding: .utf8)
        let result = try parseYAML(text)
        let cases = try XCTUnwrap(result as? [Any])
        XCTAssertGreaterThan(cases.count, 0, "streaming_parser.yaml should have at least one test case")
    }

    func test_parsesCatalogSuite() throws {
        let url = try suitesURL().appendingPathComponent("catalog.yaml")
        let text = try String(contentsOf: url, encoding: .utf8)
        let result = try parseYAML(text)
        let cases = try XCTUnwrap(result as? [Any])
        XCTAssertGreaterThan(cases.count, 0, "catalog.yaml should have at least one test case")
    }

    func test_parsesParserSuite() throws {
        let url = try suitesURL().appendingPathComponent("parser.yaml")
        let text = try String(contentsOf: url, encoding: .utf8)
        let result = try parseYAML(text)
        let cases = try XCTUnwrap(result as? [Any])
        XCTAssertGreaterThan(cases.count, 0, "parser.yaml should have at least one test case")
    }

    func test_parsesSchemaManagerSuite() throws {
        let url = try suitesURL().appendingPathComponent("schema_manager.yaml")
        let text = try String(contentsOf: url, encoding: .utf8)
        let result = try parseYAML(text)
        let cases = try XCTUnwrap(result as? [Any])
        XCTAssertGreaterThan(cases.count, 0, "schema_manager.yaml should have at least one test case")
    }

    func test_caseCountsMatchExpected() throws {
        let expectations: [(String, Int)] = [
            ("validator.yaml", 45),
            ("streaming_parser.yaml", 76),
            ("catalog.yaml", 24),
        ]
        let suitesDir = try suitesURL()
        for (file, expected) in expectations {
            let url = suitesDir.appendingPathComponent(file)
            let text = try String(contentsOf: url, encoding: .utf8)
            let result = try parseYAML(text)
            let cases = try XCTUnwrap(result as? [Any])
            XCTAssertEqual(cases.count, expected,
                "\(file): expected \(expected) cases, got \(cases.count)")
        }
    }

    func test_simpleScalarsAndTypes() throws {
        let yaml = """
        - name: foo
          count: 42
          flag: true
          nothing: null
          ratio: 3.14
        """
        let result = try parseYAML(yaml)
        let arr = try XCTUnwrap(result as? [[String: Any]])
        XCTAssertEqual(arr.count, 1)
        let first = arr[0]
        XCTAssertEqual(first["name"] as? String, "foo")
        XCTAssertEqual(first["count"] as? Int, 42)
        XCTAssertEqual(first["flag"] as? Bool, true)
        XCTAssertTrue(first["nothing"] is NSNull)
        XCTAssertEqual(first["ratio"] as? Double, 3.14)
    }

    func test_flowSequence() throws {
        let yaml = "items: [Text, Button, Image]\n"
        let result = try parseYAML(yaml)
        let dict = try XCTUnwrap(result as? [String: Any])
        let items = try XCTUnwrap(dict["items"] as? [Any])
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0] as? String, "Text")
    }

    func test_flowMapping() throws {
        let yaml = "obj: {type: object, title: foo}\n"
        let result = try parseYAML(yaml)
        let dict = try XCTUnwrap(result as? [String: Any])
        let obj = try XCTUnwrap(dict["obj"] as? [String: Any])
        XCTAssertEqual(obj["type"] as? String, "object")
    }
}
