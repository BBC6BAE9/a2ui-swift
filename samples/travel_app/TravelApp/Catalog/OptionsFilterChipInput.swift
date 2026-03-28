// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import v_09


// MARK: - Data Model

struct OptionsFilterChipData: Identifiable {
    let id: String
    let chipLabel: String
    let options: [String]
    let iconName: TravelIcon?
    var value: String?
}

// MARK: - View

/// A chip for selecting a single option from a list of mutually exclusive options.
/// Equivalent to the Flutter `OptionsFilterChipInput` catalog component.
struct OptionsFilterChipView: View {
    let data: OptionsFilterChipData
    var onChanged: ((String?) -> Void)?

    @State private var isShowingOptions = false

    private var displayLabel: String {
        data.value ?? data.chipLabel
    }

    var body: some View {
        Button {
            isShowingOptions = true
        } label: {
            HStack(spacing: 4) {
                if let iconName = data.iconName {
                    Image(systemName: iconName.systemImageName)
                        .font(.caption)
                }
                Text(displayLabel)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.caption2)
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
        .sheet(isPresented: $isShowingOptions) {
            NavigationStack {
                List(data.options, id: \.self) { option in
                    Button {
                        onChanged?(option)
                        isShowingOptions = false
                    } label: {
                        HStack {
                            Text(option)
                            Spacer()
                            if data.value == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                .navigationTitle(data.chipLabel)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { isShowingOptions = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - A2UI Wrapper

/// Renders an `OptionsFilterChipInput` from an A2UI `ComponentNode`.
struct A2UIOptionsFilterChipView: View {
    let node: ComponentNode
    let surface: SurfaceModel

    private var props: [String: AnyCodable] { node.instance.properties }

    var body: some View {
        let chipLabel = A2UIHelpers.resolveString(props["chipLabel"], surface: surface, dataContextPath: node.dataContextPath) ?? ""
        let options = A2UIHelpers.resolveStringList(props["options"], surface: surface, dataContextPath: node.dataContextPath)
        let iconNameStr = props["iconName"]?.stringValue
        let icon = iconNameStr.flatMap { TravelIcon(rawValue: $0) }
        let currentValue = A2UIHelpers.resolveString(props["value"], surface: surface, dataContextPath: node.dataContextPath)

        OptionsFilterChipView(
            data: OptionsFilterChipData(
                id: node.id,
                chipLabel: chipLabel,
                options: options,
                iconName: icon,
                value: currentValue
            )
        ) { newValue in
            node.instance.properties["value"] = newValue.map { .string($0) } ?? .null
        }
    }
}

#Preview("Options Filter") {
    OptionsFilterChipView(
        data: OptionsFilterChipData(
            id: "budget",
            chipLabel: "Budget",
            options: ["Low", "Medium", "High"],
            iconName: .wallet,
            value: "Medium"
        )
    )
}
