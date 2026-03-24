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

// MARK: - Spec v0.9 ChoicePicker
//
// Spec properties:
//   - value (required): DynamicStringList_V09 — array of selected values
//   - options (required): [ChoicePickerOption_V09] — available choices
//   - displayStyle: "checkbox" (default) | "chips"
//   - filterable: Bool — shows search to filter options
//   - variant: "multipleSelection" | "mutuallyExclusive" — when "mutuallyExclusive" renders as single-select
//   - label: DynamicString_V09 — label above the component
//
// ## Rendering strategy
//
//   tvOS (all variants):
//     NavigationLink → secondary page with checkmark list
//
//   variant == "mutuallyExclusive" (single-select):
//     chips → horizontal button group (FlowLayout, only one active)
//     macOS + any label contains space (multi-word) → Picker(.radioGroup)
//     otherwise (incl. all iOS) → menu Picker
//
//   variant != "mutuallyExclusive" (multi-select):
//     filterable = false:
//       checkbox → inline checkmark rows
//       chips    → FlowLayout with capsule buttons
//     filterable = true:
//       sheet + .searchable() + list/chips inside
struct A2UIChoicePicker_V09: View {
    let node: ComponentNode_V09
    var viewModel: SurfaceViewModel_V09

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(ChoicePickerProperties_V09.self) {
            ChoicePickerContent_V09(
                properties: props,
                uiState: node.uiState as? MultipleChoiceUIState ?? MultipleChoiceUIState(),
                viewModel: viewModel,
                dataContextPath: dataContextPath,
                componentStyle: style.multipleChoiceStyle
            )
        }
    }
}

// MARK: - ChoicePickerContent_V09

struct ChoicePickerContent_V09: View {
    let properties: ChoicePickerProperties_V09
    var uiState: MultipleChoiceUIState
    var viewModel: SurfaceViewModel_V09
    var dataContextPath: String
    var componentStyle: A2UIStyle.MultipleChoiceComponentStyle

    @State private var showFilterSheet = false

    // MARK: Computed

    private var currentSelections: [String] {
        guard let val = properties.value else { return [] }
        return viewModel.dataStore.resolveStringList(val, dataContextPath: dataContextPath)
    }

    private var resolvedOptions: [(label: String, value: String)] {
        (properties.options ?? []).map { option in
            (
                label: viewModel.resolveString(option.label, dataContextPath: dataContextPath),
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

    private var isSingleSelect: Bool {
        properties.variant == .mutuallyExclusive
    }

    private var labelText: String? {
        guard let labelVal = properties.label else { return nil }
        let resolved = viewModel.resolveString(labelVal, dataContextPath: dataContextPath)
        return resolved.isEmpty ? nil : resolved
    }

    // MARK: Body

    var body: some View {
#if os(tvOS)
        tvOSPresentBody
#else
        if isSingleSelect {
            singleSelectBody
        } else if properties.filterable == true {
            filterableMultiSelectBody
        } else {
            inlineMultiSelectBody
        }
#endif
    }

    // MARK: - Single Select (variant == "mutuallyExclusive")

    /// If any option label contains multiple words (has whitespace), the options
    /// are descriptive phrases → use inline radio so users can read all choices.
    /// All single-word labels (e.g. "Small", "Medium") → compact menu Picker.
    private var hasMultiWordLabels: Bool {
        resolvedOptions.contains { $0.label.contains(" ") }
    }

    @ViewBuilder
    private var singleSelectBody: some View {
        if isChips {
            singleSelectChips
        } else {
#if os(macOS)
            if hasMultiWordLabels {
                singleSelectRadio
            } else {
                singleSelectMenu
            }
#else
            singleSelectMenu
#endif
        }
    }

#if os(macOS)
    /// Inline radio group — macOS only, used when labels are descriptive sentences.
    @ViewBuilder
    private var singleSelectRadio: some View {
        VStack(alignment: .leading) {
            if let desc = labelText {
                Text(desc)
                    .font(componentStyle.descriptionFont)
                    .foregroundStyle(componentStyle.descriptionColor ?? .secondary)
            }

            Picker(labelText ?? "", selection: singleSelectBinding) {
                ForEach(resolvedOptions, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
    }
#endif

    /// Compact menu Picker — used when labels are short words.
    @ViewBuilder
    private var singleSelectMenu: some View {
        let selection = singleSelectBinding

        Picker(labelText ?? "", selection: selection) {
            ForEach(resolvedOptions, id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        }
    }

#if os(tvOS)
    /// tvOS: all variants use NavigationLink to a secondary page.
    @ViewBuilder
    private var tvOSPresentBody: some View {
        let selCount = currentSelections.count
        let summary: String = {
            if isSingleSelect {
                return resolvedOptions.first { $0.value == currentSelections.first }?.label ?? "None"
            } else if selCount > 0 {
                return "\(selCount) selected"
            } else {
                return "Select"
            }
        }()

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
                    if selected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                            .fontWeight(.semibold)
                    }
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

    private var singleSelectBinding: Binding<String> {
        Binding<String>(
            get: { currentSelections.first ?? "" },
            set: { newValue in
                guard case .dataBinding(let path) = properties.value else { return }
                viewModel.dataStore.setStringArray(
                    path: path,
                    values: newValue.isEmpty ? [] : [newValue],
                    dataContextPath: dataContextPath
                )
            }
        )
    }

    /// Chips for single-select — horizontal group, only one active at a time.
    @ViewBuilder
    private var singleSelectChips: some View {
        VStack(alignment: .leading) {
            if let desc = labelText {
                Text(desc)
                    .font(componentStyle.descriptionFont)
                    .foregroundStyle(componentStyle.descriptionColor ?? .secondary)
            }
            chipsGrid(options: resolvedOptions)
        }
    }

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
                            if selected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .fontWeight(.semibold)
                            }
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
                    if selected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                            .fontWeight(.semibold)
                    }
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
        let maxAllowed: Int? = properties.variant == .mutuallyExclusive ? 1 : nil
        let newSelections = MultipleChoiceLogic.toggle(
            value: value,
            in: currentSelections,
            maxAllowed: maxAllowed
        )
        guard case .dataBinding(let path) = properties.value else { return }
        viewModel.dataStore.setStringArray(
            path: path, values: newSelections, dataContextPath: dataContextPath
        )
    }
}
