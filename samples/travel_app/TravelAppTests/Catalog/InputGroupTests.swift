// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import TravelApp

/// Tests for `InputGroupData` and `InputChild`.
///
/// Mirrors Flutter's `input_group_test.dart`.
final class InputGroupTests: XCTestCase {

    func testInputGroupDataCreation() {
        let children: [InputChild] = [
            .optionsFilter(OptionsFilterChipData(
                id: "budget", chipLabel: "Budget",
                options: ["Low", "High"], iconName: .wallet, value: nil
            )),
            .dateInput(DateInputChipData(
                id: "checkin", value: nil, label: "Check-in"
            )),
        ]

        let data = InputGroupData(
            submitLabel: "Search",
            children: children,
            actionName: "submitSearch"
        )

        XCTAssertEqual(data.submitLabel, "Search")
        XCTAssertEqual(data.actionName, "submitSearch")
        XCTAssertEqual(data.children.count, 2)
    }

    func testInputChildIds() {
        let options = InputChild.optionsFilter(OptionsFilterChipData(
            id: "opt1", chipLabel: "Opt", options: [], iconName: nil, value: nil
        ))
        let checkbox = InputChild.checkboxFilter(CheckboxFilterChipsData(
            id: "chk1", chipLabel: "Chk", options: [], iconName: nil, selectedOptions: []
        ))
        let date = InputChild.dateInput(DateInputChipData(
            id: "date1", value: nil, label: "Date"
        ))
        let text = InputChild.textInput(TextInputChipData(
            id: "text1", label: "Text", value: nil, obscured: false
        ))

        XCTAssertEqual(options.id, "opt1")
        XCTAssertEqual(checkbox.id, "chk1")
        XCTAssertEqual(date.id, "date1")
        XCTAssertEqual(text.id, "text1")
    }

    func testEmptyChildrenStillHasSubmitLabel() {
        let data = InputGroupData(
            submitLabel: "Go",
            children: [],
            actionName: "go"
        )
        XCTAssertTrue(data.children.isEmpty)
        XCTAssertEqual(data.submitLabel, "Go")
    }

    func testMutatingChildren() {
        var data = InputGroupData(
            submitLabel: "Submit",
            children: [
                .optionsFilter(OptionsFilterChipData(
                    id: "a", chipLabel: "A", options: ["X", "Y"],
                    iconName: nil, value: nil
                )),
            ],
            actionName: "submit"
        )

        XCTAssertEqual(data.children.count, 1)

        var chipData = OptionsFilterChipData(
            id: "a", chipLabel: "A", options: ["X", "Y"],
            iconName: nil, value: "X"
        )
        chipData.value = "Y"
        data.children[0] = .optionsFilter(chipData)

        if case .optionsFilter(let updated) = data.children[0] {
            XCTAssertEqual(updated.value, "Y")
        } else {
            XCTFail("Expected optionsFilter child")
        }
    }
}
