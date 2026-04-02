// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

/// A debug catalog view that showcases all components rendered via A2UI,
/// matching the Flutter `DebugCatalogView` layout: each component's example data
/// is parsed into a SurfaceViewModel, then rendered inside a labeled card.
struct CatalogView: View {
    @State private var catalogSections: [CatalogSection] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading catalog…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(catalogSections) { section in
                            VStack(spacing: 8) {
                                Text(section.surfaceId)
                                    .font(.title3)
                                    .fontWeight(.bold)

                                CatalogSurfaceView(viewModel: section.viewModel)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .task {
            if catalogSections.isEmpty {
                let sections = Self.buildCatalog()
                catalogSections = sections
                isLoading = false
            }
        }
    }

    // MARK: - Catalog Data Model

    struct CatalogSection: Identifiable {
        let id: String
        let surfaceId: String
        let viewModel: SurfaceViewModel
    }

    // MARK: - Build all catalog items matching Flutter's DebugCatalogView

    static func buildCatalog() -> [CatalogSection] {
        var sections: [CatalogSection] = []

        for item in allCatalogItems {
            for (index, exampleBuilder) in item.examples.enumerated() {
                let indexPart = item.examples.count > 1 ? "-\(index)" : ""
                let surfaceId = "\(item.name)\(indexPart)"
                let components = exampleBuilder()

                let catalog = Catalog(id: "travel")
                let surface = SurfaceModel(id: surfaceId, catalog: catalog)
                let viewModel = SurfaceViewModel(surface: surface)

                // Process: updateComponents first (registers components), then createSurface (builds tree)
                if let update = MockServerToClientMessages.decodeMessage(["updateComponents": ["surfaceId": surfaceId, "components": components]]) {
                    try? viewModel.processMessage(update)
                }
                if let create = MockServerToClientMessages.decodeMessage(["createSurface": ["surfaceId": surfaceId, "catalogId": "travel"]]) {
                    try? viewModel.processMessage(create)
                }

                if viewModel.componentTree != nil {
                    sections.append(CatalogSection(
                        id: surfaceId,
                        surfaceId: surfaceId,
                        viewModel: viewModel
                    ))
                }
            }
        }

        return sections
    }

    // MARK: - All Catalog Items (matching Flutter's travelAppCatalog)

    private struct CatalogItemDef {
        let name: String
        let examples: [@MainActor () -> [[String: Any]]]
    }

    @MainActor private static var allCatalogItems: [CatalogItemDef] {
        [
            // Basic components (from genui standard catalog)
            CatalogItemDef(name: "Button", examples: [buttonExample0, buttonExample1]),
            CatalogItemDef(name: "Column", examples: [columnExample]),
            CatalogItemDef(name: "Text", examples: [textExample]),
            CatalogItemDef(name: "Image", examples: [imageExample]),

            // Custom travel components
            CatalogItemDef(name: "CheckboxFilterChipsInput", examples: [checkboxFilterChipsExample]),
            CatalogItemDef(name: "DateInputChip", examples: [dateInputChipExample]),
            CatalogItemDef(name: "InformationCard", examples: [informationCardExample]),
            CatalogItemDef(name: "InputGroup", examples: [inputGroupExample]),
            CatalogItemDef(name: "Itinerary", examples: [itineraryExample]),
            CatalogItemDef(name: "ListingsBooker", examples: [listingsBookerExample]),
            CatalogItemDef(name: "OptionsFilterChipInput", examples: [optionsFilterChipExample]),
            CatalogItemDef(name: "TabbedSections", examples: [tabbedSectionsExample]),
            CatalogItemDef(name: "TextInputChip", examples: [textInputChipExample0, textInputChipExample1]),
            CatalogItemDef(name: "Trailhead", examples: [trailheadExample]),
            CatalogItemDef(name: "TravelCarousel", examples: [travelCarouselInspirationExample, travelCarouselHotelExample]),
        ]
    }

    // MARK: - Basic Component Examples

    private static func buttonExample0() -> [[String: Any]] {
        [
            ["id": "root", "component": "Button",
             "child": "text",
             "action": ["event": ["name": "button_pressed"]]],
            ["id": "text", "component": "Text", "text": "Hello World"]
        ]
    }

    private static func buttonExample1() -> [[String: Any]] {
        [
            ["id": "root", "component": "Column",
             "children": ["primaryButton", "secondaryButton"]],
            ["id": "primaryButton", "component": "Button",
             "child": "primaryText",
             "variant": "primary",
             "action": ["event": ["name": "primary_pressed"]]],
            ["id": "primaryText", "component": "Text", "text": "Primary Button"],
            ["id": "secondaryButton", "component": "Button",
             "child": "secondaryText",
             "action": ["event": ["name": "secondary_pressed"]]],
            ["id": "secondaryText", "component": "Text", "text": "Secondary Button"]
        ]
    }

    private static func columnExample() -> [[String: Any]] {
        [
            ["id": "root", "component": "Column",
             "children": ["advice_text", "advice_options", "submit_button"]],
            ["id": "advice_text", "component": "Text",
             "text": "What kind of advice are you looking for?"],
            ["id": "advice_options", "component": "Text",
             "text": "Some advice options."],
            ["id": "submit_button", "component": "Button",
             "child": "submit_button_text",
             "action": ["event": ["name": "submit"]]],
            ["id": "submit_button_text", "component": "Text", "text": "Submit"]
        ]
    }

    private static func textExample() -> [[String: Any]] {
        [
            ["id": "root", "component": "Text",
             "text": "Hello World",
             "variant": "headlineMedium"]
        ]
    }

    private static func imageExample() -> [[String: Any]] {
        [
            ["id": "root", "component": "Image",
             "url": "https://developer.apple.com/assets/elements/icons/swiftui/swiftui-256x256_2x.png"]
        ]
    }

    // MARK: - Custom Component Examples (matching Flutter catalog exampleData)

    private static func checkboxFilterChipsExample() -> [[String: Any]] {
        [
            ["id": "root", "component": TravelComponentNames.checkboxFilterChipsInput,
             "chipLabel": "Amenities",
             "options": ["Wifi", "Gym", "Pool", "Parking"],
             "selectedOptions": ["Wifi", "Gym"]]
        ]
    }

    private static func dateInputChipExample() -> [[String: Any]] {
        [
            ["id": "root", "component": TravelComponentNames.dateInputChip,
             "value": "1871-07-22",
             "label": "Your birth date"]
        ]
    }

    private static func informationCardExample() -> [[String: Any]] {
        [
            ["id": "root", "component": TravelComponentNames.informationCard,
             "title": "Beautiful Scenery",
             "subtitle": "A stunning view",
             "body": "This is a beautiful place to visit in the summer.",
             "imageChildId": "image1"],
            ["id": "image1", "component": "Image", "url": "assets/travel_images/canyonlands_national_park_utah.jpg"]
        ]
    }

    private static func inputGroupExample() -> [[String: Any]] {
        [
            ["id": "root", "component": TravelComponentNames.inputGroup,
             "submitLabel": "Submit",
             "children": ["check_in", "check_out", "text_input1", "text_input2"],
             "action": ["event": ["name": "submit_form"]]],
            ["id": "check_in", "component": TravelComponentNames.dateInputChip,
             "value": "2026-07-22", "label": "Check-in date"],
            ["id": "check_out", "component": TravelComponentNames.dateInputChip,
             "label": "Check-out date"],
            ["id": "text_input1", "component": TravelComponentNames.textInputChip,
             "value": "John Doe", "label": "Enter your name"],
            ["id": "text_input2", "component": TravelComponentNames.textInputChip,
             "label": "Enter your friend's name"]
        ]
    }

    private static func itineraryExample() -> [[String: Any]] {
        [
            ["id": "root", "component": TravelComponentNames.itinerary,
             "title": "My Awesome Trip",
             "subheading": "A 3-day adventure",
             "imageChildId": "image1",
             "days": [
                ["title": "Day 1",
                 "subtitle": "Arrival and Exploration",
                 "description": "Welcome to the city!",
                 "imageChildId": "image2",
                 "entries": [
                    ["title": "Check-in to Hotel",
                     "bodyText": "Check-in to your hotel and relax.",
                     "time": "3:00 PM",
                     "type": "accommodation",
                     "status": "noBookingRequired"]
                 ]]
             ]],
            ["id": "image1", "component": "Image", "url": "assets/travel_images/canyonlands_national_park_utah.jpg"],
            ["id": "image2", "component": "Image", "url": "assets/travel_images/brooklyn_bridge_new_york.jpg"]
        ]
    }

    private static func listingsBookerExample() -> [[String: Any]] {
        let selectionIds = MockData.hotelListings.prefix(2).map(\.listingSelectionId)
        return [
            ["id": "root", "component": TravelComponentNames.listingsBooker,
             "listingSelectionIds": selectionIds,
             "itineraryName": "Dart and Flutter deep dive"]
        ]
    }

    private static func optionsFilterChipExample() -> [[String: Any]] {
        [
            ["id": "root", "component": TravelComponentNames.optionsFilterChipInput,
             "chipLabel": "Budget",
             "options": ["Low", "Medium", "High"],
             "value": "Medium"]
        ]
    }

    private static func tabbedSectionsExample() -> [[String: Any]] {
        [
            ["id": "root", "component": TravelComponentNames.tabbedSections,
             "sections": [
                ["title": "Tab 1", "child": "tab1_content"],
                ["title": "Tab 2", "child": "tab2_content"]
             ]],
            ["id": "tab1_content", "component": "Text",
             "text": "This is the content of Tab 1."],
            ["id": "tab2_content", "component": "Text",
             "text": "This is the content of Tab 2."]
        ]
    }

    private static func textInputChipExample0() -> [[String: Any]] {
        [
            ["id": "root", "component": TravelComponentNames.textInputChip,
             "value": "John Doe",
             "label": "Enter your name"]
        ]
    }

    private static func textInputChipExample1() -> [[String: Any]] {
        [
            ["id": "root", "component": TravelComponentNames.textInputChip,
             "label": "Enter your password",
             "obscured": true]
        ]
    }

    private static func trailheadExample() -> [[String: Any]] {
        [
            ["id": "root", "component": TravelComponentNames.trailhead,
             "topics": ["Topic 1", "Topic 2", "Topic 3"],
             "action": ["event": ["name": "select_topic"]]]
        ]
    }

    private static func travelCarouselInspirationExample() -> [[String: Any]] {
        [
            ["id": "root", "component": "Column",
             "children": ["inspiration_title", "inspiration_carousel"]],
            ["id": "inspiration_title", "component": "Text",
             "text": "Let's plan your dream trip to Greece! What kind of experience are you looking for?"],
            ["id": "inspiration_carousel", "component": TravelComponentNames.travelCarousel,
             "items": [
                ["description": "Relaxing Beach Holiday",
                 "imageChildId": "santorini_beach_image",
                 "listingSelectionId": "12345",
                 "action": ["event": ["name": "selectExperience"]]],
                ["imageChildId": "akrotiri_fresco_image",
                 "description": "Cultural Exploration",
                 "listingSelectionId": "12346",
                 "action": ["event": ["name": "selectExperience"]]],
                ["imageChildId": "santorini_caldera_image",
                 "description": "Adventure & Outdoors",
                 "listingSelectionId": "12347",
                 "action": ["event": ["name": "selectExperience"]]],
                ["description": "Foodie Tour",
                 "imageChildId": "greece_food_image",
                 "action": ["event": ["name": "selectExperience"]]]
             ]],
            ["id": "santorini_beach_image", "component": "Image", "fit": "cover", "url": "assets/travel_images/santorini_panorama.jpg"],
            ["id": "akrotiri_fresco_image", "component": "Image", "fit": "cover", "url": "assets/travel_images/akrotiri_spring_fresco_santorini.jpg"],
            ["id": "santorini_caldera_image", "component": "Image", "url": "assets/travel_images/santorini_from_space.jpg", "fit": "cover"],
            ["id": "greece_food_image", "component": "Image", "fit": "cover", "url": "assets/travel_images/saffron_gatherers_fresco_santorini.jpg"]
        ]
    }

    private static func travelCarouselHotelExample() -> [[String: Any]] {
        let hotels = MockData.hotelListings
        let hotel1 = hotels[0]
        let hotel2 = hotels.count > 1 ? hotels[1] : hotel1
        return [
            ["id": "root", "component": TravelComponentNames.travelCarousel,
             "items": [
                ["description": hotel1.description,
                 "imageChildId": "image_1",
                 "listingSelectionId": "12345",
                 "action": ["event": ["name": "selectHotel"]]],
                ["description": hotel2.description,
                 "imageChildId": "image_2",
                 "listingSelectionId": "12346",
                 "action": ["event": ["name": "selectHotel"]]]
             ]],
            ["id": "image_1", "component": "Image", "fit": "cover",
             "url": hotel1.imageName],
            ["id": "image_2", "component": "Image", "fit": "cover",
             "url": hotel2.imageName]
        ]
    }
}

// MARK: - Surface Rendering View

private struct CatalogSurfaceView: View {
    let viewModel: SurfaceViewModel

    var body: some View {
        if let rootNode = viewModel.componentTree {
            A2UIComponentView(node: rootNode, surface: viewModel.surface)
                .a2uiCatalog(TravelCatalog())
                .a2uiLeafMargin(0)
                .a2uiImageResolver { urlString in
                    let name = a2uiExtractAssetName(from: urlString)
                    // Only return an Image if the asset catalog contains this name
                    #if canImport(UIKit)
                    guard UIImage(named: name) != nil else { return nil }
                    #elseif canImport(AppKit)
                    guard NSImage(named: name) != nil else { return nil }
                    #endif
                    return Image(name)
                }
        }
    }
}

#Preview {
    NavigationStack {
        CatalogView()
            .navigationTitle("Widget Catalog")
    }
}
