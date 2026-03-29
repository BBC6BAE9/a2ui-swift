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

// MARK: - BuiltinComponentType

/// Type-safe enumeration of all standard A2UI built-in component names.
///
/// Mirrors the string-based `CatalogItem.name` used in genui-flutter's `BasicCatalogItems`,
/// but provides compile-time safety so callers cannot mis-spell a component name.
public enum BuiltinComponentType: String, CaseIterable, Sendable {
    case text         = "Text"
    case image        = "Image"
    case icon         = "Icon"
    case video        = "Video"
    case audioPlayer  = "AudioPlayer"
    case row          = "Row"
    case column       = "Column"
    case list         = "List"
    case card         = "Card"
    case tabs         = "Tabs"
    case divider      = "Divider"
    case modal        = "Modal"
    case button       = "Button"
    case checkBox     = "CheckBox"
    case textField    = "TextField"
    case dateTimeInput = "DateTimeInput"
    case choicePicker = "ChoicePicker"
    case slider       = "Slider"
}

// MARK: - CatalogWidgetBuilder

/// A closure that builds a SwiftUI view for a component.
///
/// Return `nil` to fall back to the built-in renderer for that component type.
/// Mirrors genui-flutter's `CatalogWidgetBuilder = Widget Function(CatalogItemContext)`.
///
/// The closure runs on the `@MainActor` because SwiftUI view construction is
/// always performed on the main thread.
public typealias CatalogWidgetBuilder = @MainActor (_ context: CatalogItemContext) -> AnyView?

// MARK: - CatalogItemContext

/// Context passed to a `CatalogWidgetBuilder` closure.
///
/// Provides everything the builder needs: the component's data, a way to render
/// child components, access to the reactive data model, and action dispatching.
///
/// Mirrors genui-flutter's `CatalogItemContext`.
public struct CatalogItemContext {

    /// The component node being rendered (contains typed properties via `typedProperties<T>()`).
    public let node: ComponentNode

    /// The surface this component belongs to.
    public let surface: SurfaceModel

    /// The `DataContext` scoped to this component's data path.
    /// Use this to resolve `DynamicString`, `DynamicNumber`, `DynamicBoolean`, etc.
    /// Mirrors genui-flutter's `itemContext.dataContext`.
    public var dataContext: DataContext {
        DataContext(surface: surface, path: node.dataContextPath)
    }

    /// Builds a child component node into a SwiftUI view.
    ///
    /// Mirrors genui-flutter's `itemContext.buildChild(String id)`.
    /// Pass one of the nodes from `node.children`.
    @MainActor
    public func buildChild(_ childNode: ComponentNode) -> AnyView {
        _buildChild(childNode)
    }

    /// Dispatches a resolved `Action` (event or functionCall) from this component.
    ///
    /// For `.event` actions, resolves the context values via `dataContext` and dispatches
    /// to both the server (via `SurfaceModel.dispatchAction`) and the local SwiftUI
    /// `a2uiActionHandler` environment value — mirroring what the built-in components do.
    ///
    /// Mirrors genui-flutter's `itemContext.dispatchEvent(UserActionEvent(...))`.
    public func dispatchEvent(_ action: Action) {
        _dispatchEvent(action)
    }

    /// Reports an error that occurred while building this component.
    ///
    /// Routes to `SurfaceModel.dispatchError` with code `"CATALOG_ITEM_ERROR"`.
    /// Mirrors genui-flutter's `itemContext.reportError(error, stack)`.
    public func reportError(_ error: Error) {
        _reportError(error)
    }

    /// Builds the default built-in view for this component, bypassing any registered overrides.
    ///
    /// Use this when you want to wrap or decorate the default rendering rather than
    /// replacing it entirely — e.g. add padding around the default `Text` renderer
    /// without re-implementing text styling from scratch.
    ///
    /// Calling this inside a `CatalogWidgetBuilder` is safe and will never recurse,
    /// because it routes directly to the built-in renderer, skipping the override table.
    @MainActor
    public func buildDefaultView() -> AnyView {
        _buildDefault()
    }

    // MARK: Internal init

    /// Internal storage for the `buildChild` closure. Uses `@MainActor` because
    /// constructing SwiftUI views (`A2UIComponentView`) requires the main actor.
    let _buildChild: @MainActor (ComponentNode) -> AnyView

    /// Internal storage for `buildDefaultView` — routes to the built-in renderer directly.
    let _buildDefault: @MainActor () -> AnyView

    /// Internal storage for the `dispatchEvent` closure.
    let _dispatchEvent: @Sendable (Action) -> Void

    /// Internal storage for the `reportError` closure.
    let _reportError: @Sendable (Error) -> Void
}

// MARK: - CatalogItem

/// Defines an override for a single built-in A2UI component.
///
/// When registered via `.a2uiCatalogItem(_:)` or `.a2uiCatalogItems(_:)`, the
/// `widgetBuilder` closure is called instead of the default built-in renderer
/// whenever a component of the matching type is encountered in the tree.
///
/// Mirrors genui-flutter's `CatalogItem { name, dataSchema, widgetBuilder }`.
/// The `dataSchema` field is omitted here because schemas are already defined
/// at the protocol level and do not need to be re-declared per renderer.
public struct CatalogItem {

    /// The built-in component type this item overrides.
    ///
    /// Mirrors genui-flutter's `CatalogItem.name` (String), but uses a type-safe enum.
    public let name: BuiltinComponentType

    /// The closure that builds the replacement view.
    ///
    /// Return `nil` to fall back to the default built-in renderer.
    /// Mirrors genui-flutter's `CatalogItem.widgetBuilder`.
    public let widgetBuilder: CatalogWidgetBuilder

    /// Creates a new `CatalogItem`.
    ///
    /// - Parameters:
    ///   - name: The built-in component type to override.
    ///   - widgetBuilder: A closure that receives a `CatalogItemContext` and returns
    ///     an `AnyView`, or `nil` to defer to the default renderer.
    public init(name: BuiltinComponentType, widgetBuilder: @escaping CatalogWidgetBuilder) {
        self.name = name
        self.widgetBuilder = widgetBuilder
    }
}
