// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// The catalog ID for the basic catalog (v1.0).
/// Mirrors Flutter's `basicCatalogId` from `primitives/constants.dart` and v1.0
/// spec examples (`createSurface.catalogId`).
public let basicCatalogId =
    "https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json"

/// The ready-to-use Basic Catalog instance.
///
/// Contains all 18 standard components and 25 built-in functions.
/// Pass this to `SurfaceViewModel`, `MessageProcessor`, or `A2UISurfaceView`.
///
/// Mirrors the React renderer's `basicCatalog` singleton in
/// `renderers/react/src/v1_0/catalog/basic/index.ts`.
///
/// # Usage
/// ```swift
/// let vm = SurfaceViewModel(catalog: basicCatalog)
/// try vm.processMessages(messages)
/// A2UISurfaceView(viewModel: vm)
/// ```
public nonisolated(unsafe) let basicCatalog = Catalog(
    id: basicCatalogId,
    componentNames: BASIC_COMPONENT_NAMES,
    functions: BASIC_FUNCTIONS
)
