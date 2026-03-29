// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import A2UISwiftCore

/// Defines the collection of UI components that the generative AI model can use
/// to construct the user interface for the travel app.
///
/// This catalog includes a mix of core widgets (like `Button`, `Column`, `Text`,
/// `Image`) and custom, domain-specific widgets tailored for a travel planning
/// experience, such as `TravelCarousel`, `Itinerary`, and `InputGroup`. The AI
/// selects from these components to build a dynamic and interactive UI in
/// response to user prompts.
///
/// Mirrors Flutter's `travelAppCatalog` from `catalog.dart`.
let travelAppCatalog = Catalog(
    id: basicCatalogId,
    componentNames: basicCatalog.componentNames.union(Set(TravelComponentNames.allNames)),
    functions: basicCatalog.functions
)
