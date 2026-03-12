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

/// Unit tests for MultipleChoice pure logic (Rule 6: key logic must have test coverage).
///
/// Covers:
///   - toggle(): add, remove, single-select replacement, maxAllowed enforcement
///   - filter(): case-insensitive substring matching, empty query, no matches
final class MultipleChoiceLogicTests: XCTestCase {

    // MARK: - Toggle: basic add/remove

    func testToggleAddsValue() {
        let result = MultipleChoiceLogic.toggle(value: "B", in: ["A"], maxAllowed: nil)
        XCTAssertEqual(result, ["A", "B"])
    }

    func testToggleRemovesValue() {
        let result = MultipleChoiceLogic.toggle(value: "A", in: ["A", "B"], maxAllowed: nil)
        XCTAssertEqual(result, ["B"])
    }

    func testToggleEmptySelections() {
        let result = MultipleChoiceLogic.toggle(value: "A", in: [], maxAllowed: nil)
        XCTAssertEqual(result, ["A"])
    }

    func testToggleRemoveLastValue() {
        let result = MultipleChoiceLogic.toggle(value: "A", in: ["A"], maxAllowed: nil)
        XCTAssertEqual(result, [])
    }

    // MARK: - Toggle: single-select (maxAllowed == 1)

    func testSingleSelectReplacesValue() {
        let result = MultipleChoiceLogic.toggle(value: "B", in: ["A"], maxAllowed: 1)
        XCTAssertEqual(result, ["B"])
    }

    func testSingleSelectDeselectsCurrent() {
        let result = MultipleChoiceLogic.toggle(value: "A", in: ["A"], maxAllowed: 1)
        XCTAssertEqual(result, [])
    }

    func testSingleSelectFromEmpty() {
        let result = MultipleChoiceLogic.toggle(value: "A", in: [], maxAllowed: 1)
        XCTAssertEqual(result, ["A"])
    }

    // MARK: - Toggle: maxAllowed > 1

    func testMaxAllowedBlocksExcess() {
        let result = MultipleChoiceLogic.toggle(value: "C", in: ["A", "B"], maxAllowed: 2)
        XCTAssertEqual(result, ["A", "B"], "Should not add when at max")
    }

    func testMaxAllowedAllowsWhenBelowLimit() {
        let result = MultipleChoiceLogic.toggle(value: "B", in: ["A"], maxAllowed: 2)
        XCTAssertEqual(result, ["A", "B"])
    }

    func testMaxAllowedStillAllowsRemoval() {
        let result = MultipleChoiceLogic.toggle(value: "A", in: ["A", "B"], maxAllowed: 2)
        XCTAssertEqual(result, ["B"], "Should still allow removal when at max")
    }

    // MARK: - Filter: basic matching

    func testFilterEmptyQueryReturnsAll() {
        let options = [("Apple", "A"), ("Banana", "B")].map { (label: $0.0, value: $0.1) }
        let result = MultipleChoiceLogic.filter(options: options, query: "")
        XCTAssertEqual(result.count, 2)
    }

    func testFilterMatchesSubstring() {
        let options = [("Apple", "A"), ("Banana", "B"), ("Pineapple", "C")].map { (label: $0.0, value: $0.1) }
        let result = MultipleChoiceLogic.filter(options: options, query: "apple")
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map(\.value), ["A", "C"])
    }

    func testFilterCaseInsensitive() {
        let options = [("Swift", "swift"), ("Python", "python")].map { (label: $0.0, value: $0.1) }
        let result = MultipleChoiceLogic.filter(options: options, query: "SWIFT")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.value, "swift")
    }

    func testFilterNoMatches() {
        let options = [("Apple", "A"), ("Banana", "B")].map { (label: $0.0, value: $0.1) }
        let result = MultipleChoiceLogic.filter(options: options, query: "xyz")
        XCTAssertTrue(result.isEmpty)
    }

    func testFilterMatchesOnlyLabel() {
        let options = [(label: "Apple", value: "fruit_a")]
        let result = MultipleChoiceLogic.filter(options: options, query: "fruit")
        XCTAssertTrue(result.isEmpty, "Should only match label, not value")
    }
}
