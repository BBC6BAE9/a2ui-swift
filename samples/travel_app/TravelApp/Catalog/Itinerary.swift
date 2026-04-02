// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

// MARK: - Data Models (pure data, no catalog)

enum ItineraryEntryType: String, Codable {
    case accommodation
    case transport
    case activity

    var systemImageName: String {
        switch self {
        case .accommodation: return "bed.double.fill"
        case .transport: return "tram.fill"
        case .activity: return "figure.hiking"
        }
    }
}

enum ItineraryEntryStatus: String, Codable {
    case noBookingRequired
    case choiceRequired
    case chosen
}

struct ItineraryData {
    let title: String
    let subheading: String
    let imageName: String
    let days: [ItineraryDayData]
    var imageNode: ComponentNode? = nil
    var surface: SurfaceModel? = nil
}

struct ItineraryDayData: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let entries: [ItineraryEntryData]
    var imageNode: ComponentNode? = nil
    var surface: SurfaceModel? = nil
}

struct ItineraryEntryData: Identifiable {
    let id = UUID()
    let title: String
    var subtitle: String? = nil
    let bodyText: String
    var address: String? = nil
    let time: String
    var totalCost: String? = nil
    let type: ItineraryEntryType
    let status: ItineraryEntryStatus
    var choiceRequiredAction: [String: Any]? = nil
}

// MARK: - Itinerary View
// Views are generic over Catalog — catalog is passed separately from data,
// mirroring Flutter's BuildContext pattern where catalog flows via InheritedWidget.

struct ItineraryView: View {
    let data: ItineraryData
    var onEntryAction: ((ItineraryEntryData) -> Void)?
    var onViewDetails: (() -> Void)?

    @State private var isShowingDetail = false

    var body: some View {
        Button {
            isShowingDetail = true
        } label: {
            HStack(spacing: 12) {
                if let node = data.imageNode, let surface = data.surface {
                    A2UIComponentView(node: node, surface: surface)
                        .frame(width: 100, height: 100)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    let assetName = a2uiExtractAssetName(from: data.imageName)
                    Image(assetName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(.headline)
                    Text(data.subheading)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isShowingDetail) {
            ItineraryDetailSheet(
                data: data,
                onEntryAction: onEntryAction,
                onViewDetails: onViewDetails
            )
        }
    }
}

// MARK: - Itinerary Detail Sheet

struct ItineraryDetailSheet: View {
    let data: ItineraryData
    var onEntryAction: ((ItineraryEntryData) -> Void)?
    var onViewDetails: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let node = data.imageNode, let surface = data.surface {
                    A2UIComponentView(node: node, surface: surface)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipped()
                    } else {
                        let assetName = a2uiExtractAssetName(from: data.imageName)
                        Image(assetName)
                            .resizable(resizingMode: .stretch)
                            .aspectRatio(contentMode: .fit)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(data.title)
                            .font(.title)
                            .fontWeight(.bold)

                        Button("View Details") {
                            onViewDetails?()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()

                    ForEach(data.days) { day in
                        ItineraryDayView(
                            day: day,
                            onEntryAction: onEntryAction,
                            onDismiss: { dismiss() }
                        )
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

// MARK: - Itinerary Day

struct ItineraryDayView: View {
    let day: ItineraryDayData
    var onEntryAction: ((ItineraryEntryData) -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let node = day.imageNode, let surface = day.surface {
                    A2UIComponentView(node: node, surface: surface)
                        .frame(width: 80, height: 80)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    let assetName = a2uiExtractAssetName(from: day.imageName)
                    Image(assetName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(day.title)
                        .font(.headline)
                    Text(day.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(markdownAttributed(day.description))
                .font(.body)
                .foregroundStyle(.secondary)

            Divider()

            ForEach(day.entries) { entry in
                ItineraryEntryView(
                    entry: entry,
                    onAction: onEntryAction,
                    onDismiss: onDismiss
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

// MARK: - Itinerary Entry (leaf — no children to render, no catalog needed)

struct ItineraryEntryView: View {
    let entry: ItineraryEntryData
    var onAction: ((ItineraryEntryData) -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.type.systemImageName)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    switch entry.status {
                    case .chosen:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .choiceRequired:
                        Button("Choose") {
                            onAction?(entry)
                            onDismiss?()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    case .noBookingRequired:
                        EmptyView()
                    }
                }

                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(entry.time)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                if let address = entry.address {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(address)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                if let cost = entry.totalCost {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle")
                            .font(.caption2)
                        Text(cost)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Text(markdownAttributed(entry.bodyText))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - A2UI Wrapper

struct A2UIItineraryView: View {
    let node: ComponentNode
    let children: [ComponentNode]
    let surface: SurfaceModel
    @Environment(\.a2uiActionHandler) private var actionHandler

    private var props: [String: AnyCodable] { node.instance.properties }

    var body: some View {
        let data = buildItineraryData()
        ItineraryView(data: data) { entry in
            if let actionHandler {
                if let choiceAction = entry.choiceRequiredAction,
                   let resolved = resolveChoiceAction(choiceAction) {
                    actionHandler(resolved)
                } else {
                    let action = ResolvedAction(
                        name: "chooseEntry",
                        sourceComponentId: node.id,
                        context: ["entryTitle": .string(entry.title)]
                    )
                    actionHandler(action)
                }
            }
        } onViewDetails: {
            actionHandler?(ResolvedAction(
                name: "viewItinerary",
                sourceComponentId: node.id,
                context: [:]
            ))
        }
        .padding(.horizontal)
    }

    private func resolveChoiceAction(_ actionDict: [String: Any]) -> ResolvedAction? {
        guard let data = try? JSONSerialization.data(withJSONObject: actionDict),
              let codable = try? JSONDecoder().decode(AnyCodable.self, from: data) else {
            return nil
        }
        return A2UIHelpers.resolveAction(codable, node: node, surface: surface)
    }

    private func buildItineraryData() -> ItineraryData {
        let title = A2UIHelpers.resolveString(props["title"], surface: surface, dataContextPath: node.dataContextPath) ?? ""
        let subheading = A2UIHelpers.resolveString(props["subheading"], surface: surface, dataContextPath: node.dataContextPath) ?? ""

        let heroImageChildId = props["imageChildId"]?.stringValue
        let heroImageNode = heroImageChildId.flatMap { childId in children.first { $0.baseComponentId == childId } }
        let heroImageName = heroImageNode?.instance.properties["url"]?.stringValue
            ?? "assets/travel_images/santorini_panorama.jpg"

        var days: [ItineraryDayData] = []
        if case .array(let daysArray) = props["days"] {
            for dayVal in daysArray {
                guard case .dictionary(let dayDict) = dayVal else { continue }
                let dayTitle = dayDict["title"]?.stringValue ?? ""
                let daySubtitle = dayDict["subtitle"]?.stringValue ?? ""
                let dayDesc = dayDict["description"]?.stringValue ?? ""
                let dayImageChildId = dayDict["imageChildId"]?.stringValue
                let dayImageNode = dayImageChildId.flatMap { childId in children.first { $0.baseComponentId == childId } }
                let dayImageName = dayImageNode?.instance.properties["url"]?.stringValue
                    ?? "assets/travel_images/akrotiri_spring_fresco_santorini.jpg"

                var entries: [ItineraryEntryData] = []
                if case .array(let entriesArray) = dayDict["entries"] {
                    for entryVal in entriesArray {
                        guard case .dictionary(let entryDict) = entryVal else { continue }
                        var choiceRequiredAction: [String: Any]?
                        if case .dictionary(let actionDict) = entryDict["choiceRequiredAction"],
                           let data = try? JSONEncoder().encode(AnyCodable.dictionary(actionDict)),
                           let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            choiceRequiredAction = jsonObj
                        }
                        entries.append(ItineraryEntryData(
                            title: entryDict["title"]?.stringValue ?? "",
                            subtitle: entryDict["subtitle"]?.stringValue,
                            bodyText: entryDict["bodyText"]?.stringValue ?? "",
                            address: entryDict["address"]?.stringValue,
                            time: entryDict["time"]?.stringValue ?? "",
                            totalCost: entryDict["totalCost"]?.stringValue,
                            type: ItineraryEntryType(rawValue: entryDict["type"]?.stringValue ?? "") ?? .activity,
                            status: ItineraryEntryStatus(rawValue: entryDict["status"]?.stringValue ?? "") ?? .noBookingRequired,
                            choiceRequiredAction: choiceRequiredAction
                        ))
                    }
                }

                days.append(ItineraryDayData(
                    title: dayTitle,
                    subtitle: daySubtitle,
                    description: dayDesc,
                    imageName: dayImageName,
                    entries: entries,
                    imageNode: dayImageNode,
                    surface: dayImageNode != nil ? surface : nil
                ))
            }
        }

        return ItineraryData(
            title: title,
            subheading: subheading,
            imageName: heroImageName,
            days: days,
            imageNode: heroImageNode,
            surface: heroImageNode != nil ? surface : nil
        )
    }
}

#Preview {
    ItineraryView(data: MockData.greeceItinerary)
        .padding()
}
