// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

/// Custom component catalog that maps A2UI component types to travel app views.
/// Equivalent to the Flutter `travelCustomRenderer` catalog item list.
struct TravelCatalog: CustomComponentCatalog {
    @ViewBuilder
    func build(typeName: String, node: ComponentNode, surface: SurfaceModel) -> some View {
        switch typeName {
        case TravelComponentNames.travelCarousel:
            A2UITravelCarouselView(node: node, children: node.children, surface: surface)

        case TravelComponentNames.informationCard:
            A2UIInformationCardView(node: node, children: node.children, surface: surface)

        case TravelComponentNames.itinerary:
            A2UIItineraryView(node: node, children: node.children, surface: surface)

        case TravelComponentNames.inputGroup:
            A2UIInputGroupView(node: node, children: node.children, surface: surface)

        case TravelComponentNames.trailhead:
            A2UITrailheadView(node: node, surface: surface)

        case TravelComponentNames.listingsBooker:
            A2UIListingsBookerView(node: node, surface: surface)

        case TravelComponentNames.tabbedSections:
            A2UITabbedSectionsView(node: node, children: node.children, surface: surface)

        case TravelComponentNames.optionsFilterChipInput:
            A2UIOptionsFilterChipView(node: node, surface: surface)

        case TravelComponentNames.checkboxFilterChipsInput:
            A2UICheckboxFilterChipsView(node: node, surface: surface)

        case TravelComponentNames.dateInputChip:
            A2UIDateInputChipView(node: node, surface: surface)

        case TravelComponentNames.textInputChip:
            A2UITextInputChipView(node: node, surface: surface)

        default:
            EmptyView()
        }
    }
}
