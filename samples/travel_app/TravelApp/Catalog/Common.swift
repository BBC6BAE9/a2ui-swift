// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI

// MARK: - TravelIcon

/// Icon set matching the Flutter `TravelIcon` enum in `common.dart`.
enum TravelIcon: String, CaseIterable {
    case location, hotel, restaurant, airport, train, car
    case date, time, calendar, people, person, family
    case wallet, receipt

    var systemImageName: String {
        switch self {
        case .location: return "mappin.and.ellipse"
        case .hotel: return "bed.double.fill"
        case .restaurant: return "fork.knife"
        case .airport: return "airplane"
        case .train: return "tram.fill"
        case .car: return "car.fill"
        case .date: return "calendar"
        case .time: return "clock"
        case .calendar: return "calendar"
        case .people: return "person.2.fill"
        case .person: return "person.fill"
        case .family: return "figure.2.and.child.holdinghands"
        case .wallet: return "creditcard.fill"
        case .receipt: return "doc.text.fill"
        }
    }
}

// MARK: - TravelComponentNames

/// Custom component type names matching the Flutter travel catalog.
enum TravelComponentNames {
    static let travelCarousel = "TravelCarousel"
    static let itinerary = "Itinerary"
    static let informationCard = "InformationCard"
    static let inputGroup = "InputGroup"
    static let trailhead = "Trailhead"
    static let tabbedSections = "TabbedSections"
    static let listingsBooker = "ListingsBooker"
    static let optionsFilterChipInput = "OptionsFilterChipInput"
    static let checkboxFilterChipsInput = "CheckboxFilterChipsInput"
    static let dateInputChip = "DateInputChip"
    static let textInputChip = "TextInputChip"

    static let allNames: [String] = [
        travelCarousel,
        itinerary,
        informationCard,
        inputGroup,
        trailhead,
        tabbedSections,
        listingsBooker,
        optionsFilterChipInput,
        checkboxFilterChipsInput,
        dateInputChip,
        textInputChip,
    ]
}

// MARK: - Helpers

/// Extracts a Swift asset catalog name from a path or literal string.
/// Converts Flutter-style paths like `assets/travel_images/santorini_panorama.jpg`
/// to the last path component without extension for use with `Image(_:)`.
func a2uiExtractAssetName(from pathOrName: String) -> String {
    let last = pathOrName.split(separator: "/").last.map(String.init) ?? pathOrName
    if let dot = last.lastIndex(of: ".") {
        return String(last[..<dot])
    }
    return last
}

/// Parses inline Markdown (bold, italic, code, links) into an `AttributedString`.
/// Falls back to plain text if parsing fails.
func markdownAttributed(_ string: String) -> AttributedString {
    (try? AttributedString(
        markdown: string,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(string)
}
