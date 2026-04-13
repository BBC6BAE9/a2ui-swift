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

/// Spec v0.9 TextField — input component.
///
/// Spec properties:
/// - `label` (optional): DynamicString
/// - `value` (required): DynamicString — bound to data model
/// - `variant` (optional): `date`, `longText`, `number`, `shortText`, `obscured`
/// - `checks` (optional): [CheckRule]
///
/// ## Rendering strategy: system native, zero hardcoded values.
///
/// Each variant maps to the most appropriate native SwiftUI control:
/// - `shortText` / default → `TextField` with `.textFieldStyle(.roundedBorder)`
/// - `obscured` → `SecureField` with `.textFieldStyle(.roundedBorder)`
/// - `number` → `TextField` + `.keyboardType(.decimalPad)`
/// - `longText` → `TextEditor` (with label above; fallback to `TextField` on watchOS/tvOS)
/// - `date` → `DatePicker` (rendered by `A2UIDateTimeInput`, but fallback `TextField` here)
///
/// No hardcoded spacing, padding, colors, or corner radii — all system defaults.
struct A2UITextField: View {
    let node: ComponentNode
    let surface: SurfaceModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(TextFieldProperties.self) {
            let dc = DataContext(surface: surface, path: dataContextPath)
            let label = props.label.map { dc.resolve($0) } ?? ""
            let binding = a2uiStringBinding(for: props.value, dataContext: dc)
            let checksError = dc.firstFailingCheckMessage(props.checks)

            A2UITextFieldView(
                label: label,
                text: binding,
                variant: props.variant?.rawValue,
                checksErrorMessage: checksError
            )
            .a2uiAccessibility(node.accessibility, dataContext: dc)
            .padding(style.leafMargin)
        }
    }
}
