// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import v_09

/// Custom component renderer that maps A2UI component types to travel app views.
let travelCustomRenderer: CustomComponentRenderer = { typeName, node, children, surface in
    switch typeName {
    case TravelComponentNames.travelCarousel:
        return AnyView(A2UITravelCarouselView(node: node, children: children, surface: surface))

    case TravelComponentNames.informationCard:
        return AnyView(A2UIInformationCardView(node: node, children: children, surface: surface))

    case TravelComponentNames.itinerary:
        return AnyView(A2UIItineraryView(node: node, children: children, surface: surface))

    case TravelComponentNames.inputGroup:
        return AnyView(A2UIInputGroupView(node: node, children: children, surface: surface))

    case TravelComponentNames.trailhead:
        return AnyView(A2UITrailheadView(node: node, surface: surface))

    case TravelComponentNames.listingsBooker:
        return AnyView(A2UIListingsBookerView(node: node, surface: surface))

    case TravelComponentNames.tabbedSections:
        return AnyView(A2UITabbedSectionsView(node: node, children: children, surface: surface))

    case TravelComponentNames.optionsFilterChipInput:
        return AnyView(A2UIOptionsFilterChipView(node: node, surface: surface))

    case TravelComponentNames.checkboxFilterChipsInput:
        return AnyView(A2UICheckboxFilterChipsView(node: node, surface: surface))

    case TravelComponentNames.dateInputChip:
        return AnyView(A2UIDateInputChipView(node: node, surface: surface))

    case TravelComponentNames.textInputChip:
        return AnyView(A2UITextInputChipView(node: node, surface: surface))

    default:
        return nil
    }
}
