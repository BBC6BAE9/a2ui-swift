// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest
@testable import A2UI

final class PrimitivesTests: XCTestCase {

    // MARK: - StringValue Decoding

    func testStringValueDecodesV09ShortForm() throws {
        // v0.9 allows bare string: "Hello"
        let json = Data(#""Hello""#.utf8)
        let value = try JSONDecoder().decode(StringValue.self, from: json)
        XCTAssertEqual(value.literalString, "Hello")
        XCTAssertNil(value.path)
    }

    func testStringValueDecodesV08DictForm() throws {
        // v0.8: {"literalString":"World","path":"name"}
        let json = Data(#"{"literalString":"World","path":"name"}"#.utf8)
        let value = try JSONDecoder().decode(StringValue.self, from: json)
        XCTAssertEqual(value.literalString, "World")
        XCTAssertEqual(value.path, "name")
    }

    func testStringValueDecodesLiteralOnly() throws {
        let json = Data(#"{"literal":"fallback"}"#.utf8)
        let value = try JSONDecoder().decode(StringValue.self, from: json)
        XCTAssertEqual(value.literal, "fallback")
        XCTAssertEqual(value.literalValue, "fallback")
        XCTAssertNil(value.path)
    }

    func testStringValueRoundTrip() throws {
        let original = StringValue(path: "user", literalString: "fallback")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StringValue.self, from: data)
        XCTAssertEqual(decoded.path, "user")
        XCTAssertEqual(decoded.literalString, "fallback")
    }

    // MARK: - NumberValue Decoding

    func testNumberValueDecodesV09ShortForm() throws {
        let json = Data("42.5".utf8)
        let value = try JSONDecoder().decode(NumberValue.self, from: json)
        XCTAssertEqual(value.literalNumber, 42.5)
        XCTAssertNil(value.path)
    }

    func testNumberValueDecodesV08DictForm() throws {
        let json = Data(#"{"literalNumber":99,"path":"score"}"#.utf8)
        let value = try JSONDecoder().decode(NumberValue.self, from: json)
        XCTAssertEqual(value.literalNumber, 99)
        XCTAssertEqual(value.path, "score")
    }

    func testNumberValueRoundTrip() throws {
        let original = NumberValue(path: "count", literalNumber: 7)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NumberValue.self, from: data)
        XCTAssertEqual(decoded.path, "count")
        XCTAssertEqual(decoded.literalNumber, 7)
    }

    // MARK: - BooleanValue Decoding

    func testBooleanValueDecodesV09ShortForm() throws {
        let json = Data("true".utf8)
        let value = try JSONDecoder().decode(BooleanValue.self, from: json)
        XCTAssertEqual(value.literalBoolean, true)
        XCTAssertNil(value.path)
    }

    func testBooleanValueDecodesV08DictForm() throws {
        let json = Data(#"{"literalBoolean":false,"path":"active"}"#.utf8)
        let value = try JSONDecoder().decode(BooleanValue.self, from: json)
        XCTAssertEqual(value.literalBoolean, false)
        XCTAssertEqual(value.path, "active")
    }

    func testBooleanValueRoundTrip() throws {
        let original = BooleanValue(path: "flag", literalBoolean: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BooleanValue.self, from: data)
        XCTAssertEqual(decoded.path, "flag")
        XCTAssertEqual(decoded.literalBoolean, true)
    }

    // MARK: - Edge Cases

    func testStringValueDecodesUnexpectedType() throws {
        // Array input — should produce empty StringValue, not crash
        let json = Data("[1,2,3]".utf8)
        let value = try JSONDecoder().decode(StringValue.self, from: json)
        XCTAssertNil(value.path)
        XCTAssertNil(value.literalString)
    }

    func testNumberValueDecodesUnexpectedType() throws {
        let json = Data(#""not a number""#.utf8)
        let value = try JSONDecoder().decode(NumberValue.self, from: json)
        XCTAssertNil(value.literalNumber)
        XCTAssertNil(value.path)
    }

    func testBooleanValueDecodesUnexpectedType() throws {
        let json = Data("123".utf8)
        let value = try JSONDecoder().decode(BooleanValue.self, from: json)
        XCTAssertNil(value.literalBoolean)
        XCTAssertNil(value.path)
    }

    func testLiteralValueComputedProperties() {
        let sv = StringValue(literalString: "a", literal: "b")
        XCTAssertEqual(sv.literalValue, "a", "literalString takes precedence over literal")

        let sv2 = StringValue(literal: "b")
        XCTAssertEqual(sv2.literalValue, "b")

        let nv = NumberValue(path: nil, literalNumber: 1, literal: 2)
        XCTAssertEqual(nv.literalValue, 1)

        let bv = BooleanValue(path: nil, literalBoolean: nil, literal: true)
        XCTAssertEqual(bv.literalValue, true)
    }
}
