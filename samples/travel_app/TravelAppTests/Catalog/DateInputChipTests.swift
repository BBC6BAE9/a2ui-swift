// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import TravelApp

/// Tests for `DateInputChipData` and date formatting logic.
///
/// Mirrors Flutter's `date_input_chip_test.dart`.
final class DateInputChipTests: XCTestCase {

    func testDisplayLabelWithNoValue() {
        let data = DateInputChipData(id: "checkin", value: nil, label: "Check-in")
        XCTAssertNil(data.value)
        XCTAssertEqual(data.label, "Check-in")
    }

    func testDisplayLabelWithDateValue() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: "2025-07-15")!

        let data = DateInputChipData(id: "checkin", value: date, label: "Check-in")
        XCTAssertNotNil(data.value)

        let formatted = date.formatted(date: .abbreviated, time: .omitted)
        XCTAssertFalse(formatted.isEmpty)
    }

    func testDateStringParsing() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let valid = formatter.date(from: "2025-12-25")
        XCTAssertNotNil(valid)

        let invalid = formatter.date(from: "not-a-date")
        XCTAssertNil(invalid)
    }

    func testDateFormatRoundTrip() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let original = "2025-08-20"
        let date = formatter.date(from: original)!
        let formatted = formatter.string(from: date)
        XCTAssertEqual(formatted, original)
    }

    func testMutatingDateValue() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var data = DateInputChipData(id: "checkout", value: nil, label: "Check-out")
        XCTAssertNil(data.value)

        data.value = formatter.date(from: "2025-09-01")
        XCTAssertNotNil(data.value)
    }
}
