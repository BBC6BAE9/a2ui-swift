// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

// MARK: - Data Models

struct ListingsBookerData {
    let itineraryName: String
    var listings: [HotelListing]
}

// MARK: - View

/// A checkout view for booking hotel listings.
/// Equivalent to the Flutter `ListingsBooker` catalog component.
struct ListingsBookerView: View {
    @Binding var data: ListingsBookerData
    var onBook: (() -> Void)?
    var onModify: ((HotelListing) -> Void)?

    enum BookingStatus {
        case initial, inProgress, done
    }

    @State private var bookingStatus: BookingStatus = .initial
    @State private var selectedPaymentMethod: String?

    private let paymentMethods = [
        ("John Doe", "**** **** **** 1234", "12/25"),
        ("Jane Doe", "**** **** **** 5678", "08/26"),
    ]

    private var grandTotal: Double {
        data.listings.reduce(0) { $0 + $1.totalPrice }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Check out \"\(data.itineraryName)\"")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            ForEach(data.listings) { listing in
                ListingCardView(listing: listing, onRemove: {
                    data.listings.removeAll { $0.id == listing.id }
                }, onModify: onModify != nil ? {
                    onModify?(listing)
                } : nil)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Grand Total:")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("$\(grandTotal, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Divider()

                Text("Select Payment Method")
                    .font(.headline)

                ForEach(Array(paymentMethods.enumerated()), id: \.offset) { index, card in
                    Button {
                        selectedPaymentMethod = card.1
                    } label: {
                        HStack {
                            Image(systemName: selectedPaymentMethod == card.1 ? "circle.inset.filled" : "circle")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text(card.0)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(card.1)\nExpires: \(card.2)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }

                Button {
                    bookingStatus = .inProgress
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        bookingStatus = .done
                        onBook?()
                    }
                } label: {
                    Group {
                        switch bookingStatus {
                        case .initial:
                            Text("Book")
                                .fontWeight(.semibold)
                        case .inProgress:
                            ProgressView()
                                .tint(.white)
                        case .done:
                            Label("Booked", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(bookingStatus == .done ? .green : nil)
                .disabled(selectedPaymentMethod == nil || bookingStatus != .initial)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Listing Card

struct ListingCardView: View {
    let listing: HotelListing
    var onRemove: (() -> Void)?
    var onModify: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                    Image(a2uiExtractAssetName(from: listing.imageName))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.name)
                        .font(.headline)
                    Text(listing.location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 4) {
                    Button("Remove", role: .destructive) {
                        onRemove?()
                    }
                    .font(.caption)

                    if let onModify {
                        Button("Modify") {
                            onModify()
                        }
                        .font(.caption)
                    }
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Check-in").font(.caption).foregroundStyle(.secondary)
                    Text(listing.checkIn.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Check-out").font(.caption).foregroundStyle(.secondary)
                    Text(listing.checkOut.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                }
            }

            HStack {
                Text("Duration:").font(.caption)
                Spacer()
                Text("\(listing.nights) nights").font(.caption)
            }
            .foregroundStyle(.secondary)

            HStack {
                Text("Total price:").font(.subheadline).fontWeight(.medium)
                Spacer()
                Text("$\(listing.totalPrice, specifier: "%.2f")")
                    .font(.subheadline).fontWeight(.medium)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - A2UI Wrapper

/// Renders a `ListingsBooker` from an A2UI `ComponentNode`.
struct A2UIListingsBookerView: View {
    let node: ComponentNode
    let surface: SurfaceModel
    @Environment(\.a2uiActionHandler) private var actionHandler

    private var props: [String: AnyCodable] { node.instance.properties }

    @State private var listings: [HotelListing] = []
    @State private var initialized = false

    var body: some View {
        let itineraryName = A2UIHelpers.resolveString(props["itineraryName"], surface: surface, dataContextPath: node.dataContextPath) ?? ""
        let hasModifyAction = props["modifyAction"] != nil

        ListingsBookerViewWrapper(
            itineraryName: itineraryName,
            listings: $listings,
            onBook: {
                actionHandler?(ResolvedAction(
                    name: "bookingConfirmed",
                    sourceComponentId: node.id,
                    context: [:]
                ))
            },
            onModify: hasModifyAction ? { listing in
                if let action = A2UIHelpers.resolveAction(props["modifyAction"], node: node, surface: surface) {
                    var ctx = action.context
                    ctx["listingSelectionId"] = .string(listing.listingSelectionId)
                    let modifiedAction = ResolvedAction(
                        name: action.name,
                        sourceComponentId: action.sourceComponentId,
                        context: ctx
                    )
                    actionHandler?(modifiedAction)
                }
            } : nil
        )
        .onAppear {
            guard !initialized else { return }
            initialized = true
            let selectionIds = A2UIHelpers.resolveStringList(props["listingSelectionIds"], surface: surface, dataContextPath: node.dataContextPath)
            listings = selectionIds.compactMap { BookingService.instance.listing(for: $0) }
        }
    }
}

private struct ListingsBookerViewWrapper: View {
    let itineraryName: String
    @Binding var listings: [HotelListing]
    let onBook: () -> Void
    var onModify: ((HotelListing) -> Void)?

    var body: some View {
        ListingsBookerView(
            data: Binding(
                get: { ListingsBookerData(itineraryName: itineraryName, listings: listings) },
                set: { listings = $0.listings }
            ),
            onBook: onBook,
            onModify: onModify
        )
    }
}

#Preview("Listings Booker") {
    @Previewable @State var data = MockData.listingsBooker
    ListingsBookerView(data: $data)
}
