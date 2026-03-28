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

/// Spec v0.9 CheckBox — boolean toggle input.
///
/// Spec properties:
/// - `label` (required): DynamicString_V09 — text next to the checkbox
/// - `value` (required): DynamicBoolean_V09 — bound to data model
///
/// ## Rendering strategy: system `Toggle`, zero hardcoded values.
///
/// Maps directly to SwiftUI `Toggle` **without specifying `.toggleStyle()`**,
/// letting the system use `.automatic` on every platform.
struct A2UICheckBox_V09: View {
    let node: ComponentNode_V09
    var viewModel: SurfaceViewModel_V09

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(CheckBoxProperties_V09.self) {
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
