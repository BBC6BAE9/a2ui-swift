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

// MARK: - AnyCustomComponentCatalog

/// Internal type-erased wrapper around any `CustomComponentCatalog`.
///
/// This type exists solely to allow a `CustomComponentCatalog` (which has an
/// `associatedtype Output`) to be stored in a SwiftUI `EnvironmentKey` without
/// infecting every internal component with a generic parameter.
///
/// **This type is not part of the public API.**  Users always work with the
/// concrete `CustomComponentCatalog` protocol and never see `AnyView` at their
/// call site.  The single `AnyView` wrap happens here, at the framework boundary,
/// and is invisible to the host application.
struct AnyCustomComponentCatalog {

    private let _build: @MainActor (String, ComponentNode, SurfaceModel) -> AnyView?

    /// Wraps any `CustomComponentCatalog`.
    ///
    /// The concrete `Output` type is captured here; all downstream views remain
    /// non-generic.
    init<C: CustomComponentCatalog>(_ catalog: C) {
        _build = { @MainActor typeName, node, surface in
            let result = catalog.build(typeName: typeName, node: node, surface: surface)
            // `EmptyView` is the protocol-level sentinel for "not handled".
            // Returning nil signals A2UICustom to fall back to rendering children.
            guard !(result is EmptyView) else { return nil }
            return AnyView(result)
        }
    }

    /// Builds the custom component view, or returns `nil` when the catalog
    /// does not handle `typeName` (fall back to rendering children).
    @MainActor
    func build(typeName: String, node: ComponentNode, surface: SurfaceModel) -> AnyView? {
        _build(typeName, node, surface)
    }
}

// MARK: - EnvironmentKey

private struct A2UICatalogKey: EnvironmentKey {
    static let defaultValue = AnyCustomComponentCatalog(EmptyCustomCatalog())
}

extension EnvironmentValues {
    /// The active custom-component catalog.  Set once at `A2UISurfaceView` and
    /// flows down the tree automatically — no manual parameter threading needed.
    var a2uiCatalog: AnyCustomComponentCatalog {
        get { self[A2UICatalogKey.self] }
        set { self[A2UICatalogKey.self] = newValue }
    }
}

// MARK: - Public View Modifier

public extension View {
    /// Injects a custom component catalog into the SwiftUI environment so that
    /// `A2UIComponentView` can render custom component types.
    ///
    /// Use this when you construct `A2UIComponentView` directly (e.g. in a
    /// custom host view) and need to supply a catalog without going through
    /// `A2UISurfaceView`.
    ///
    /// ```swift
    /// A2UIComponentView(node: rootNode, surface: surface)
    ///     .a2uiCatalog(MyAppCatalog())
    /// ```
    func a2uiCatalog<C: CustomComponentCatalog>(_ catalog: C) -> some View {
        environment(\.a2uiCatalog, AnyCustomComponentCatalog(catalog))
    }
}
