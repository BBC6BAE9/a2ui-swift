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

/// # Button
/// Uses native SwiftUI `Button` with `.borderedProminent` / `.bordered` for system HIG rendering.
/// When `A2UIStyle.buttonStyles` provides a `ButtonVariantStyle` override, switches to custom
/// drawing (plain style + manual background/padding/radius) so the host app can fully restyle.
/// The child is an arbitrary component tree (typically Text), not a plain string label.
struct A2UIButton_V09: View {
    let node: ComponentNode_V09
    var viewModel: SurfaceViewModel_V09

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(ButtonProperties_V09.self),
           let child = node.children.first {
            ButtonActionView_V09(
                props: props,
                componentId: node.baseComponentId,
                dataContextPath: dataContextPath,
                viewModel: viewModel
            ) {
                A2UIComponentView_V09(node: child, viewModel: viewModel)
            }
        }
    }
}

// MARK: - ButtonActionView_V09

/// Wrapper that reads `a2uiActionHandler` from environment and invokes it on tap.
/// v0.9 Button supports `variant: String?` ("default", "primary", "borderless") instead of `primary: Bool`.
/// When a `ButtonVariantStyle` override is set, the button switches to custom drawing.
struct ButtonActionView_V09<Label: View>: View {
    let props: ButtonProperties_V09
    let componentId: String
    let dataContextPath: String
    var viewModel: SurfaceViewModel_V09
    @ViewBuilder let label: () -> Label

    @Environment(\.a2uiActionHandler) private var actionHandler
    @Environment(\.a2uiStyle) private var style

    private var variant: ButtonVariant_V09_Enum { props.variant ?? .default }

    private func handleAction() {
        guard let resolved = viewModel.resolveAction(
            props.action,
            sourceComponentId: componentId,
            dataContextPath: dataContextPath
        ) else { return }
        viewModel.lastAction = resolved
        if let handler = actionHandler {
            handler(resolved)
        }
    }

    var body: some View {
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
}
