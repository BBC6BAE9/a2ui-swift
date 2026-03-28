// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import TravelApp

/// Tests for `BookingService`, `HotelListing`, and `ListHotelsTool`.
///
/// Mirrors Flutter's `tools/hotels/list_hotels_tool_test.dart`.
final class BookingServiceTests: XCTestCase {

    private func makeSearch() -> HotelSearch {
        HotelSearch.fromJson([
            "query": "Sunnyvale hotels",
            "checkIn": "2025-08-01",
            "checkOut": "2025-08-08",
            "guests": 2,
        ])
    }

    func testListHotelsReturnsResults() async {
        let result = await BookingService.instance.listHotels(makeSearch())
        XCTAssertEqual(result.listings.count, 2)
    }

    func testListHotelsSyncReturnsResults() {
        let result = BookingService.instance.listHotelsSync(makeSearch())
        XCTAssertEqual(result.listings.count, 2)
    }

    func testListHotelsResultsHaveRequiredFields() {
        let result = BookingService.instance.listHotelsSync(
            HotelSearch.fromJson([
                "query": "test",
                "checkIn": "2025-07-01",
                "checkOut": "2025-07-05",
                "guests": 1,
            ])
        )

        for listing in result.listings {
            XCTAssertFalse(listing.name.isEmpty)
            XCTAssertFalse(listing.location.isEmpty)
            XCTAssertFalse(listing.imageName.isEmpty)
            XCTAssertFalse(listing.listingSelectionId.isEmpty)
        }
    }

    func testToAiInputHasExpectedKeys() {
        let result = BookingService.instance.listHotelsSync(makeSearch())
        let aiInput = result.toAiInput()
        let listings = aiInput["listings"] as? [[String: Any]]
        XCTAssertNotNil(listings)
        for item in listings ?? [] {
            XCTAssertNotNil(item["description"] as? String)
            XCTAssertNotNil(item["images"] as? [String])
            XCTAssertNotNil(item["listingSelectionId"] as? String)
        }
    }

    func testListingsAreRemembered() {
        let result = BookingService.instance.listHotelsSync(
            HotelSearch.fromJson([
                "query": "test",
                "checkIn": "2025-06-01",
                "checkOut": "2025-06-10",
                "guests": 2,
            ])
        )

        for listing in result.listings {
            let retrieved = BookingService.instance.listing(for: listing.listingSelectionId)
            XCTAssertNotNil(retrieved, "Listing should be retrievable by selectionId")
            XCTAssertEqual(retrieved?.listingSelectionId, listing.listingSelectionId)
        }
    }

    func testHotelListingDescription() {
        let listing = HotelListing(
            id: "1",
            listingSelectionId: "sel-1",
            name: "The Dart Inn",
            location: "Sunnyvale, CA",
            pricePerNight: 150,
            imageName: "dart_inn.png",
            checkIn: Date(),
            checkOut: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            guests: 2
        )
        XCTAssertEqual(listing.description, "The Dart Inn in Sunnyvale, CA, $150")
    }

    func testHotelListingNightsCalculation() {
        let checkIn = Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 1))!
        let checkOut = Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 5))!

        let listing = HotelListing(
            id: "1",
            listingSelectionId: "sel-1",
            name: "Test Hotel",
            location: "Test",
            pricePerNight: 100,
            imageName: "test.png",
            checkIn: checkIn,
            checkOut: checkOut,
            guests: 1
        )
        XCTAssertEqual(listing.nights, 4)
        XCTAssertEqual(listing.totalPrice, 400)
    }

    func testListingSelectionIdsAreUnique() {
        let result = BookingService.instance.listHotelsSync(
            HotelSearch.fromJson([
                "query": "test",
                "checkIn": "2025-09-01",
                "checkOut": "2025-09-05",
                "guests": 1,
            ])
        )
        let ids = result.listings.map(\.listingSelectionId)
        XCTAssertEqual(ids.count, Set(ids).count, "Selection IDs should be unique")
    }

    func testHotelSearchFromJson() {
        let search = HotelSearch.fromJson([
            "query": "Tokyo hotels",
            "checkIn": "2025-10-01",
            "checkOut": "2025-10-05",
            "guests": 3,
        ])
        XCTAssertEqual(search.query, "Tokyo hotels")
        XCTAssertEqual(search.guests, 3)
    }

    func testListHotelsToolInvoke() async throws {
        let tool = ListHotelsTool(onListHotels: { search in
            await BookingService.instance.listHotels(search)
        })
        XCTAssertEqual(tool.name, "listHotels")

        let result = try await tool.invoke([
            "query": "test",
            "checkIn": "2025-12-01",
            "checkOut": "2025-12-05",
            "guests": 2,
        ])
        let listings = result["listings"] as? [[String: Any]]
        XCTAssertNotNil(listings)
        XCTAssertEqual(listings?.count, 2)
    }
}
