// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import TravelApp

/// Tests for `OptionsFilterChipData`.
///
/// Mirrors Flutter's `options_filter_chip_input_test.dart`.
final class OptionsFilterChipInputTests: XCTestCase {

    func testDisplayLabelShowsChipLabelWhenNoValue() {
        let data = OptionsFilterChipData(
            id: "budget",
            chipLabel: "Budget",
            options: ["Low", "Medium", "High"],
            iconName: .wallet,
            value: nil
        )
        XCTAssertNil(data.value)
        XCTAssertEqual(data.chipLabel, "Budget")
    }

    func testDisplayLabelShowsSelectedValue() {
        let data = OptionsFilterChipData(
            id: "budget",
            chipLabel: "Budget",
            options: ["Low", "Medium", "High"],
            iconName: .wallet,
            value: "Medium"
        )
        XCTAssertEqual(data.value, "Medium")
    }

    func testIconIsOptional() {
        let withIcon = OptionsFilterChipData(
            id: "a", chipLabel: "A", options: [], iconName: .wallet, value: nil
        )
        let withoutIcon = OptionsFilterChipData(
            id: "b", chipLabel: "B", options: [], iconName: nil, value: nil
        )
        XCTAssertNotNil(withIcon.iconName)
        XCTAssertNil(withoutIcon.iconName)
    }

    func testMutatingValueUpdatesSelection() {
        var data = OptionsFilterChipData(
            id: "price",
            chipLabel: "Price",
            options: ["$", "$$", "$$$"],
            iconName: nil,
            value: nil
        )
        XCTAssertNil(data.value)

        data.value = "$$"
        XCTAssertEqual(data.value, "$$")
    }
}
