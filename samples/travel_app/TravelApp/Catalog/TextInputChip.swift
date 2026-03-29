// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

// MARK: - Data Model

struct TextInputChipData: Identifiable {
    let id: String
    let label: String
    var value: String?
    let obscured: Bool
}

// MARK: - View

/// A chip for free text input.
/// Equivalent to the Flutter `TextInputChip` catalog component.
struct TextInputChipView: View {
    let data: TextInputChipData
    var onChanged: ((String) -> Void)?

    @State private var isShowingInput = false
    @State private var textValue: String = ""

    private var displayLabel: String {
        if let value = data.value, !value.isEmpty {
            return data.obscured ? "********" : value
        }
        return data.label
    }

    var body: some View {
        Button {
            textValue = data.value ?? ""
            isShowingInput = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.caption)
                Text(displayLabel)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1)
                    .background(Capsule().fill(Color.accentColor.opacity(0.05)))
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isShowingInput) {
            NavigationStack {
                VStack(spacing: 16) {
                    if data.obscured {
                        SecureField(data.label, text: $textValue)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        TextField(data.label, text: $textValue)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button("Done") {
                        if !textValue.isEmpty {
                            onChanged?(textValue)
                        }
                        isShowingInput = false
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
                .padding()
                .navigationTitle(data.label)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingInput = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - A2UI Wrapper

/// Renders a `TextInputChip` from an A2UI `ComponentNode`.
struct A2UITextInputChipView: View {
    let node: ComponentNode
    let surface: SurfaceModel

    private var props: [String: AnyCodable] { node.instance.properties }

    var body: some View {
        let label = A2UIHelpers.resolveString(props["label"], surface: surface, dataContextPath: node.dataContextPath) ?? "Text"
        let value = A2UIHelpers.resolveString(props["value"], surface: surface, dataContextPath: node.dataContextPath)
        let obscured = A2UIHelpers.resolveBool(props["obscured"], surface: surface, dataContextPath: node.dataContextPath) ?? false

        TextInputChipView(
            data: TextInputChipData(id: node.id, label: label, value: value, obscured: obscured)
        ) { newValue in
            node.instance.properties["value"] = .string(newValue)
        }
    }
}
