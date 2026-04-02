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

import SwiftUI
import A2UISwiftCore

// MARK: - CustomComponentCatalog

/// A catalog that renders custom (non-built-in) A2UI components.
///
/// Implement this protocol to add custom component types to an `A2UISurfaceView`
/// without modifying the framework's core dispatch logic.
///
/// The framework calls `build(typeName:node:surface:)` whenever it encounters a
/// `.custom(typeName)` node in the component tree.  Return `EmptyView()` (or any
/// sentinel) to signal "no match" and fall back to rendering the children in a VStack.
///
/// ## Usage
///
/// ```swift
/// // 1. Define a catalog in your own module — no framework files touched.
/// struct AppCatalog: CustomComponentCatalog {
///     @ViewBuilder
///     func build(typeName: String, node: ComponentNode, surface: SurfaceModel) -> some View {
///         switch typeName {
///         case "Chart":    MyChartView(node: node, surface: surface)
///         case "Carousel": MyCarouselView(node: node, surface: surface)
///         default:         EmptyView()
///         }
///     }
/// }
///
/// // 2. Pass the catalog — call-site identical to Flutter.
/// let catalog = AppCatalog()
/// A2UISurfaceView(viewModel: vm, catalog: catalog)
/// ```
///
/// ## Flutter equivalent (call-site)
///
/// ```dart
/// final catalog = AppCatalog();
/// A2UISurfaceView(surface: surface, catalog: catalog)
/// ```
///
/// ## Why PAT instead of a closure?
///
/// A named protocol type gives the catalog an identity that is:
/// - **Composable**: multiple catalogs can be chained or composed.
/// - **Testable**: swap `AppCatalog()` for `MockCatalog()` in tests.
/// - **Injectable**: pass `any CustomComponentCatalog` across module boundaries.
/// - **Zero AnyView**: `associatedtype Output` lets the compiler keep full type
///   information; no type-erasure is needed anywhere in the View tree.
///
/// The `associatedtype Output` is inferred automatically when you annotate
/// `build` with `@ViewBuilder` — you never write it by hand.
public protocol CustomComponentCatalog {
    /// The concrete `View` type produced by this catalog.
    /// Inferred by the compiler from the `@ViewBuilder` return type.
    associatedtype Output: View

    /// Builds a SwiftUI view for the given custom component.
    ///
    /// - Parameters:
    ///   - typeName: Custom component type name from the server (e.g. `"Chart"`).
    ///   - node:     Resolved component node (properties, children, id, …).
    ///   - surface:  The surface this component belongs to.
    /// - Returns: A view for the component, or `EmptyView()` when this catalog
    ///   does not handle `typeName` (falls back to rendering children in VStack).
    @ViewBuilder
    @MainActor
    func build(typeName: String, node: ComponentNode, surface: SurfaceModel) -> Output
}

// MARK: - EmptyCustomCatalog

/// A `CustomComponentCatalog` that never handles any custom component.
///
/// Used as the default when no catalog is provided to `A2UISurfaceView`.
///
/// ```swift
/// // These two are equivalent:
/// A2UISurfaceView(viewModel: vm)
/// A2UISurfaceView(viewModel: vm, catalog: EmptyCustomCatalog())
/// ```
public struct EmptyCustomCatalog: CustomComponentCatalog {
    public init() {}

    @ViewBuilder
    public func build(typeName: String, node: ComponentNode, surface: SurfaceModel) -> some View {
        EmptyView()
    }
}
