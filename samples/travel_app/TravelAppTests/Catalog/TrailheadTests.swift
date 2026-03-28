// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import TravelApp

/// Tests for `TrailheadData`.
///
/// Mirrors Flutter's `trailhead_test.dart`.
final class TrailheadTests: XCTestCase {

    func testTrailheadDataCreation() {
        let data = TrailheadData(
            topics: ["Beach vacation", "City tours", "Mountain hiking"],
            actionName: "selectTopic"
        )

        XCTAssertEqual(data.topics.count, 3)
        XCTAssertEqual(data.topics[0], "Beach vacation")
        XCTAssertEqual(data.topics[1], "City tours")
        XCTAssertEqual(data.topics[2], "Mountain hiking")
        XCTAssertEqual(data.actionName, "selectTopic")
    }

    func testEmptyTopics() {
        let data = TrailheadData(topics: [], actionName: "noTopics")
        XCTAssertTrue(data.topics.isEmpty)
    }

    func testTopicLabelsPreserved() {
        let topics = ["🏖 Beach", "⛰ Mountain", "🏛 Cultural"]
        let data = TrailheadData(topics: topics, actionName: "pick")

        for (index, topic) in topics.enumerated() {
            XCTAssertEqual(data.topics[index], topic)
        }
    }
}
