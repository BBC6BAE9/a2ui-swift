// Copyright 2025 GenUI Authors.

import XCTest
@testable import Primitives
/// A custom part type for testing extensibility.
struct CustomPart: Part, Sendable {
    let customField: String

    func toJson() -> [String: Any?] {
        return [
            "type": "Custom",
            "content": ["customField": customField],
        ]
    }

    static func == (lhs: CustomPart, rhs: CustomPart) -> Bool {
        lhs.customField == rhs.customField
    }
}

/// A converter for CustomPart.
func customPartConverter(_ json: [String: Any?]) throws -> any Part {
    guard let type = json["type"] as? String, type == "Custom" else {
        throw PartError.unknownType(json["type"] as? String ?? "nil")
    }
    guard let content = json["content"] as? [String: Any?],
          let customField = content["customField"] as? String else {
        throw PartError.invalidFormat("CustomPart requires 'customField'")
    }
    return CustomPart(customField: customField)
}

final class CustomPartTests: XCTestCase {

    func testRoundTripSerializationWithCustomType() throws {
        let originalPart = CustomPart(customField: "custom_value")

        // Serialize
        let json = originalPart.toJson()
        XCTAssertEqual(json["type"] as? String, "Custom")
        let content = json["content"] as? [String: Any?]
        XCTAssertEqual(content?["customField"] as? String, "custom_value")

        // Deserialize using partFromJson with custom converter
        let reconstructedPart = try partFromJson(
            json,
            converterRegistry: ["Custom": customPartConverter]
        )

        XCTAssertTrue(reconstructedPart is CustomPart)
        XCTAssertEqual(
            (reconstructedPart as! CustomPart).customField,
            "custom_value"
        )
        XCTAssertEqual(reconstructedPart as! CustomPart, originalPart)
    }

    func testPartFromJsonThrowsForCustomType() {
        let json: [String: Any?] = [
            "type": "Custom",
            "content": ["customField": "val"],
        ]

        XCTAssertThrowsError(
            try partFromJson(json, converterRegistry: defaultPartConverterRegistry)
        ) { error in
            XCTAssertTrue(error is PartError)
        }
    }

    func testPartFromJsonHandlesStandardTypesWithCustomConverter() throws {
        let textPart = StandardPart.text("hello")
        let json = textPart.toJson()

        // Merge default + custom registry
        var registry = defaultPartConverterRegistry
        registry["Custom"] = customPartConverter

        let reconstructed = try partFromJson(json, converterRegistry: registry)
        XCTAssertEqual(reconstructed as! StandardPart, textPart)
    }
}
