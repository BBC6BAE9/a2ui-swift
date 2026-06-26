// Tests/A2UIConformanceTests/YAMLDecoderTests.swift
import Testing
import Foundation

@Suite("YAMLDecoder")
struct YAMLDecoderTests {

    /// Helper: locate the Resources bundle for this test target.
    private func suitesURL() throws -> URL {
        // In SPM test bundles the resources are copied next to the binary.
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "suites", withExtension: nil) else {
            throw YAMLError.parse("Cannot find Resources/suites in test bundle")
        }
        return url
    }

    @Test func parsesValidatorSuite() throws {
        let url = try suitesURL().appendingPathComponent("validator.yaml")
        let text = try String(contentsOf: url, encoding: .utf8)
        let result = try parseYAML(text)
        let cases = try #require(result as? [Any])
        #expect(cases.count > 0, "validator.yaml should have at least one test case")
    }

    @Test func parsesStreamingParserSuite() throws {
        let url = try suitesURL().appendingPathComponent("streaming_parser.yaml")
        let text = try String(contentsOf: url, encoding: .utf8)
        let result = try parseYAML(text)
        let cases = try #require(result as? [Any])
        #expect(cases.count > 0, "streaming_parser.yaml should have at least one test case")
    }

    @Test func parsesCatalogSuite() throws {
        let url = try suitesURL().appendingPathComponent("catalog.yaml")
        let text = try String(contentsOf: url, encoding: .utf8)
        let result = try parseYAML(text)
        let cases = try #require(result as? [Any])
        #expect(cases.count > 0, "catalog.yaml should have at least one test case")
    }

    @Test func parsesParserSuite() throws {
        let url = try suitesURL().appendingPathComponent("parser.yaml")
        let text = try String(contentsOf: url, encoding: .utf8)
        let result = try parseYAML(text)
        let cases = try #require(result as? [Any])
        #expect(cases.count > 0, "parser.yaml should have at least one test case")
    }

    @Test func parsesSchemaManagerSuite() throws {
        let url = try suitesURL().appendingPathComponent("schema_manager.yaml")
        let text = try String(contentsOf: url, encoding: .utf8)
        let result = try parseYAML(text)
        let cases = try #require(result as? [Any])
        #expect(cases.count > 0, "schema_manager.yaml should have at least one test case")
    }

    @Test func caseCountsMatchExpected() throws {
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
            let cases = try #require(result as? [Any])
            #expect(cases.count == expected, "\(file): expected \(expected) cases, got \(cases.count)")
        }
    }

    @Test func simpleScalarsAndTypes() throws {
        let yaml = """
        - name: foo
          count: 42
          flag: true
          nothing: null
          ratio: 3.14
        """
        let result = try parseYAML(yaml)
        let arr = try #require(result as? [[String: Any]])
        #expect(arr.count == 1)
        let first = arr[0]
        #expect(first["name"] as? String == "foo")
        #expect(first["count"] as? Int == 42)
        #expect(first["flag"] as? Bool == true)
        #expect(first["nothing"] is NSNull)
        #expect(first["ratio"] as? Double == 3.14)
    }

    @Test func flowSequence() throws {
        let yaml = "items: [Text, Button, Image]\n"
        let result = try parseYAML(yaml)
        let dict = try #require(result as? [String: Any])
        let items = try #require(dict["items"] as? [Any])
        #expect(items.count == 3)
        #expect(items[0] as? String == "Text")
    }

    @Test func flowMapping() throws {
        let yaml = "obj: {type: object, title: foo}\n"
        let result = try parseYAML(yaml)
        let dict = try #require(result as? [String: Any])
        let obj = try #require(dict["obj"] as? [String: Any])
        #expect(obj["type"] as? String == "object")
    }
}
