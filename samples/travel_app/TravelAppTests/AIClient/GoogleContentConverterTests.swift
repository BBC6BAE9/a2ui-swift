// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
import Primitives@testable import TravelApp

/// Tests for `GoogleContentConverter`.
///
/// Mirrors Flutter's `google_content_converter_test.dart`.
final class GoogleContentConverterTests: XCTestCase {

    /// Mirrors Flutter test: "converts interaction json to text"
    ///
    /// DataPart with `application/vnd.genui.interaction+json` should be
    /// converted to a Gemini text part (not inlineData).
    func testConvertsInteractionJsonToText() throws {
        let interactionData: [String: Any] = ["foo": "bar"]
        let jsonData = try JSONSerialization.data(
            withJSONObject: interactionData,
            options: [.sortedKeys]
        )

        let message = Primitives.ChatMessage(
            role: .user,
            parts: [
                .data(DataPartContent(
                    bytes: jsonData,
                    mimeType: "application/vnd.genui.interaction+json"
                )),
            ]
        )

        let result = GoogleContentConverter.toGeminiContents([message])

        XCTAssertEqual(result.count, 1)
        let content = result[0]
        XCTAssertEqual(content["role"] as? String, "user")

        let parts = content["parts"] as? [[String: Any]]
        XCTAssertNotNil(parts)
        XCTAssertEqual(parts?.count, 1)

        let part = parts![0]
        let expectedJson = String(data: jsonData, encoding: .utf8)!
        XCTAssertEqual(part["text"] as? String, expectedJson)
        XCTAssertNil(part["inlineData"])
    }

    /// Mirrors Flutter test: "converts other mime types to blobs"
    ///
    /// DataPart with `image/png` should be converted to a Gemini inlineData
    /// part (blob), not a text part.
    func testConvertsOtherMimeTypesToBlobs() {
        let bytes = Data([1, 2, 3])

        let message = Primitives.ChatMessage(
            role: .user,
            parts: [
                .data(DataPartContent(
                    bytes: bytes,
                    mimeType: "image/png"
                )),
            ]
        )

        let result = GoogleContentConverter.toGeminiContents([message])

        XCTAssertEqual(result.count, 1)
        let content = result[0]
        XCTAssertEqual(content["role"] as? String, "user")

        let parts = content["parts"] as? [[String: Any]]
        XCTAssertNotNil(parts)
        XCTAssertEqual(parts?.count, 1)

        let part = parts![0]
        XCTAssertNil(part["text"])

        let inlineData = part["inlineData"] as? [String: Any]
        XCTAssertNotNil(inlineData)
        XCTAssertEqual(inlineData?["mimeType"] as? String, "image/png")

        let base64 = inlineData?["data"] as? String
        XCTAssertNotNil(base64)
        XCTAssertEqual(Data(base64Encoded: base64!), bytes)
    }
}
