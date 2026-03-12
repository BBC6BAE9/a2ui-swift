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

/// Spec v0.8 CheckBox — boolean toggle input.
///
/// Spec properties:
/// - `label` (required): literalString or path — text next to the checkbox
/// - `value` (required): literalBoolean or path — bound to data model
///
/// ## Rendering strategy: system `Toggle`, zero hardcoded values.
///
/// Maps directly to SwiftUI `Toggle` **without specifying `.toggleStyle()`**,
/// letting the system use `.automatic` on every platform. This is intentional:
/// - Apple is gradually unifying macOS toward iOS-style controls (e.g. Sequoia).
/// - Not specifying a style means our UI automatically follows platform evolution.
/// - If we forced `.switch` on macOS, we'd lose native checkbox in contexts where
///   the system still prefers it (e.g. Form, Settings).
/// - Users who need a specific style can override via `CheckBoxComponentStyle`.
///
/// ## Platform behavior (`.automatic`):
/// - iOS / visionOS: switch
/// - macOS: checkbox (evolving toward switch in newer OS versions)
/// - watchOS: switch
/// - tvOS: button-toggle
struct A2UICheckBox: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(CheckBoxProperties.self) {
            let label = viewModel.resolveString(
                props.label, dataContextPath: dataContextPath
            )
            let cbStyle = style.checkBoxStyle

            Toggle(isOn: a2uiBoolBinding(for: props.value, viewModel: viewModel, dataContextPath: dataContextPath)) {
                Text(label)
                    .font(cbStyle.labelFont)
                    .foregroundStyle(cbStyle.labelColor ?? .primary)
            }
            .tint(cbStyle.tintColor)
        }
    }
}

// MARK: - Previews

#Preview("CheckBox") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["cb1","cb2"]}}}},{"id":"cb1","component":{"CheckBox":{"label":{"literalString":"Accept Terms"},"value":{"path":"/terms"}}}},{"id":"cb2","component":{"CheckBox":{"label":{"literalString":"Subscribe to Newsletter"},"value":{"path":"/newsletter"}}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"terms","valueBool":true},{"key":"newsletter","valueBool":false}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
