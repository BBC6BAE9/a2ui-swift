// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

// MARK: - Data Models

struct InputGroupData {
    let submitLabel: String
    var children: [InputChild]
    let actionName: String
}

enum InputChild: Identifiable {
    case optionsFilter(OptionsFilterChipData)
    case checkboxFilter(CheckboxFilterChipsData)
    case dateInput(DateInputChipData)
    case textInput(TextInputChipData)

    var id: String {
        switch self {
        case .optionsFilter(let d): return d.id
        case .checkboxFilter(let d): return d.id
        case .dateInput(let d): return d.id
        case .textInput(let d): return d.id
        }
    }
}

// MARK: - View

/// A group of input chips with a submit button.
/// Equivalent to the Flutter `InputGroup` catalog component.
struct InputGroupView: View {
    @Binding var data: InputGroupData
    var onSubmit: ((InputGroupData) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: 8) {
                ForEach(Array(data.children.enumerated()), id: \.element.id) { index, child in
                    inputChipView(for: child, at: index)
                }
            }

            Button {
                onSubmit?(data)
            } label: {
                Text(data.submitLabel)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding()
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func inputChipView(for child: InputChild, at index: Int) -> some View {
        switch child {
        case .optionsFilter(let chipData):
            OptionsFilterChipView(data: chipData) { newValue in
                var updated = chipData
                updated.value = newValue
                data.children[index] = .optionsFilter(updated)
            }
        case .checkboxFilter(let chipData):
            CheckboxFilterChipsView(data: chipData) { newSelected in
                var updated = chipData
                updated.selectedOptions = newSelected
                data.children[index] = .checkboxFilter(updated)
            }
        case .dateInput(let chipData):
            DateInputChipView(data: chipData) { newDate in
                var updated = chipData
                updated.value = newDate
                data.children[index] = .dateInput(updated)
            }
        case .textInput(let chipData):
            TextInputChipView(data: chipData) { newValue in
                var updated = chipData
                updated.value = newValue
                data.children[index] = .textInput(updated)
            }
        }
    }
}

// MARK: - FlowLayout

/// A simple flow layout that wraps children into multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            let size = result.sizes[index]
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(size)
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
        var sizes: [CGSize]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let idealSize = subview.sizeThatFits(.unspecified)
            let chipWidth = min(idealSize.width, maxWidth)
            let size = CGSize(width: chipWidth, height: idealSize.height)
            if currentX + chipWidth > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            sizes.append(size)
            lineHeight = max(lineHeight, size.height)
            currentX += chipWidth + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return ArrangeResult(
            size: CGSize(width: totalWidth, height: currentY + lineHeight),
            positions: positions,
            sizes: sizes
        )
    }
}

// MARK: - A2UI Wrapper

/// Renders an `InputGroup` from an A2UI `ComponentNode`.
struct A2UIInputGroupView: View {
    let node: ComponentNode
    let children: [ComponentNode]
    let surface: SurfaceModel
    @Environment(\.a2uiActionHandler) private var actionHandler

    private var props: [String: AnyCodable] { node.instance.properties }

    var body: some View {
        let submitLabel = A2UIHelpers.resolveString(props["submitLabel"], surface: surface, dataContextPath: node.dataContextPath) ?? "Submit"

        VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: 8) {
                ForEach(children) { child in
                    A2UIComponentView(node: child, surface: surface)
                }
            }

            Button {
                if let action = A2UIHelpers.resolveAction(props["action"], node: node, surface: surface) {
                    actionHandler?(action)
                }
            } label: {
                Text(submitLabel)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding()
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

#Preview {
    @Previewable @State var data = MockData.tripPreferencesInputGroup
    InputGroupView(data: $data) { submitted in
        print("Submitted: \(submitted.actionName)")
    }
    .padding()
}
