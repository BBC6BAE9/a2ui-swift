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

// MARK: - A2UISurfaceView

/// The main entry point for rendering a single A2UI surface in SwiftUI.
///
/// Mirrors the React renderer's `<A2uiSurface surface={surfaceModel} />` in
/// `renderers/react/src/v0_9/A2uiSurface.tsx`.
///
/// Handles the full rendering lifecycle:
/// - Renders nothing until the first `updateComponents` message is processed
/// - Reactively re-renders when `componentTree` changes (structural updates)
/// - Re-renders individual views when `PathSlot.value` changes (data updates)
/// - Applies theme from `createSurface.theme`
/// - Routes taps to `onAction` as resolved `ResolvedAction` values
///
/// # Without custom components
/// ```swift
/// @State var vm = SurfaceViewModel(catalog: basicCatalog)
/// try vm.processMessages(messages)
///
/// A2UISurfaceView(viewModel: vm)
///
/// // With action handler:
/// A2UISurfaceView(viewModel: vm) { action in
///     print("Action: \(action.name)")
/// }
/// ```
///
/// # With custom components (call-site identical to Flutter)
/// ```swift
/// // Flutter:  final catalog = AppCatalog(); A2UISurfaceView(surface: surface, catalog: catalog)
/// // SwiftUI:
/// let catalog = AppCatalog()
/// A2UISurfaceView(viewModel: vm, catalog: catalog)
/// ```
///
/// # Catalog pattern
/// Define a `CustomComponentCatalog` in your own module — no framework files modified:
/// ```swift
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
/// ```
public struct A2UISurfaceView<Catalog: CustomComponentCatalog>: View {
    private let viewModel: SurfaceViewModel
    private let catalog: Catalog
    private let onAction: (@Sendable (ResolvedAction) -> Void)?

    public init(
        viewModel: SurfaceViewModel,
        catalog: Catalog,
        onAction: (@Sendable (ResolvedAction) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.catalog = catalog
        self.onAction = onAction
    }

    public var body: some View {
        if let rootNode = viewModel.componentTree {
            ScrollView {
                A2UIComponentView(node: rootNode, surface: viewModel.surface)
                    .padding()
            }
            .tint(viewModel.a2uiStyle.primaryColor)
            .environment(\.a2uiStyle, viewModel.a2uiStyle)
            .environment(\.a2uiActionHandler, onAction)
            .environment(\.a2uiCatalog, AnyCustomComponentCatalog(catalog))
        }
    }
}

// MARK: - Convenience init (no custom components)

extension A2UISurfaceView where Catalog == EmptyCustomCatalog {
    /// Creates a surface view with no custom components.
    ///
    /// ```swift
    /// A2UISurfaceView(viewModel: vm)
    /// A2UISurfaceView(viewModel: vm) { action in print(action.name) }
    /// ```
    public init(
        viewModel: SurfaceViewModel,
        onAction: (@Sendable (ResolvedAction) -> Void)? = nil
    ) {
        self.init(viewModel: viewModel, catalog: EmptyCustomCatalog(), onAction: onAction)
    }
}
