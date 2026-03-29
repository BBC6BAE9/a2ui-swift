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

/// Recursively renders a pre-resolved `ComponentNode` and its children.
public struct A2UIComponentView: View {
    public let node: ComponentNode
    public let surface: SurfaceModel

    public init(node: ComponentNode, surface: SurfaceModel) {
        self.node = node
        self.surface = surface
    }

    @Environment(\.a2uiCatalogItemOverrides) private var catalogOverrides
    @Environment(\.a2uiActionHandler) private var actionHandler

    public var body: some View {
        renderComponent(node.type)
            .modifier(WeightModifier(weight: node.weight))
    }

    @ViewBuilder
    private func renderComponent(_ type: ComponentType) -> some View {
        // Check for a CatalogItem override first.
        // Mirrors genui-flutter's Catalog.buildWidget() which looks up items by name
        // before falling back to default rendering.
        if case .custom = type {
            // Custom components are never in the override table — always routed to A2UICustom.
            A2UICustom(node: node, surface: surface)
        } else if let overrideView = resolveOverride(for: type) {
            overrideView
        } else {
            builtinComponent(for: type)
        }
    }

    /// Attempts to resolve a `CatalogItem` override for the given type.
    /// Returns `nil` if no override is registered, or if the registered builder returns `nil`.
    private func resolveOverride(for type: ComponentType) -> AnyView? {
        guard let typeName = builtinTypeName(for: type),
              let builder = catalogOverrides.builder(for: typeName)
        else { return nil }

        let ctx = makeCatalogItemContext()
        return builder(ctx)
    }

    /// Builds the `CatalogItemContext` passed to a `CatalogWidgetBuilder` closure.
    /// Mirrors genui-flutter's construction of `CatalogItemContext` inside `Catalog.buildWidget()`.
    private func makeCatalogItemContext() -> CatalogItemContext {
        // Capture surface and actionHandler for use inside the closures below.
        let surface = surface
        let node = node
        let actionHandler = actionHandler

        return CatalogItemContext(
            node: node,
            surface: surface,
            _buildChild: { childNode in
                AnyView(A2UIComponentView(node: childNode, surface: surface))
            },
            _buildDefault: {
                // Route directly to builtinComponent — bypasses the override table,
                // so calling buildDefaultView() inside a CatalogWidgetBuilder is safe.
                AnyView(
                    A2UIBuiltinView(node: node, surface: surface)
                        .modifier(WeightModifier(weight: node.weight))
                )
            },
            _dispatchEvent: { action in
                let dc = DataContext(surface: surface, path: node.dataContextPath)
                switch action {
                case .event(let name, let ctx):
                    var resolvedContext: [String: AnyCodable] = [:]
                    if let ctx {
                        for (key, dv) in ctx {
                            resolvedContext[key] = dc.resolveDynamicValue(dv) ?? .null
                        }
                    }
                    surface.dispatchAction(
                        name: name,
                        sourceComponentId: node.baseComponentId,
                        context: resolvedContext
                    )
                    if let handler = actionHandler {
                        handler(ResolvedAction(
                            name: name,
                            sourceComponentId: node.baseComponentId,
                            context: resolvedContext
                        ))
                    }
                case .functionCall(let fc):
                    _ = dc.resolveDynamicValue(.functionCall(fc))
                }
            },
            _reportError: { error in
                surface.dispatchError(
                    code: "CATALOG_ITEM_ERROR",
                    message: error.localizedDescription
                )
            }
        )
    }

    /// Maps a `ComponentType` to its raw string name for override lookup.
    /// Returns `nil` for `.custom` (handled separately).
    private func builtinTypeName(for type: ComponentType) -> String? {
        switch type {
        case .Text:          return BuiltinComponentType.text.rawValue
        case .Image:         return BuiltinComponentType.image.rawValue
        case .Icon:          return BuiltinComponentType.icon.rawValue
        case .Video:         return BuiltinComponentType.video.rawValue
        case .AudioPlayer:   return BuiltinComponentType.audioPlayer.rawValue
        case .Row:           return BuiltinComponentType.row.rawValue
        case .Column:        return BuiltinComponentType.column.rawValue
        case .List:          return BuiltinComponentType.list.rawValue
        case .Card:          return BuiltinComponentType.card.rawValue
        case .Tabs:          return BuiltinComponentType.tabs.rawValue
        case .Divider:       return BuiltinComponentType.divider.rawValue
        case .Modal:         return BuiltinComponentType.modal.rawValue
        case .Button:        return BuiltinComponentType.button.rawValue
        case .CheckBox:      return BuiltinComponentType.checkBox.rawValue
        case .TextField:     return BuiltinComponentType.textField.rawValue
        case .DateTimeInput: return BuiltinComponentType.dateTimeInput.rawValue
        case .ChoicePicker:  return BuiltinComponentType.choicePicker.rawValue
        case .Slider:        return BuiltinComponentType.slider.rawValue
        case .custom:        return nil
        }
    }

    /// The original built-in switch — unchanged.
    @ViewBuilder
    private func builtinComponent(for type: ComponentType) -> some View {
        switch type {
        case .Text:         A2UIText(node: node, surface: surface)
        case .Image:        A2UIImage(node: node, surface: surface)
        case .Column:       A2UIColumn(node: node, surface: surface)
        case .Row:          A2UIRow(node: node, surface: surface)
        case .Card:         A2UICard(node: node, surface: surface)
        case .Button:       A2UIButton(node: node, surface: surface)
        case .Icon:         A2UIIcon(node: node, surface: surface)
        case .Divider:      A2UIDivider(node: node, surface: surface)
        case .TextField:    A2UITextField(node: node, surface: surface)
        case .CheckBox:     A2UICheckBox(node: node, surface: surface)
        case .Slider:       A2UISlider(node: node, surface: surface)
        case .DateTimeInput:A2UIDateTimeInput(node: node, surface: surface)
        case .List:         A2UIList(node: node, surface: surface)
        case .Video:        A2UIVideo(node: node, surface: surface)
        case .AudioPlayer:  A2UIAudioPlayer(node: node, surface: surface)
        case .Tabs:         A2UITabs(node: node, surface: surface)
        case .Modal:        A2UIModal(node: node, surface: surface)
        case .ChoicePicker: A2UIChoicePicker(node: node, surface: surface)
        case .custom:       A2UICustom(node: node, surface: surface)
        }
    }
}

// MARK: - A2UIBuiltinView

/// Internal view that renders a component using only the built-in renderers,
/// completely bypassing the `CatalogItem` override table.
///
/// Used by `CatalogItemContext.buildDefaultView()` so that builders can wrap
/// the default rendering without risking infinite recursion.
struct A2UIBuiltinView: View {
    let node: ComponentNode
    let surface: SurfaceModel

    var body: some View {
        switch node.type {
        case .Text:         A2UIText(node: node, surface: surface)
        case .Image:        A2UIImage(node: node, surface: surface)
        case .Column:       A2UIColumn(node: node, surface: surface)
        case .Row:          A2UIRow(node: node, surface: surface)
        case .Card:         A2UICard(node: node, surface: surface)
        case .Button:       A2UIButton(node: node, surface: surface)
        case .Icon:         A2UIIcon(node: node, surface: surface)
        case .Divider:      A2UIDivider(node: node, surface: surface)
        case .TextField:    A2UITextField(node: node, surface: surface)
        case .CheckBox:     A2UICheckBox(node: node, surface: surface)
        case .Slider:       A2UISlider(node: node, surface: surface)
        case .DateTimeInput:A2UIDateTimeInput(node: node, surface: surface)
        case .List:         A2UIList(node: node, surface: surface)
        case .Video:        A2UIVideo(node: node, surface: surface)
        case .AudioPlayer:  A2UIAudioPlayer(node: node, surface: surface)
        case .Tabs:         A2UITabs(node: node, surface: surface)
        case .Modal:        A2UIModal(node: node, surface: surface)
        case .ChoicePicker: A2UIChoicePicker(node: node, surface: surface)
        case .custom:       A2UICustom(node: node, surface: surface)
        }
    }
}
