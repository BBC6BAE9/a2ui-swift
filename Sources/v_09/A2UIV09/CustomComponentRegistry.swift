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

// MARK: - Custom Component Renderer

/// A closure that renders a custom v0.9 component.
/// Receives the `SurfaceModel` so the renderer can create a `DataContext`
/// and resolve DynamicValues reactively.
public typealias CustomComponentRenderer = @Sendable (
    _ typeName: String,
    _ node: ComponentNode,
    _ children: [ComponentNode],
    _ surface: SurfaceModel
) -> AnyView?

// MARK: - Environment Key

private struct CustomComponentRendererV09Key: EnvironmentKey {
    static let defaultValue: CustomComponentRenderer? = nil
}

extension EnvironmentValues {
    public var a2uiCustomComponentRendererV09: CustomComponentRenderer? {
        get { self[CustomComponentRendererV09Key.self] }
        set { self[CustomComponentRendererV09Key.self] = newValue }
    }
}

// MARK: - View Modifier

extension View {
    public func a2uiCustomComponentsV09(
        _ renderer: @escaping CustomComponentRenderer
    ) -> some View {
        self.environment(\.a2uiCustomComponentRendererV09, renderer)
    }
}
