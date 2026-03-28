// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import v_09

// MARK: - Data Model

struct DateInputChipData: Identifiable {
    let id: String
    var value: Date?
    let label: String
}

// MARK: - View

/// A chip for date input with a date picker sheet.
/// Equivalent to the Flutter `DateInputChip` catalog component.
struct DateInputChipView: View {
    let data: DateInputChipData
    var onChanged: ((Date) -> Void)?

    @State private var isShowingPicker = false
    @State private var selectedDate: Date = Date()

    private var displayLabel: String {
        if let date = data.value {
            return "\(data.label): \(date.formatted(date: .abbreviated, time: .omitted))"
        }
        return data.label
    }

    var body: some View {
        Button {
            selectedDate = data.value ?? Date()
            isShowingPicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
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
        .sheet(isPresented: $isShowingPicker) {
            NavigationStack {
                DatePicker(
                    data.label,
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle(data.label)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onChanged?(selectedDate)
                            isShowingPicker = false
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingPicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - A2UI Wrapper

/// Renders a `DateInputChip` from an A2UI `ComponentNode`.
struct A2UIDateInputChipView: View {
    let node: ComponentNode
    let surface: SurfaceModel

    private var props: [String: AnyCodable] { node.instance.properties }

    var body: some View {
        let label = A2UIHelpers.resolveString(props["label"], surface: surface, dataContextPath: node.dataContextPath) ?? "Date"
        let dateStr = A2UIHelpers.resolveString(props["value"], surface: surface, dataContextPath: node.dataContextPath)
        let date = dateStr.flatMap { parseDateString($0) }

        DateInputChipView(
            data: DateInputChipData(id: node.id, value: date, label: label)
        ) { newDate in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            node.instance.properties["value"] = .string(formatter.string(from: newDate))
        }
    }

    private func parseDateString(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: str)
    }
}
