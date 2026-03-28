// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/// A fake booking service to simulate hotel listings and bookings.
/// Mirrors Flutter's `BookingService` in `tools/booking/booking_service.dart`.
final class BookingService {
    static let instance = BookingService()

    private init() {}

    private(set) var listings: [String: HotelListing] = [:]

    private func generateListingSelectionId() -> String {
        String(Int.random(in: 0..<1_000_000_000))
    }

    @discardableResult
    private func rememberListing(_ listing: HotelListing) -> HotelListing {
        listings[listing.listingSelectionId] = listing
        return listing
    }

    func listHotels(_ search: HotelSearch) async -> HotelSearchResult {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return listHotelsSync(search)
    }

    func bookSelections(
        listingSelectionIds: [String],
        paymentMethodId: String
    ) async {
        try? await Task.sleep(nanoseconds: 400_000_000)
    }

    /// Synchronous version for example data generation.
    func listHotelsSync(_ search: HotelSearch) -> HotelSearchResult {
        HotelSearchResult(
            listings: [
                rememberListing(
                    HotelListing(
                        id: UUID().uuidString,
                        listingSelectionId: generateListingSelectionId(),
                        name: "The Dart Inn",
                        location: "Sunnyvale, CA",
                        pricePerNight: 150,
                        imageName: "assets/booking_service/dart_inn.png",
                        checkIn: search.checkIn,
                        checkOut: search.checkOut,
                        guests: search.guests
                    )
                ),
                rememberListing(
                    HotelListing(
                        id: UUID().uuidString,
                        listingSelectionId: generateListingSelectionId(),
                        name: "The Flutter Hotel",
                        location: "Mountain View, CA",
                        pricePerNight: 250,
                        imageName: "assets/booking_service/flutter_hotel.png",
                        checkIn: search.checkIn,
                        checkOut: search.checkOut,
                        guests: search.guests
                    )
                ),
            ]
        )
    }

    func listing(for selectionId: String) -> HotelListing? {
        listings[selectionId]
    }
}
