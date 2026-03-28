// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import TravelApp

/// Tests for shared travel catalog helpers in `Common.swift`.
final class CommonTests: XCTestCase {

    // MARK: - TravelIcon

    func testTravelIconAllCasesHaveSystemImageNames() {
        for icon in TravelIcon.allCases {
            XCTAssertFalse(
                icon.systemImageName.isEmpty,
                "\(icon) should have a non-empty system image name"
            )
        }
    }

    func testTravelIconKnownMappings() {
        XCTAssertEqual(TravelIcon.location.systemImageName, "mappin.and.ellipse")
        XCTAssertEqual(TravelIcon.hotel.systemImageName, "bed.double.fill")
        XCTAssertEqual(TravelIcon.wallet.systemImageName, "creditcard.fill")
        XCTAssertEqual(TravelIcon.airport.systemImageName, "airplane")
    }

    func testTravelIconRawValueRoundTrip() {
        for icon in TravelIcon.allCases {
            XCTAssertEqual(TravelIcon(rawValue: icon.rawValue), icon)
        }
    }

    // MARK: - TravelComponentNames

    func testAllNamesContainsExpectedComponents() {
        let expected = [
            "TravelCarousel", "Itinerary", "InformationCard",
            "InputGroup", "Trailhead", "TabbedSections", "ListingsBooker",
            "OptionsFilterChipInput", "CheckboxFilterChipsInput",
            "DateInputChip", "TextInputChip",
        ]
        for name in expected {
            XCTAssertTrue(
                TravelComponentNames.allNames.contains(name),
                "allNames should contain \(name)"
            )
        }
        XCTAssertEqual(TravelComponentNames.allNames.count, expected.count)
    }

    // MARK: - a2uiExtractAssetName

    func testExtractAssetNameFromFlutterPath() {
        let result = a2uiExtractAssetName(from: "assets/travel_images/santorini_panorama.jpg")
        XCTAssertEqual(result, "santorini_panorama")
    }

    func testExtractAssetNameFromPlainName() {
        XCTAssertEqual(a2uiExtractAssetName(from: "santorini_panorama"), "santorini_panorama")
    }

    func testExtractAssetNameFromNameWithExtension() {
        XCTAssertEqual(a2uiExtractAssetName(from: "photo.png"), "photo")
    }

    func testExtractAssetNameFromNestedPath() {
        XCTAssertEqual(
            a2uiExtractAssetName(from: "a/b/c/image.webp"),
            "image"
        )
    }

    // MARK: - markdownAttributed

    func testMarkdownAttributedPlainText() {
        let result = markdownAttributed("Hello world")
        XCTAssertEqual(String(result.characters), "Hello world")
    }

    func testMarkdownAttributedWithBold() {
        let result = markdownAttributed("Hello **world**")
        XCTAssertEqual(String(result.characters), "Hello world")
    }

    func testMarkdownAttributedEmptyString() {
        let result = markdownAttributed("")
        XCTAssertEqual(String(result.characters), "")
    }
}
