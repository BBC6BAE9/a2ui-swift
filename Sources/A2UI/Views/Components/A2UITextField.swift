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

/// Spec v0.8 TextField — input component.
///
/// Spec properties:
/// - `label` (required): literalString or path
/// - `text` (optional): literalString or path — bound to data model
/// - `textFieldType` (optional): `date`, `longText`, `number`, `shortText`, `obscured`
/// - `validationRegexp` (optional): client-side regex validation
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
    var viewModel: SurfaceViewModel

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(TextFieldProperties.self) {
            let label = viewModel.resolveString(
                props.label, dataContextPath: dataContextPath
            )
            let binding = a2uiStringBinding(for: props.text, viewModel: viewModel, dataContextPath: dataContextPath)

            A2UITextFieldView(
                label: label,
                text: binding,
                variant: props.textFieldType,
                validationRegexp: props.validationRegexp
            )
        }
    }
}

// MARK: - A2UITextFieldView

/// Renders a TextField with variant support and regex validation.
/// Uses native SwiftUI controls: `TextField`, `SecureField`, `TextEditor`.
struct A2UITextFieldView: View {
    let label: String
    @Binding var text: String
    let variant: String?
    let validationRegexp: String?

    @Environment(\.a2uiStyle) private var style
    @State private var isValid = true
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading) {
            fieldForVariant
                .focused($isFocused)
                .onChange(of: text) { validate($1) }
                .onChange(of: isFocused) { _, focused in
                    if !focused { validate(text) }
                }

            if !isValid {
                Text("Input does not match required format")
                    .font(.caption)
                    .foregroundStyle(style.textFieldStyle.errorColor ?? .red)
            }
        }
    }

    @ViewBuilder
    private var fieldForVariant: some View {
        let tfStyle = style.textFieldStyle

        switch variant {
        case "obscured":
            SecureField(label, text: $text)
                #if !os(watchOS) && !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif

        case "longText":
            #if os(watchOS) || os(tvOS)
            SwiftUI.TextField(label, text: $text)
            #else
            VStack(alignment: .leading) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let bg = tfStyle.longTextBackgroundColor {
                    TextEditor(text: $text)
                        .frame(minHeight: tfStyle.longTextMinHeight ?? 100)
                        .scrollContentBackground(.hidden)
                        .padding()
                        .background(bg, in: .rect(cornerRadius: 8, style: .continuous))
                } else {
                    TextEditor(text: $text)
                        .frame(minHeight: tfStyle.longTextMinHeight ?? 100)
                        .scrollContentBackground(.hidden)
                        .padding()
                        .background(.fill.quaternary, in: .rect(cornerRadius: 8, style: .continuous))
                }
            }
            #endif

        case "number":
            SwiftUI.TextField(label, text: $text)
                #if !os(watchOS) && !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif

        case "date":
            // Spec has `date` as a textFieldType — but date input is better served
            // by `DateTimeInput` component. Here we provide a basic text fallback.
            SwiftUI.TextField(label, text: $text)
                #if !os(watchOS) && !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif

        case "shortText":
            SwiftUI.TextField(label, text: $text)
                #if !os(watchOS) && !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif

        default:
            // Unspecified or unknown → standard single-line text field.
            SwiftUI.TextField(label, text: $text)
                #if !os(watchOS) && !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
        }
    }

    private func validate(_ value: String) {
        isValid = Self.isValid(value: value, pattern: validationRegexp)
    }

    /// Pure validation logic — testable without UI.
    static func isValid(value: String, pattern: String?) -> Bool {
        guard let pattern, !pattern.isEmpty else { return true }
        return value.isEmpty || (try? Regex(pattern).wholeMatch(in: value)) != nil
    }
}

// MARK: - Previews

#Preview("TextField - Default") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"TextField":{"label":{"literalString":"Name"},"text":{"path":"/name"}}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"name","valueString":"Jane Doe"}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("TextField - Password") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"TextField":{"label":{"literalString":"Password"},"text":{"path":"/pw"},"textFieldType":"obscured"}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"pw","valueString":"secret"}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("TextField - Long Text") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"TextField":{"label":{"literalString":"Bio"},"text":{"path":"/bio"},"textFieldType":"longText"}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"bio","valueString":"Hello world"}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("TextField - Number") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"TextField":{"label":{"literalString":"Age"},"text":{"path":"/age"},"textFieldType":"number"}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"age","valueString":"25"}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("TextField - Date") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"TextField":{"label":{"literalString":"Birthday"},"text":{"path":"/bday"},"textFieldType":"date"}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"bday","valueString":"1990-01-15"}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("TextField - Short Text") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"TextField":{"label":{"literalString":"Nickname"},"text":{"path":"/nick"},"textFieldType":"shortText"}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"nick","valueString":"JD"}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("TextField - Validation") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"TextField":{"label":{"literalString":"Email"},"text":{"path":"/email"},"validationRegexp":"^[\\\\w.+-]+@[\\\\w-]+\\\\.[a-zA-Z]{2,}$"}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"email","valueString":"jane@example.com"}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
