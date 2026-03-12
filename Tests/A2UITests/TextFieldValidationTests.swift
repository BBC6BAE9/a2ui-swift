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

/// Unit tests for TextField regex validation logic (Rule 6: key logic must have test coverage).
final class TextFieldValidationTests: XCTestCase {

    // MARK: - No pattern (nil / empty)

    func testNilPatternAlwaysValid() {
        XCTAssertTrue(A2UITextFieldView.isValid(value: "", pattern: nil))
        XCTAssertTrue(A2UITextFieldView.isValid(value: "anything", pattern: nil))
    }

    func testEmptyPatternAlwaysValid() {
        XCTAssertTrue(A2UITextFieldView.isValid(value: "", pattern: ""))
        XCTAssertTrue(A2UITextFieldView.isValid(value: "anything", pattern: ""))
    }

    // MARK: - Empty value (always valid — user hasn't typed yet)

    func testEmptyValueAlwaysValidRegardlessOfPattern() {
        XCTAssertTrue(A2UITextFieldView.isValid(value: "", pattern: "^\\d+$"))
        XCTAssertTrue(A2UITextFieldView.isValid(value: "", pattern: "^[a-z]+$"))
    }

    // MARK: - Matching patterns

    func testEmailPatternMatches() {
        let email = "^[\\w.+-]+@[\\w-]+\\.[a-zA-Z]{2,}$"
        XCTAssertTrue(A2UITextFieldView.isValid(value: "jane@example.com", pattern: email))
        XCTAssertTrue(A2UITextFieldView.isValid(value: "a+b@c.co", pattern: email))
    }

    func testEmailPatternRejects() {
        let email = "^[\\w.+-]+@[\\w-]+\\.[a-zA-Z]{2,}$"
        XCTAssertFalse(A2UITextFieldView.isValid(value: "not-an-email", pattern: email))
        XCTAssertFalse(A2UITextFieldView.isValid(value: "@missing.com", pattern: email))
    }

    func testDigitsOnlyPattern() {
        let digits = "^\\d+$"
        XCTAssertTrue(A2UITextFieldView.isValid(value: "12345", pattern: digits))
        XCTAssertFalse(A2UITextFieldView.isValid(value: "123abc", pattern: digits))
        XCTAssertFalse(A2UITextFieldView.isValid(value: "abc", pattern: digits))
    }

    // MARK: - Invalid regex (graceful handling)

    func testInvalidRegexTreatsAsInvalid() {
        // A malformed regex should not crash — `try? Regex(...)` returns nil → not valid
        XCTAssertFalse(A2UITextFieldView.isValid(value: "hello", pattern: "[invalid"))
    }
}
