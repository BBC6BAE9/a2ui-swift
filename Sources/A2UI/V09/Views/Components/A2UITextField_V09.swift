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

/// Spec v0.9 TextField — input component.
///
/// Spec properties:
/// - `label` (required): DynamicString_V09
/// - `value` (optional): DynamicString_V09 — bound to data model
/// - `variant` (optional): `date`, `longText`, `number`, `shortText`, `obscured`
/// - `validationRegexp` (optional): client-side regex validation
/// - `checks` (optional): [CheckRule_V09]
///
/// ## Rendering strategy: system native, zero hardcoded values.
///
/// Each variant maps to the most appropriate native SwiftUI control:
/// - `shortText` / default → `TextField` with `.textFieldStyle(.roundedBorder)`
/// - `obscured` → `SecureField` with `.textFieldStyle(.roundedBorder)`
/// - `number` → `TextField` + `.keyboardType(.decimalPad)`
/// - `longText` → `TextEditor` (with label above; fallback to `TextField` on watchOS/tvOS)
/// - `date` → `DatePicker` (rendered by `A2UIDateTimeInput_V09`, but fallback `TextField` here)
///
/// No hardcoded spacing, padding, colors, or corner radii — all system defaults.
struct A2UITextField_V09: View {
    let node: ComponentNode_V09
    var viewModel: SurfaceViewModel_V09

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(TextFieldProperties_V09.self) {
            let label = viewModel.resolveString(
                props.label, dataContextPath: dataContextPath
            )
            let binding = a2uiStringBinding(for: props.value, viewModel: viewModel, dataContextPath: dataContextPath)

            A2UITextFieldView(
                label: label,
                text: binding,
                variant: props.variant?.rawValue,
                validationRegexp: props.validationRegexp
            )
        }
    }
}
