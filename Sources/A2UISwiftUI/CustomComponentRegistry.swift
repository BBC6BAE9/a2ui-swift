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

// MARK: - Custom Component Renderer (deprecated)

/// A closure that renders a custom v0.9 component.
///
/// - Deprecated: Use `CustomComponentCatalog` protocol instead.
///   Define a struct conforming to `CustomComponentCatalog` and pass it to
///   `A2UISurfaceView(viewModel:catalog:)`.  The protocol approach is zero-`AnyView`,
///   type-safe, testable, and has a call-site identical to Flutter.
@available(*, deprecated, renamed: "CustomComponentCatalog",
    message: "Use CustomComponentCatalog protocol and A2UISurfaceView(viewModel:catalog:) instead.")
public typealias CustomComponentRenderer = @Sendable (
    _ typeName: String,
    _ node: ComponentNode,
    _ children: [ComponentNode],
    _ surface: SurfaceModel
) -> AnyView?
