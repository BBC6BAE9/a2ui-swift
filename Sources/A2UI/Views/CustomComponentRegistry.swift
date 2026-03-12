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

/// A closure that renders a custom component given a node, its children, and a view model.
///
/// - Parameters:
///   - typeName: The custom component type string (e.g. "Canvas", "Chart", "GoogleMap").
///   - node: The resolved `ComponentNode` for this component.
///   - children: Pre-resolved child nodes.
///   - viewModel: The `SurfaceViewModel` for data binding.
/// - Returns: An `AnyView` if the type is handled, or `nil` to fall back to default rendering.
public typealias CustomComponentRenderer = @Sendable (
    _ typeName: String,
    _ node: ComponentNode,
    _ children: [ComponentNode],
    _ viewModel: SurfaceViewModel
) -> AnyView?

// MARK: - Environment Key

private struct CustomComponentRendererKey: EnvironmentKey {
    static let defaultValue: CustomComponentRenderer? = nil
}

extension EnvironmentValues {
    /// A custom component renderer closure injected via the environment.
    public var a2uiCustomComponentRenderer: CustomComponentRenderer? {
        get { self[CustomComponentRendererKey.self] }
        set { self[CustomComponentRendererKey.self] = newValue }
    }
}

// MARK: - View Modifier

extension View {
    /// Inject a custom component renderer for unknown A2UI component types.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiCustomComponents { typeName, node, children, viewModel in
    ///         switch typeName {
    ///         case "Chart": return AnyView(MyChartView(...))
    ///         default: return nil
    ///         }
    ///     }
    /// ```
    public func a2uiCustomComponents(
        _ renderer: @escaping CustomComponentRenderer
    ) -> some View {
        self.environment(\.a2uiCustomComponentRenderer, renderer)
    }
}
