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

/// # Button
/// Uses native SwiftUI `Button` with `.borderedProminent` / `.bordered` for system HIG rendering.
/// When `A2UIStyle.buttonStyles` provides a `ButtonVariantStyle` override, switches to custom
/// drawing (plain style + manual background/padding/radius) so the host app can fully restyle.
/// The child is an arbitrary component tree (typically Text), not a plain string label.
struct A2UIButton: View {
    let node: ComponentNode
    let surface: SurfaceModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(ButtonProperties.self),
           let child = node.children.first {
            let dc = DataContext(surface: surface, path: dataContextPath)
            ButtonActionView(
                props: props,
                componentId: node.baseComponentId,
                dataContextPath: dataContextPath,
                surface: surface
            ) {
                A2UIComponentView(node: child, surface: surface)
            }
            .a2uiAccessibility(node.accessibility, dataContext: dc)
            .padding(style.leafMargin)
        }
    }
}

// MARK: - ButtonActionView

/// Wrapper that reads `a2uiActionHandler` from environment and invokes it on tap.
/// v0.9 Button supports `variant: String?` ("default", "primary", "borderless") instead of `primary: Bool`.
/// When a `ButtonVariantStyle` override is set, the button switches to custom drawing.
struct ButtonActionView<Label: View>: View {
    let props: ButtonProperties
    let componentId: String
    let dataContextPath: String
    let surface: SurfaceModel
    @ViewBuilder let label: () -> Label

    @Environment(\.a2uiActionHandler) private var actionHandler
    @Environment(\.a2uiStyle) private var style

    private var variant: ButtonVariant_Enum { props.variant ?? .default }

    private func handleAction() {
        let action = props.action
        let dc = DataContext(surface: surface, path: dataContextPath)
        switch action {
        case .event(let name, let ctx):
            var resolvedContext: [String: AnyCodable] = [:]
            if let ctx = ctx {
                for (key, dv) in ctx {
                    resolvedContext[key] = dc.resolveDynamicValue(dv) ?? .null
                }
            }
            // Dispatch to SurfaceModel → MessageProcessor → server.
            // Context is resolved before dispatch, mirroring WebCore where the renderer
            // calls DataContext.resolveAction() before surface.dispatchAction().
            surface.dispatchAction(name: name, sourceComponentId: componentId, context: resolvedContext)
            // Notify the host app's local SwiftUI action handler.
            if let handler = actionHandler {
                handler(ResolvedAction(name: name, sourceComponentId: componentId, context: resolvedContext))
            }
        case .functionCall(let fc):
            // Pure client-side execution: resolve via DataContext (handles arg resolution,
            // function invocation, and error dispatching). No server dispatch or actionHandler
            // notification needed — there is no server event name.
            _ = dc.resolveDynamicValue(.functionCall(fc))
        }
    }

    var body: some View {
        // Spec §617 (a2ui_protocol.md): "If any check fails, the button is automatically disabled."
        // firstFailingCheckMessage reads PathSlots inside body, so SwiftUI tracks deps reactively.
        let dc = DataContext(surface: surface, path: dataContextPath)
        let isDisabled = dc.firstFailingCheckMessage(props.checks) != nil

        Group {
            if let custom = style.buttonStyles[variant.rawValue] {
                // Custom drawing path -- ButtonVariantStyle override is set
                SwiftUI.Button(action: handleAction) { label() }
                    .buttonStyle(.plain)
                    .foregroundStyle(custom.foregroundColor ?? .primary)
                    .padding(.horizontal, custom.horizontalPadding ?? 16)
                    .padding(.vertical, custom.verticalPadding ?? 8)
                    .background(
                        RoundedRectangle(cornerRadius: custom.cornerRadius ?? 8)
                            .fill(custom.backgroundColor ?? .clear)
                    )
            } else {
                // System ButtonStyle path -- native HIG rendering
                switch variant {
                case .primary:
                    SwiftUI.Button(action: handleAction) { label() }
                        .buttonStyle(.borderedProminent)
                        .tint(style.primaryColor)
                case .borderless:
                    SwiftUI.Button(action: handleAction) { label() }
                        .buttonStyle(.borderless)
                default:
                    SwiftUI.Button(action: handleAction) { label() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .disabled(isDisabled)
    }
}
