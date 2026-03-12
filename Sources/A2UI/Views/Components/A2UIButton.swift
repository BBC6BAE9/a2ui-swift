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
struct A2UIButton: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(ButtonProperties.self),
           let child = node.children.first {
            ButtonActionView(
                props: props,
                componentId: node.baseComponentId,
                dataContextPath: dataContextPath,
                viewModel: viewModel
            ) {
                A2UIComponentView(node: child, viewModel: viewModel)
            }
        }
    }
}

// MARK: - ButtonActionView

/// Wrapper that reads `a2uiActionHandler` from environment and invokes it on tap.
/// v0.8 Button supports `primary: Bool` to toggle between `.borderedProminent` and `.bordered`.
/// When a `ButtonVariantStyle` override is set, the button switches to custom drawing.
struct ButtonActionView<Label: View>: View {
    let props: ButtonProperties
    let componentId: String
    let dataContextPath: String
    var viewModel: SurfaceViewModel
    @ViewBuilder let label: () -> Label

    @Environment(\.a2uiActionHandler) private var actionHandler
    @Environment(\.a2uiStyle) private var style

    private var isPrimary: Bool { props.primary == true }

    private func handleAction() {
        let resolved = viewModel.resolveAction(
            props.action,
            sourceComponentId: componentId,
            dataContextPath: dataContextPath
        )
        viewModel.lastAction = resolved
        if let handler = actionHandler {
            handler(resolved)
        }
    }

    var body: some View {
        let variant = isPrimary ? "primary" : "default"

        if let custom = style.buttonStyles[variant] {
            // Custom drawing path — ButtonVariantStyle override is set
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
            // System ButtonStyle path — native HIG rendering
            if isPrimary {
                SwiftUI.Button(action: handleAction) { label() }
                    .buttonStyle(.borderedProminent)
                    .tint(style.primaryColor)
            } else {
                SwiftUI.Button(action: handleAction) { label() }
                    .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Previews

#Preview("Button - Default") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Button":{"child":"bt","action":{"name":"tap"}}}},{"id":"bt","component":{"Text":{"text":{"literalString":"Default"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Button - Primary") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Button":{"child":"bt","primary":true,"action":{"name":"tap"}}}},{"id":"bt","component":{"Text":{"text":{"literalString":"Primary"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Button - With Action Context") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Button":{"child":"bt","primary":true,"action":{"name":"submit","context":[{"key":"userId","value":{"literalString":"123"}}]}}}},{"id":"bt","component":{"Text":{"text":{"literalString":"Submit"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Button - All Variants") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["b1","b2"]}}}},{"id":"b1","component":{"Button":{"child":"t1","primary":true,"action":{"name":"tap"}}}},{"id":"t1","component":{"Text":{"text":{"literalString":"Primary"}}}},{"id":"b2","component":{"Button":{"child":"t2","action":{"name":"tap"}}}},{"id":"t2","component":{"Text":{"text":{"literalString":"Default"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
