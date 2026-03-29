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

// MARK: - CatalogItemOverrides (internal storage)

/// Internal dictionary used as the environment value.
/// Keyed by `BuiltinComponentType.rawValue` for O(1) lookup at render time.
struct CatalogItemOverrides {
    var builders: [String: CatalogWidgetBuilder] = [:]

    /// Registers (or replaces) the builder for the given component type.
    /// Mirrors genui-flutter's `Catalog.copyWith(newItems:)` — same name replaces.
    mutating func register(_ item: CatalogItem) {
        builders[item.name.rawValue] = item.widgetBuilder
    }

    func builder(for typeName: String) -> CatalogWidgetBuilder? {
        builders[typeName]
    }
}

// MARK: - EnvironmentKey

private struct CatalogItemOverridesKey: EnvironmentKey {
    static let defaultValue = CatalogItemOverrides()
}

extension EnvironmentValues {
    var a2uiCatalogItemOverrides: CatalogItemOverrides {
        get { self[CatalogItemOverridesKey.self] }
        set { self[CatalogItemOverridesKey.self] = newValue }
    }
}

// MARK: - View extensions

extension View {

    /// Overrides the renderer for a single built-in component type.
    ///
    /// Return `nil` from the builder to fall back to the default built-in renderer.
    ///
    /// Mirrors genui-flutter's `Catalog.copyWith(newItems: [CatalogItem(...)])`.
    ///
    /// Example:
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiCatalogItem(.button) { ctx in
    ///         let props = try? ctx.node.typedProperties(ButtonProperties.self)
    ///         return AnyView(MyButton(label: ctx.buildChild(ctx.node.children[0]),
    ///                                 onTap: { ctx.dispatchEvent(props!.action) }))
    ///     }
    /// ```
    public func a2uiCatalogItem(
        _ type: BuiltinComponentType,
        widgetBuilder: @escaping CatalogWidgetBuilder
    ) -> some View {
        transformEnvironment(\.a2uiCatalogItemOverrides) { overrides in
            overrides.register(CatalogItem(name: type, widgetBuilder: widgetBuilder))
        }
    }

    /// Overrides the renderers for multiple built-in component types at once.
    ///
    /// Later entries in the array override earlier ones for the same type,
    /// and the entire set merges with (and overrides) any overrides already
    /// present higher in the view tree.
    ///
    /// Mirrors genui-flutter's `Catalog.copyWith(newItems: [...])`.
    ///
    /// Example:
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiCatalogItems([
    ///         CatalogItem(name: .button) { ctx in AnyView(MyButton(ctx: ctx)) },
    ///         CatalogItem(name: .card)   { ctx in AnyView(MyCard(ctx: ctx)) },
    ///     ])
    /// ```
    public func a2uiCatalogItems(_ items: [CatalogItem]) -> some View {
        transformEnvironment(\.a2uiCatalogItemOverrides) { overrides in
            for item in items {
                overrides.register(item)
            }
        }
    }
}
