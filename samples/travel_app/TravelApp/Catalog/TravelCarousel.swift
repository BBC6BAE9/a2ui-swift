// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import v_09

// MARK: - Data Models

struct TravelCarouselData {
    let title: String?
    let items: [TravelCarouselItem]
}

struct TravelCarouselItem: Identifiable {
    let id = UUID()
    let description: String
    let imageName: String
    let listingSelectionId: String?
    let actionName: String
}

// MARK: - View

/// A horizontally scrolling carousel of travel option cards.
/// Equivalent to the Flutter `TravelCarousel` catalog component.
struct TravelCarouselView: View {
    let data: TravelCarouselData
    var onItemTapped: ((TravelCarouselItem) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = data.title {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(data.items) { item in
                        TravelCarouselItemView(item: item)
                            .onTapGesture {
                                onItemTapped?(item)
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct TravelCarouselItemView: View {
    let item: TravelCarouselItem

    var body: some View {
        VStack(spacing: 0) {
            let assetName = a2uiExtractAssetName(from: item.imageName)
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 190, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(item.description)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(width: 190, height: 90)
                .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - A2UI Wrapper

/// Renders a `TravelCarousel` from an A2UI `ComponentNode`.
struct A2UITravelCarouselView: View {
    let node: ComponentNode
    let children: [ComponentNode]
    let surface: SurfaceModel
    @Environment(\.a2uiActionHandler) private var actionHandler

    private var props: [String: AnyCodable] { node.instance.properties }

    var body: some View {
        let title = A2UIHelpers.resolveString(props["title"], surface: surface, dataContextPath: node.dataContextPath)

        VStack(alignment: .leading, spacing: 16) {
            if let title {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        carouselItemView(item: item)
                            .onTapGesture {
                                if let action = item.action {
                                    var ctx = action.context
                                    ctx["description"] = .string(item.description)
                                    if let listingSelectionId = item.listingSelectionId {
                                        ctx["listingSelectionId"] = .string(listingSelectionId)
                                    }
                                    let enrichedAction = ResolvedAction(
                                        name: action.name,
                                        sourceComponentId: action.sourceComponentId,
                                        context: ctx
                                    )
                                    actionHandler?(enrichedAction)
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private struct CarouselItem {
        let description: String
        let imageNode: ComponentNode?
        let listingSelectionId: String?
        let action: ResolvedAction?
    }

    private var items: [CarouselItem] {
        guard case .array(let itemsArray) = props["items"] else {
            print("[TravelCarousel] No 'items' array found in props")
            return []
        }
        let childIds = children.map { $0.baseComponentId }
        print("[TravelCarousel] node has \(children.count) children: \(childIds)")
        return itemsArray.compactMap { itemVal -> CarouselItem? in
            guard case .dictionary(let dict) = itemVal else { return nil }
            let desc = A2UIHelpers.resolveString(dict["description"], surface: surface, dataContextPath: node.dataContextPath) ?? ""
            let imageChildId = dict["imageChildId"]?.stringValue
            let imageNode = imageChildId.flatMap { childId in
                children.first { $0.baseComponentId == childId }
            }
            print("[TravelCarousel] item '\(desc)': imageChildId=\(imageChildId ?? "nil"), imageNode=\(imageNode != nil ? "found" : "NOT FOUND")")
            let listingSelectionId = dict["listingSelectionId"]?.stringValue
            let action = A2UIHelpers.resolveAction(dict["action"], node: node, surface: surface)
            return CarouselItem(description: desc, imageNode: imageNode, listingSelectionId: listingSelectionId, action: action)
        }
    }

    @ViewBuilder
    private func carouselItemView(item: CarouselItem) -> some View {
        VStack(spacing: 0) {
            if let imageNode = item.imageNode {
                A2UIComponentView(node: imageNode, surface: surface)
                    .frame(width: 190, height: 150)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 190, height: 150)
            }

            Text(item.description)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(width: 190, height: 90)
                .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    TravelCarouselView(
        data: MockData.inspirationCarousel,
        onItemTapped: { item in
            print("Tapped: \(item.description)")
        }
    )
}
