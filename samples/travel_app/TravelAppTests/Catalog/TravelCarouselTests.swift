// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import TravelApp

/// Tests for `TravelCarouselData` and `TravelCarouselItem`.
///
/// Mirrors Flutter's `travel_carousel_test.dart` — adapted from widget
/// tests to data model unit tests since SwiftUI views aren't directly
/// testable via XCTest without a UI testing framework.
final class TravelCarouselTests: XCTestCase {

    func testCarouselDataCreation() {
        let items = [
            TravelCarouselItem(
                description: "Santorini",
                imageName: "assets/travel_images/santorini.jpg",
                listingSelectionId: "sel-1",
                actionName: "selectItem"
            ),
            TravelCarouselItem(
                description: "Mykonos",
                imageName: "assets/travel_images/mykonos.jpg",
                listingSelectionId: nil,
                actionName: "selectItem"
            ),
        ]

        let data = TravelCarouselData(title: "Where to?", items: items)

        XCTAssertEqual(data.title, "Where to?")
        XCTAssertEqual(data.items.count, 2)
        XCTAssertEqual(data.items[0].description, "Santorini")
        XCTAssertEqual(data.items[1].description, "Mykonos")
    }

    func testCarouselItemImageNameExtraction() {
        let item = TravelCarouselItem(
            description: "Beach",
            imageName: "assets/travel_images/santorini_panorama.jpg",
            listingSelectionId: nil,
            actionName: "select"
        )

        let assetName = a2uiExtractAssetName(from: item.imageName)
        XCTAssertEqual(assetName, "santorini_panorama")
    }

    func testCarouselItemsHaveUniqueIds() {
        let item1 = TravelCarouselItem(
            description: "A", imageName: "a.jpg",
            listingSelectionId: nil, actionName: "tap"
        )
        let item2 = TravelCarouselItem(
            description: "B", imageName: "b.jpg",
            listingSelectionId: nil, actionName: "tap"
        )
        XCTAssertNotEqual(item1.id, item2.id)
    }

    func testCarouselOptionalTitle() {
        let data = TravelCarouselData(title: nil, items: [])
        XCTAssertNil(data.title)
        XCTAssertTrue(data.items.isEmpty)
    }

    func testCarouselItemListingSelectionId() {
        let withId = TravelCarouselItem(
            description: "Hotel", imageName: "h.jpg",
            listingSelectionId: "sel-123", actionName: "select"
        )
        let withoutId = TravelCarouselItem(
            description: "Hotel", imageName: "h.jpg",
            listingSelectionId: nil, actionName: "select"
        )
        XCTAssertEqual(withId.listingSelectionId, "sel-123")
        XCTAssertNil(withoutId.listingSelectionId)
    }
}
