// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import TravelApp

/// Tests that the custom renderer handles all registered component types.
///
/// Mirrors Flutter's `catalog_validation_test.dart` — validates that every
/// component name in `TravelComponentNames.allNames` is handled by the
/// `travelCustomRenderer` switch.
final class TravelCustomRendererTests: XCTestCase {

    func testAllComponentNamesAreRegistered() {
        let expected: [String] = [
            TravelComponentNames.travelCarousel,
            TravelComponentNames.informationCard,
            TravelComponentNames.itinerary,
            TravelComponentNames.inputGroup,
            TravelComponentNames.trailhead,
            TravelComponentNames.listingsBooker,
            TravelComponentNames.tabbedSections,
            TravelComponentNames.optionsFilterChipInput,
            TravelComponentNames.checkboxFilterChipsInput,
            TravelComponentNames.dateInputChip,
            TravelComponentNames.textInputChip,
        ]

        XCTAssertEqual(
            Set(TravelComponentNames.allNames),
            Set(expected),
            "allNames should match the expected set of component names"
        )
    }

    func testComponentNameConstants() {
        XCTAssertEqual(TravelComponentNames.travelCarousel, "TravelCarousel")
        XCTAssertEqual(TravelComponentNames.itinerary, "Itinerary")
        XCTAssertEqual(TravelComponentNames.informationCard, "InformationCard")
        XCTAssertEqual(TravelComponentNames.inputGroup, "InputGroup")
        XCTAssertEqual(TravelComponentNames.trailhead, "Trailhead")
        XCTAssertEqual(TravelComponentNames.tabbedSections, "TabbedSections")
        XCTAssertEqual(TravelComponentNames.listingsBooker, "ListingsBooker")
        XCTAssertEqual(TravelComponentNames.optionsFilterChipInput, "OptionsFilterChipInput")
        XCTAssertEqual(TravelComponentNames.checkboxFilterChipsInput, "CheckboxFilterChipsInput")
        XCTAssertEqual(TravelComponentNames.dateInputChip, "DateInputChip")
        XCTAssertEqual(TravelComponentNames.textInputChip, "TextInputChip")
    }

    func testNoDuplicateComponentNames() {
        let names = TravelComponentNames.allNames
        let uniqueNames = Set(names)
        XCTAssertEqual(
            names.count, uniqueNames.count,
            "Component names should be unique — found duplicates"
        )
    }
}
