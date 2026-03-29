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
/// # Usage
/// ```swift
/// @State var vm = SurfaceViewModel(catalog: basicCatalog)
///
/// // Process messages from your agent transport:
/// try vm.processMessages(messages)
///
/// // Render:
/// A2UISurfaceView(viewModel: vm)
///
/// // With action handler:
/// A2UISurfaceView(viewModel: vm) { action in
///     print("Action: \(action.name)")
/// }
/// ```
public struct A2UISurfaceView: View {
    private let viewModel: SurfaceViewModel
    private let onAction: (@Sendable (ResolvedAction) -> Void)?

    public init(
        viewModel: SurfaceViewModel,
        onAction: (@Sendable (ResolvedAction) -> Void)? = nil
    ) {
        self.viewModel = viewModel
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
        }
    }
}
