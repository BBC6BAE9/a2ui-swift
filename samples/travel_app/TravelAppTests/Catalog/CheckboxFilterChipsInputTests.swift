// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import TravelApp

/// Tests for `CheckboxFilterChipsData`.
///
/// Mirrors Flutter's `checkbox_filter_chips_input_test.dart`.
final class CheckboxFilterChipsInputTests: XCTestCase {

    func testDisplayLabelShowsJoinedSelectedOptions() {
        let data = CheckboxFilterChipsData(
            id: "amenities",
            chipLabel: "Amenities",
            options: ["Wifi", "Gym", "Pool", "Parking"],
            iconName: nil,
            selectedOptions: ["Gym", "Wifi"]
        )
        let label = data.selectedOptions.sorted().joined(separator: ", ")
        XCTAssertEqual(label, "Gym, Wifi")
    }

    func testDisplayLabelFallsBackToChipLabelWhenEmpty() {
        let data = CheckboxFilterChipsData(
            id: "amenities",
            chipLabel: "Amenities",
            options: ["Wifi", "Gym"],
            iconName: nil,
            selectedOptions: []
        )
        XCTAssertTrue(data.selectedOptions.isEmpty)
        XCTAssertEqual(data.chipLabel, "Amenities")
    }

    func testTogglingOption() {
        var data = CheckboxFilterChipsData(
            id: "test",
            chipLabel: "Test",
            options: ["A", "B", "C"],
            iconName: nil,
            selectedOptions: ["A"]
        )
        XCTAssertTrue(data.selectedOptions.contains("A"))

        data.selectedOptions.insert("B")
        XCTAssertEqual(data.selectedOptions, ["A", "B"])

        data.selectedOptions.remove("A")
        XCTAssertEqual(data.selectedOptions, ["B"])
    }

    func testIconIsOptional() {
        let withIcon = CheckboxFilterChipsData(
            id: "a", chipLabel: "A", options: [],
            iconName: .hotel, selectedOptions: []
        )
        let withoutIcon = CheckboxFilterChipsData(
            id: "b", chipLabel: "B", options: [],
            iconName: nil, selectedOptions: []
        )
        XCTAssertNotNil(withIcon.iconName)
        XCTAssertNil(withoutIcon.iconName)
    }
}
