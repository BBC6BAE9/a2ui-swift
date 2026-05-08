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

import A2UISwiftCore
import Foundation
import Testing

@testable import A2UISwiftUI

// MARK: - T1: Field decoding

@Suite("T1: TextFieldProperties validationRegexp decoding")
struct TextFieldPropertiesDecodingTests {

    @Test("decodes validationRegexp when present")
    func decodesValidationRegexp() throws {
        let json = #"{"value":"","validationRegexp":"\\d+"}"#.data(using: .utf8)!
        let props = try JSONDecoder().decode(TextFieldProperties.self, from: json)
        #expect(props.validationRegexp == "\\d+")
    }

    @Test("validationRegexp is nil when absent")
    func validationRegexpNilWhenAbsent() throws {
        let json = #"{"value":""}"#.data(using: .utf8)!
        let props = try JSONDecoder().decode(TextFieldProperties.self, from: json)
        #expect(props.validationRegexp == nil)
    }
}

// MARK: - T2: Empty / nil pass-through

@Suite("T2: regexpValidationMessage — empty / nil pass-through")
struct RegexpValidationMessagePassThroughTests {

    @Test("nil pattern always passes")
    func nilPatternPasses() {
        #expect(A2UITextFieldView.regexpValidationMessage(value: "hello", pattern: nil) == nil)
    }

    @Test("empty pattern always passes")
    func emptyPatternPasses() {
        #expect(A2UITextFieldView.regexpValidationMessage(value: "hello", pattern: "") == nil)
    }

    @Test("empty value passes regardless of pattern")
    func emptyValuePasses() {
        #expect(A2UITextFieldView.regexpValidationMessage(value: "", pattern: "\\d+") == nil)
    }
}

// MARK: - T3: Whole-string match semantics

@Suite("T3: regexpValidationMessage — whole-string match semantics")
struct RegexpValidationMessageWholeMatchTests {

    @Test("full match passes")
    func fullMatchPasses() {
        #expect(A2UITextFieldView.regexpValidationMessage(value: "hello", pattern: "[a-z]+") == nil)
    }

    @Test("partial match fails (no full-string match)")
    func partialMatchFails() {
        #expect(
            A2UITextFieldView.regexpValidationMessage(value: "hello123", pattern: "[a-z]+")
                == "Invalid format"
        )
    }

    @Test("substring present but not full-string match fails (firstMatch trap)")
    func substringNotFullStringFails() {
        // \d+ would pass with firstMatch("abc123") but must fail with wholeMatch
        #expect(
            A2UITextFieldView.regexpValidationMessage(value: "abc123", pattern: "\\d+")
                == "Invalid format"
        )
    }
}

// MARK: - T4: Malformed regex — fail-closed

@Suite("T4: regexpValidationMessage — malformed regex fail-closed")
struct RegexpValidationMessageFailClosedTests {

    @Test("malformed regex returns Invalid format, not nil")
    func malformedRegexFailClosed() {
        // Must NOT silently pass — must be treated as invalid input
        #expect(
            A2UITextFieldView.regexpValidationMessage(value: "hello", pattern: "[invalid")
                == "Invalid format"
        )
    }
}

// MARK: - T5: checks vs validationRegexp priority

@Suite("T5: displayedValidationMessage — checks priority over regexp")
struct DisplayedValidationMessagePriorityTests {

    @Test("checksErrorMessage wins when both are non-nil")
    func checksTakesPriority() {
        let result = A2UITextFieldView.displayedValidationMessage(
            checksErrorMessage: "Must be a valid email",
            value: "abc123",
            pattern: "\\d+"  // would also fail
        )
        #expect(result == "Must be a valid email")
    }

    @Test("regexp error shown when checks passes")
    func regexpShownWhenChecksNil() {
        let result = A2UITextFieldView.displayedValidationMessage(
            checksErrorMessage: nil,
            value: "abc123",
            pattern: "\\d+"
        )
        #expect(result == "Invalid format")
    }

    @Test("nil when both pass")
    func nilWhenBothPass() {
        let result = A2UITextFieldView.displayedValidationMessage(
            checksErrorMessage: nil,
            value: "123",
            pattern: "\\d+"
        )
        #expect(result == nil)
    }

    @Test("nil when both are nil / empty-pattern")
    func nilWhenNoRules() {
        let result = A2UITextFieldView.displayedValidationMessage(
            checksErrorMessage: nil,
            value: "anything",
            pattern: nil
        )
        #expect(result == nil)
    }
}
