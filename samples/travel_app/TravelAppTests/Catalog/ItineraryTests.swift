// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import TravelApp

/// Tests for `ItineraryData` and related models.
///
/// Mirrors Flutter's `itinerary_test.dart`.
final class ItineraryTests: XCTestCase {

    func testItineraryDataCreation() {
        let entry = ItineraryEntryData(
            title: "Visit Acropolis",
            bodyText: "Explore ancient ruins",
            time: "09:00",
            type: .activity,
            status: .noBookingRequired
        )
        let day = ItineraryDayData(
            title: "Day 1",
            subtitle: "Athens",
            description: "Explore the capital",
            imageName: "athens.jpg",
            entries: [entry]
        )
        let data = ItineraryData(
            title: "Greece Trip",
            subheading: "5 days, 4 nights",
            imageName: "greece.jpg",
            days: [day]
        )

        XCTAssertEqual(data.title, "Greece Trip")
        XCTAssertEqual(data.subheading, "5 days, 4 nights")
        XCTAssertEqual(data.days.count, 1)
        XCTAssertEqual(data.days[0].entries.count, 1)
    }

    func testItineraryEntryTypes() {
        XCTAssertEqual(ItineraryEntryType.accommodation.rawValue, "accommodation")
        XCTAssertEqual(ItineraryEntryType.transport.rawValue, "transport")
        XCTAssertEqual(ItineraryEntryType.activity.rawValue, "activity")
    }

    func testItineraryEntryTypeSystemImages() {
        XCTAssertEqual(ItineraryEntryType.accommodation.systemImageName, "bed.double.fill")
        XCTAssertEqual(ItineraryEntryType.transport.systemImageName, "tram.fill")
        XCTAssertEqual(ItineraryEntryType.activity.systemImageName, "figure.hiking")
    }

    func testItineraryEntryStatusValues() {
        XCTAssertEqual(ItineraryEntryStatus.noBookingRequired.rawValue, "noBookingRequired")
        XCTAssertEqual(ItineraryEntryStatus.choiceRequired.rawValue, "choiceRequired")
        XCTAssertEqual(ItineraryEntryStatus.chosen.rawValue, "chosen")
    }

    func testEntryOptionalFields() {
        let minimal = ItineraryEntryData(
            title: "Walk",
            bodyText: "A short walk",
            time: "10:00",
            type: .activity,
            status: .noBookingRequired
        )
        XCTAssertNil(minimal.subtitle)
        XCTAssertNil(minimal.address)
        XCTAssertNil(minimal.totalCost)
        XCTAssertNil(minimal.choiceRequiredAction)

        let full = ItineraryEntryData(
            title: "Hotel Check-in",
            subtitle: "Grand Hotel",
            bodyText: "Check in to the hotel",
            address: "123 Main St",
            time: "14:00",
            totalCost: "$200",
            type: .accommodation,
            status: .chosen
        )
        XCTAssertEqual(full.subtitle, "Grand Hotel")
        XCTAssertEqual(full.address, "123 Main St")
        XCTAssertEqual(full.totalCost, "$200")
    }

    func testDaysHaveUniqueIds() {
        let day1 = ItineraryDayData(
            title: "Day 1", subtitle: "", description: "",
            imageName: "", entries: []
        )
        let day2 = ItineraryDayData(
            title: "Day 2", subtitle: "", description: "",
            imageName: "", entries: []
        )
        XCTAssertNotEqual(day1.id, day2.id)
    }

    func testEntriesHaveUniqueIds() {
        let entry1 = ItineraryEntryData(
            title: "A", bodyText: "", time: "",
            type: .activity, status: .noBookingRequired
        )
        let entry2 = ItineraryEntryData(
            title: "B", bodyText: "", time: "",
            type: .activity, status: .noBookingRequired
        )
        XCTAssertNotEqual(entry1.id, entry2.id)
    }

    func testEntryTypeFromRawValue() {
        XCTAssertEqual(ItineraryEntryType(rawValue: "accommodation"), .accommodation)
        XCTAssertEqual(ItineraryEntryType(rawValue: "transport"), .transport)
        XCTAssertEqual(ItineraryEntryType(rawValue: "activity"), .activity)
        XCTAssertNil(ItineraryEntryType(rawValue: "unknown"))
    }
}
