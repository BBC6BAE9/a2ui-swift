// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/// Protocol for any bookable listing.
/// Mirrors Flutter's `Listing` abstract class in `tools/booking/model.dart`.
protocol Listing {
    var listingSelectionId: String { get }
}

/// Result of a hotel search containing matching listings.
/// Mirrors Flutter's `HotelSearchResult` in `tools/booking/model.dart`.
struct HotelSearchResult {
    let listings: [HotelListing]

    static func fromJson(_ json: [String: Any]) -> HotelSearchResult {
        let listingsArray = json["listings"] as? [[String: Any]] ?? []
        return HotelSearchResult(
            listings: listingsArray.map { HotelListing.fromJson($0) }
        )
    }

    func toJson() -> [String: Any] {
        ["listings": listings.map { $0.toJson() }]
    }

    func toAiInput() -> [String: Any] {
        ["listings": listings.map { $0.toAiInput() }]
    }
}

/// A hotel listing with booking details.
/// Mirrors Flutter's `HotelListing` in `tools/booking/model.dart`.
struct HotelListing: Identifiable, Listing {
    let id: String
    let listingSelectionId: String
    let name: String
    let location: String
    let pricePerNight: Double
    let imageName: String
    let checkIn: Date
    let checkOut: Date
    let guests: Int

    var description: String {
        "\(name) in \(location), $\(Int(pricePerNight))"
    }

    var nights: Int {
        Calendar.current.dateComponents([.day], from: checkIn, to: checkOut).day ?? 0
    }

    var totalPrice: Double {
        Double(nights) * pricePerNight
    }

    static func fromJson(_ json: [String: Any]) -> HotelListing {
        let search = HotelSearch.fromJson(json["search"] as? [String: Any] ?? [:])
        return HotelListing(
            id: UUID().uuidString,
            listingSelectionId: json["listingSelectionId"] as? String ?? "",
            name: json["name"] as? String ?? "",
            location: json["location"] as? String ?? "",
            pricePerNight: (json["pricePerNight"] as? NSNumber)?.doubleValue ?? 0,
            imageName: (json["images"] as? [String])?.first ?? "",
            checkIn: search.checkIn,
            checkOut: search.checkOut,
            guests: search.guests
        )
    }

    func toJson() -> [String: Any] {
        [
            "name": name,
            "location": location,
            "pricePerNight": pricePerNight,
            "images": [imageName],
            "listingSelectionId": listingSelectionId,
            "search": HotelSearch(
                query: "",
                checkIn: checkIn,
                checkOut: checkOut,
                guests: guests
            ).toJson(),
        ]
    }

    func toAiInput() -> [String: Any] {
        [
            "description": description,
            "images": [imageName],
            "listingSelectionId": listingSelectionId,
        ]
    }
}

/// Search parameters for a hotel query.
/// Mirrors Flutter's `HotelSearch` in `tools/booking/model.dart`.
struct HotelSearch {
    let query: String
    let checkIn: Date
    let checkOut: Date
    let guests: Int

    static func fromJson(_ json: [String: Any]) -> HotelSearch {
        let checkInDate = Self.parseDate(json["checkIn"] as? String) ?? Date()
        let checkOutDate = Self.parseDate(json["checkOut"] as? String)
            ?? Calendar.current.date(byAdding: .day, value: 7, to: checkInDate)!
        return HotelSearch(
            query: json["query"] as? String ?? "",
            checkIn: checkInDate,
            checkOut: checkOutDate,
            guests: (json["guests"] as? Int)
                ?? (json["guests"] as? Double).map { Int($0) } ?? 2
        )
    }

    func toJson() -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return [
            "query": query,
            "checkIn": formatter.string(from: checkIn),
            "checkOut": formatter.string(from: checkOut),
            "guests": guests,
        ]
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let iso = ISO8601DateFormatter()
        return iso.date(from: string + "T00:00:00Z")
    }
}
