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

// MARK: - Spec v0.8 MultipleChoice
//
// Spec properties:
//   - selections (required): literalArray or path — array of selected values
//   - options (required): [{label, value}] — available choices
//   - variant: "checkbox" (default) | "chips"
//   - filterable: Bool — shows search to filter options
//   - maxAllowedSelections: Int — when == 1 renders as single-select
//   - description: literalString or path — label above the component
//
// ## Rendering strategy
//
//   tvOS (all variants):
//     NavigationLink → secondary page with checkmark list
//
//   maxAllowedSelections == 1 (single-select):
//     chips → horizontal button group (FlowLayout, only one active)
//     macOS + any label contains space (multi-word) → Picker(.radioGroup)
//     otherwise (incl. all iOS) → menu Picker
//
//   maxAllowedSelections != 1 (multi-select):
//     filterable = false:
//       checkbox → inline checkmark rows
//       chips    → FlowLayout with capsule buttons
//     filterable = true:
//       sheet + .searchable() + list/chips inside
//
// ## Platform differences
//   - hover: iOS .hoverEffect(.lift), macOS .onHover+.brightness,
//            visionOS .hoverEffect(.highlight), tvOS/watchOS: none
//   - tvOS: no inline controls — always present a secondary List page
//   - watchOS chips: may show fewer per row (FlowLayout handles naturally)
struct A2UIMultipleChoice: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel
    
    @Environment(\.a2uiStyle) private var style
    
    private var dataContextPath: String { node.dataContextPath }
    
    var body: some View {
        if let props = try? node.payload.typedProperties(MultipleChoiceProperties.self) {
            MultipleChoiceContent(
                properties: props,
                uiState: node.uiState as? MultipleChoiceUIState ?? MultipleChoiceUIState(),
                viewModel: viewModel,
                dataContextPath: dataContextPath,
                componentStyle: style.multipleChoiceStyle
            )
        }
    }
}

// MARK: - MultipleChoiceContent

struct MultipleChoiceContent: View {
    let properties: MultipleChoiceProperties
    var uiState: MultipleChoiceUIState
    var viewModel: SurfaceViewModel
    var dataContextPath: String
    var componentStyle: A2UIStyle.MultipleChoiceComponentStyle
    
    @State private var showFilterSheet = false
    
    // MARK: Computed
    
    private var currentSelections: [String] {
        guard let val = properties.selections else { return [] }
        return viewModel.resolveStringArray(val, dataContextPath: dataContextPath)
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
    
    private var isChips: Bool { properties.variant == "chips" }
    
    private var isSingleSelect: Bool {
        properties.maxAllowedSelections == 1
    }
    
    private var descriptionText: String? {
        guard let labelVal = properties.description else { return nil }
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
    
    // MARK: - Single Select (maxAllowedSelections == 1)
    
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
            if let desc = descriptionText {
                Text(desc)
                    .font(componentStyle.descriptionFont)
                    .foregroundStyle(componentStyle.descriptionColor ?? .secondary)
            }
            
            Picker(descriptionText ?? "", selection: singleSelectBinding) {
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
        
        Picker(descriptionText ?? "", selection: selection) {
            ForEach(resolvedOptions, id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        }
    }
    
#if os(tvOS)
    /// tvOS: all variants use NavigationLink to a secondary page.
    /// The page content is chips (ScrollView + HStack of .card buttons) or list (checkmark rows).
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
                if let desc = descriptionText {
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
            .navigationTitle(descriptionText ?? "Select")
        
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
                guard let path = properties.selections?.path else { return }
                viewModel.setStringArray(
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
            if let desc = descriptionText {
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
            if let desc = descriptionText {
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
            if let desc = descriptionText {
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
                .navigationTitle(descriptionText ?? "Select")
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
        let newSelections = MultipleChoiceLogic.toggle(
            value: value,
            in: currentSelections,
            maxAllowed: properties.maxAllowedSelections
        )
        guard let path = properties.selections?.path else { return }
        viewModel.setStringArray(
            path: path, values: newSelections, dataContextPath: dataContextPath
        )
    }
}

// MARK: - Pure Logic (unit-testable)

/// Pure functions for MultipleChoice selection and filtering logic.
/// These are extracted from the View for unit testing.
enum MultipleChoiceLogic {
    
    /// Toggle a value in the selections array, respecting maxAllowed.
    static func toggle(
        value: String,
        in selections: [String],
        maxAllowed: Int?
    ) -> [String] {
        var result = selections
        if let idx = result.firstIndex(of: value) {
            result.remove(at: idx)
        } else {
            if maxAllowed == 1 {
                result = [value]
            } else if let max = maxAllowed, result.count >= max {
                return result
            } else {
                result.append(value)
            }
        }
        return result
    }
    
    /// Filter options by query string (case-insensitive substring match on label).
    static func filter(
        options: [(label: String, value: String)],
        query: String
    ) -> [(label: String, value: String)] {
        guard !query.isEmpty else { return options }
        return options.filter {
            $0.label.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - FlowLayout (Chips)

/// A wrapping horizontal layout for chips, using the Layout protocol.
/// Spacing is not hardcoded — uses system default when nil.
struct FlowLayout: Layout {
    var spacing: CGFloat?
    
    func sizeThatFits(
        proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }
    
    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
    }
    
    private func arrange(
        proposal: ProposedViewSize, subviews: Subviews
    ) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        let gap = spacing ?? 8
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + gap
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + gap
        }
        
        return ArrangeResult(
            size: CGSize(width: maxWidth, height: y + rowHeight),
            positions: positions
        )
    }
}

// MARK: - Previews

#Preview("Single Select - Radio (long labels)") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Show scroll bars"},"selections":{"path":"/scroll"},"maxAllowedSelections":1,"options":[{"label":{"literalString":"Automatically based on mouse or trackpad"},"value":"auto"},{"label":{"literalString":"When scrolling"},"value":"scroll"},{"label":{"literalString":"Always"},"value":"always"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"scroll","valueMap":[{"key":"0","valueString":"auto"}]}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Single Select - Menu (short labels)") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Icon size"},"selections":{"path":"/iconSize"},"maxAllowedSelections":1,"options":[{"label":{"literalString":"Small"},"value":"small"},{"label":{"literalString":"Medium"},"value":"medium"},{"label":{"literalString":"Large"},"value":"large"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"iconSize","valueMap":[{"key":"0","valueString":"medium"}]}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Single Select - Chips") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Size"},"selections":{"path":"/size"},"maxAllowedSelections":1,"variant":"chips","options":[{"label":{"literalString":"Small"},"value":"S"},{"label":{"literalString":"Medium"},"value":"M"},{"label":{"literalString":"Large"},"value":"L"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"size","valueMap":[{"key":"0","valueString":"M"}]}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Multi-select - Checkmark") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Fruits"},"selections":{"path":"/favorites"},"options":[{"label":{"literalString":"Apple"},"value":"A"},{"label":{"literalString":"Banana"},"value":"B"},{"label":{"literalString":"Cherry"},"value":"C"},{"label":{"literalString":"Date"},"value":"D"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"favorites","valueMap":[{"key":"0","valueString":"A"},{"key":"1","valueString":"C"}]}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Multi-select - Chips") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Tags"},"selections":{"path":"/tags"},"variant":"chips","options":[{"label":{"literalString":"Work"},"value":"work"},{"label":{"literalString":"Home"},"value":"home"},{"label":{"literalString":"Urgent"},"value":"urgent"},{"label":{"literalString":"Later"},"value":"later"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"tags","valueMap":[{"key":"0","valueString":"work"},{"key":"1","valueString":"urgent"}]}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Filterable - Checkmark") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Countries"},"selections":{"path":"/countries"},"filterable":true,"options":[{"label":{"literalString":"United States"},"value":"US"},{"label":{"literalString":"Canada"},"value":"CA"},{"label":{"literalString":"United Kingdom"},"value":"UK"},{"label":{"literalString":"Australia"},"value":"AU"},{"label":{"literalString":"Germany"},"value":"DE"},{"label":{"literalString":"France"},"value":"FR"},{"label":{"literalString":"Japan"},"value":"JP"},{"label":{"literalString":"China"},"value":"CN"},{"label":{"literalString":"Brazil"},"value":"BR"},{"label":{"literalString":"India"},"value":"IN"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"countries","valueMap":[{"key":"0","valueString":"US"}]}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Filterable - Chips") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Languages"},"selections":{"path":"/langs"},"variant":"chips","filterable":true,"options":[{"label":{"literalString":"Swift"},"value":"swift"},{"label":{"literalString":"Python"},"value":"python"},{"label":{"literalString":"Rust"},"value":"rust"},{"label":{"literalString":"Go"},"value":"go"},{"label":{"literalString":"TypeScript"},"value":"ts"},{"label":{"literalString":"Kotlin"},"value":"kotlin"},{"label":{"literalString":"Java"},"value":"java"},{"label":{"literalString":"C++"},"value":"cpp"},{"label":{"literalString":"Ruby"},"value":"ruby"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"langs","valueMap":[{"key":"0","valueString":"swift"},{"key":"1","valueString":"rust"}]}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Max 2 Selections") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Pick up to 2"},"selections":{"path":"/picks"},"maxAllowedSelections":2,"options":[{"label":{"literalString":"Red"},"value":"red"},{"label":{"literalString":"Blue"},"value":"blue"},{"label":{"literalString":"Green"},"value":"green"},{"label":{"literalString":"Yellow"},"value":"yellow"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"picks","valueMap":[{"key":"0","valueString":"red"}]}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
