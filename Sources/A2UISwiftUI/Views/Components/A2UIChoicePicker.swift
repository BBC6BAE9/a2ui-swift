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

// MARK: - Spec v0.9 ChoicePicker
//
// Spec properties:
//   - value (required): DynamicStringList — array of selected values
//   - options (required): [ChoicePickerOption] — available choices
//   - displayStyle: "checkbox" (default) | "chips"
//   - variant: "mutuallyExclusive" (default) | "multipleSelection"
//   - filterable: Bool — shows search to filter options
//   - label: DynamicString — label above the component
//
// ## Rendering strategy
//
//   `variant` controls selection semantics (matches Lit/React/Angular/Flutter):
//     mutuallyExclusive (default) → setValue([val]); tapping the same option
//                                   re-emits [val] (radio; no toggle-off).
//     multipleSelection           → toggle in/out of the array.
//
//   Visual differentiation (non-chips only — chips use the same widget for
//   both variants, matching all reference renderers):
//     mutuallyExclusive + checkbox displayStyle → radio circle icon
//     multipleSelection + checkbox displayStyle → checkmark icon
//
//   tvOS (all variants):
//     NavigationLink → secondary page with selection list
//
//   filterable = false:
//     checkbox → inline rows
//     chips    → FlowLayout with capsule buttons
//   filterable = true:
//     sheet + .searchable() + list/chips inside
struct A2UIChoicePicker: View {
    let node: ComponentNode
    let surface: SurfaceModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(ChoicePickerProperties.self) {
            let dc = DataContext(surface: surface, path: dataContextPath)
            let checksError = dc.firstFailingCheckMessage(props.checks)
            VStack(alignment: .leading, spacing: 4) {
                ChoicePickerContent(
                    properties: props,
                    uiState: node.uiState as? MultipleChoiceUIState ?? MultipleChoiceUIState(),
                    surface: surface,
                    dataContextPath: dataContextPath,
                    componentStyle: style.multipleChoiceStyle
                )
                if let msg = checksError {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .a2uiAccessibility(node.accessibility, dataContext: dc)
            .padding(style.leafMargin)
        }
    }
}

// MARK: - ChoicePickerContent

struct ChoicePickerContent: View {
    let properties: ChoicePickerProperties
    var uiState: MultipleChoiceUIState
    let surface: SurfaceModel
    var dataContextPath: String
    var componentStyle: A2UIStyle.MultipleChoiceComponentStyle

    @State private var showFilterSheet = false

    // MARK: Computed

    private var dc: DataContext { DataContext(surface: surface, path: dataContextPath) }

    private var currentSelections: [String] {
        guard let val = properties.value else { return [] }
        return dc.resolve(val)
    }

    private var resolvedOptions: [(label: String, value: String)] {
        properties.options.map { option in
            (
                label: dc.resolve(option.label),
                value: option.value
            )
        }
    }

    private var filteredOptions: [(label: String, value: String)] {
        MultipleChoiceLogic.filter(
            options: resolvedOptions, query: uiState.filterText
        )
    }

    private var isChips: Bool { properties.displayStyle == .chips }

    /// Spec default: `mutuallyExclusive` when `variant` is absent.
    /// All v0.9 reference renderers apply this default (Lit/React/Angular via
    /// Zod `.default()`, Flutter via field-level check). Swift renderer applies
    /// it explicitly here since the schema validation layer was removed.
    private var isMutuallyExclusive: Bool {
        switch properties.variant ?? .mutuallyExclusive {
        case .mutuallyExclusive: return true
        case .multipleSelection: return false
        case .unknown: return true  // unknown values default to spec default
        }
    }

    private var labelText: String? {
        guard let labelVal = properties.label else { return nil }
        let resolved = dc.resolve(labelVal)
        return resolved.isEmpty ? nil : resolved
    }

    // MARK: Body

    var body: some View {
#if os(tvOS)
        tvOSPresentBody
#else
        if properties.filterable == true {
            filterableMultiSelectBody
        } else {
            inlineMultiSelectBody
        }
#endif
    }

    // MARK: - Single Select (variant == "mutuallyExclusive")

#if os(tvOS)
    /// tvOS: NavigationLink to a secondary page with checkmark list.
    @ViewBuilder
    private var tvOSPresentBody: some View {
        let selCount = currentSelections.count
        let summary: String = selCount > 0 ? "\(selCount) selected" : "Select"

        NavigationLink {
            tvOSSelectionPage
        } label: {
            HStack {
                if let desc = labelText {
                    Text(desc)
                }
                Spacer()
                Text(summary)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var tvOSSelectionPage: some View {
        let options = properties.filterable == true ? filteredOptions : resolvedOptions

        let list = List(options, id: \.value) { option in
            let selected = currentSelections.contains(option.value)
            Button {
                toggle(option.value)
            } label: {
                HStack {
                    Text(option.label)
                    Spacer()
                    selectionIndicator(selected: selected)
                }
            }
        }
            .navigationTitle(labelText ?? "Select")

        if properties.filterable == true {
            list.searchable(
                text: Binding(
                    get: { uiState.filterText },
                    set: { uiState.filterText = $0 }
                ),
                prompt: "Filter options…"
            )
        } else {
            list
        }
    }
#endif

    // MARK: - Multi-select Inline (not filterable)

    @ViewBuilder
    private var inlineMultiSelectBody: some View {
        VStack(alignment: .leading) {
            if let desc = labelText {
                Text(desc)
                    .font(componentStyle.descriptionFont)
                    .foregroundStyle(componentStyle.descriptionColor ?? .secondary)
            }

            if isChips {
                chipsGrid(options: resolvedOptions)
            } else {
                checkmarkList(options: resolvedOptions)
            }
        }
    }

    // MARK: - Multi-select Filterable (sheet + searchable)

    @ViewBuilder
    private var filterableMultiSelectBody: some View {
        VStack(alignment: .leading) {
            if let desc = labelText {
                Text(desc)
                    .font(componentStyle.descriptionFont)
                    .foregroundStyle(componentStyle.descriptionColor ?? .secondary)
            }

            Button {
                showFilterSheet = true
            } label: {
                HStack {
                    let count = currentSelections.count
                    if count > 0 {
                        Text("\(count) selected")
                            .foregroundStyle(.primary)
                    } else {
                        Text("Select items")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showFilterSheet) {
            filterSheet
        }
    }

    @ViewBuilder
    private var filterSheet: some View {
        NavigationStack {
            filterSheetContent
                .searchable(
                    text: Binding(
                        get: { uiState.filterText },
                        set: { uiState.filterText = $0 }
                    ),
                    prompt: "Filter options…"
                )
                .navigationTitle(labelText ?? "Select")
#if !os(macOS) && !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showFilterSheet = false }
                    }
                }
        }
#if os(macOS)
        .frame(minWidth: 360, minHeight: 400)
#endif
    }

    @ViewBuilder
    private var filterSheetContent: some View {
        if isChips {
            ScrollView {
                if filteredOptions.isEmpty {
                    ContentUnavailableView.search(text: uiState.filterText)
                } else {
                    chipsGrid(options: filteredOptions)
                        .padding()
                }
            }
        } else {
            List {
                ForEach(filteredOptions, id: \.value) { option in
                    let selected = currentSelections.contains(option.value)
                    Button {
                        toggle(option.value)
                    } label: {
                        HStack {
                            Text(option.label)
                                .foregroundStyle(.primary)
                            Spacer()
                            selectionIndicator(selected: selected)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if filteredOptions.isEmpty {
                    ContentUnavailableView.search(text: uiState.filterText)
                }
            }
        }
    }

    // MARK: - Shared Subviews

    /// Selection indicator icon for non-chips list rows.
    /// - mutuallyExclusive: always shows a radio circle (filled when selected).
    /// - multipleSelection: shows a checkmark only when selected (current behavior).
    /// Mirrors visual differentiation in Lit (`<input type=radio|checkbox>`),
    /// React (same), Angular (same), and Flutter (`RadioListTile` vs `CheckboxListTile`).
    @ViewBuilder
    private func selectionIndicator(selected: Bool) -> some View {
        if isMutuallyExclusive {
            Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(selected ? Color.accentColor : .secondary)
        } else if selected {
            Image(systemName: "checkmark")
                .foregroundStyle(Color.accentColor)
                .fontWeight(.semibold)
        }
    }

    /// Chips layout using custom FlowLayout for wrapping horizontal chips.
    @ViewBuilder
    private func chipsGrid(options: [(label: String, value: String)]) -> some View {
        FlowLayout {
            ForEach(options, id: \.value) { option in
                let selected = currentSelections.contains(option.value)
                chipButton(label: option.label, value: option.value, selected: selected)
            }
        }
    }

    @ViewBuilder
    private func chipButton(label: String, value: String, selected: Bool) -> some View {
        if selected {
            Button { toggle(value) } label: {
                Label(label, systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
#if os(iOS)
            .hoverEffect(.lift)
#elseif os(visionOS)
            .hoverEffect(.highlight)
            .contentShape(.hoverEffect, Capsule(style: .continuous))
#endif
        } else {
            Button { toggle(value) } label: {
                Text(label)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
#if os(iOS)
            .hoverEffect(.lift)
#elseif os(visionOS)
            .hoverEffect(.highlight)
            .contentShape(.hoverEffect, Capsule(style: .continuous))
#endif
        }
    }

    @ViewBuilder
    private func checkmarkList(options: [(label: String, value: String)]) -> some View {
        ForEach(options, id: \.value) { option in
            let selected = currentSelections.contains(option.value)
            Button {
                toggle(option.value)
            } label: {
                HStack {
                    Text(option.label)
                        .foregroundStyle(.primary)
                    Spacer()
                    selectionIndicator(selected: selected)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
#if os(iOS)
            .hoverEffect(.lift)
#elseif os(visionOS)
            .hoverEffect(.highlight)
#endif
        }
    }

    // MARK: - Toggle Logic

    private func toggle(_ value: String) {
        let newSelections = MultipleChoiceLogic.selectionAfterTap(
            value: value,
            in: currentSelections,
            isMutuallyExclusive: isMutuallyExclusive
        )
        guard case .dataBinding(let path) = properties.value else { return }
        try? dc.set(path, value: .array(newSelections.map { .string($0) }))
    }
}
