// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

// MARK: - Data Model

struct CheckboxFilterChipsData: Identifiable {
    let id: String
    let chipLabel: String
    let options: [String]
    let iconName: TravelIcon?
    var selectedOptions: Set<String>
}

// MARK: - View

/// A chip for selecting multiple options from a list.
/// Equivalent to the Flutter `CheckboxFilterChipsInput` catalog component.
struct CheckboxFilterChipsView: View {
    let data: CheckboxFilterChipsData
    var onChanged: ((Set<String>) -> Void)?

    @State private var isShowingOptions = false

    private var displayLabel: String {
        data.selectedOptions.isEmpty ? data.chipLabel : data.selectedOptions.sorted().joined(separator: ", ")
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
                        var newSelection = data.selectedOptions
                        if newSelection.contains(option) {
                            newSelection.remove(option)
                        } else {
                            newSelection.insert(option)
                        }
                        onChanged?(newSelection)
                    } label: {
                        HStack {
                            Text(option)
                            Spacer()
                            if data.selectedOptions.contains(option) {
                                Image(systemName: "checkmark.square.fill")
                                    .foregroundStyle(.blue)
                            } else {
                                Image(systemName: "square")
                                    .foregroundStyle(.gray)
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

/// Renders a `CheckboxFilterChipsInput` from an A2UI `ComponentNode`.
struct A2UICheckboxFilterChipsView: View {
    let node: ComponentNode
    let surface: SurfaceModel

    private var props: [String: AnyCodable] { node.instance.properties }

    var body: some View {
        let chipLabel = A2UIHelpers.resolveString(props["chipLabel"], surface: surface, dataContextPath: node.dataContextPath) ?? ""
        let options = A2UIHelpers.resolveStringList(props["options"], surface: surface, dataContextPath: node.dataContextPath)
        let iconNameStr = props["iconName"]?.stringValue
        let icon = iconNameStr.flatMap { TravelIcon(rawValue: $0) }
        let selected = Set(A2UIHelpers.resolveStringList(props["selectedOptions"], surface: surface, dataContextPath: node.dataContextPath))

        CheckboxFilterChipsView(
            data: CheckboxFilterChipsData(
                id: node.id,
                chipLabel: chipLabel,
                options: options,
                iconName: icon,
                selectedOptions: selected
            )
        ) { newSelected in
            node.instance.properties["selectedOptions"] = .array(newSelected.sorted().map { .string($0) })
        }
    }
}

#Preview("Checkbox Filter") {
    CheckboxFilterChipsView(
        data: CheckboxFilterChipsData(
            id: "amenities",
            chipLabel: "Amenities",
            options: ["Wifi", "Gym", "Pool", "Parking"],
            iconName: nil,
            selectedOptions: ["Wifi", "Gym"]
        )
    )
}
