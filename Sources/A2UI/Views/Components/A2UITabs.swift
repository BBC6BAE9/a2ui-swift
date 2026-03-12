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

/// # Tabs
/// Spec v0.8 Tabs — adaptive tab container with `tabItems` (required).
///
/// Rendering strategy:
/// - ≤5 tabs → system `Picker(.segmented)` (Settings App pattern)
/// - >5 tabs → horizontal `ScrollView` + `Button(.bordered)` row (Music Browse pattern)
///
/// Platform differences:
/// - watchOS: `.segmented` unavailable, falls back to `.wheel`.
/// - tvOS / visionOS: not specifically handled yet — uses default picker behavior.
struct A2UITabs: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(TabsProperties.self) {
            let titles = props.tabItems.map {
                viewModel.resolveString($0.title, dataContextPath: dataContextPath)
            }
            TabsNodeView(
                titles: titles,
                childNodes: node.children,
                uiState: node.uiState as? TabsUIState ?? TabsUIState(),
                viewModel: viewModel
            )
        }
    }
}

// MARK: - TabsNodeView

/// Adaptive tabs: ≤5 uses system `Picker(.segmented)`, >5 uses `ScrollView(.horizontal)` + `Button(.bordered)`.
struct TabsNodeView: View {
    let titles: [String]
    let childNodes: [ComponentNode]
    var uiState: TabsUIState
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    private var selection: Binding<Int> {
        Binding(
            get: { uiState.selectedIndex },
            set: { uiState.selectedIndex = $0 }
        )
    }

    var body: some View {
        VStack {
            if titles.count <= 5 {
                segmentedBar
            } else {
                scrollableBar
            }

            if uiState.selectedIndex < childNodes.count {
                A2UIComponentView(
                    node: childNodes[uiState.selectedIndex],
                    viewModel: viewModel
                )
            }
        }
    }

    /// ≤5 tabs: system segmented control (Settings App pattern).
    /// watchOS does not support .segmented — falls back to default wheel picker.
    private var segmentedBar: some View {
        Picker("", selection: selection) {
            ForEach(titles.indices, id: \.self) { index in
                Text(titles[index])
                    .font(style.tabsStyle.titleFont)
                    .tag(index)
            }
        }
        #if os(watchOS)
        .pickerStyle(.wheel)
        #else
        .pickerStyle(.segmented)
        #endif
        .tint(style.tabsStyle.selectedColor)
        .animation(.none, value: uiState.selectedIndex)
    }

    /// >5 tabs: horizontally scrollable Button(.bordered) row (Music Browse / App Store pattern).
    private var scrollableBar: some View {
        let tabStyle = style.tabsStyle
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(titles.indices, id: \.self) { index in
                    let isSelected = uiState.selectedIndex == index
                    Button {
                        uiState.selectedIndex = index
                    } label: {
                        Text(titles[index])
                            .font(tabStyle.titleFont)
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected
                        ? (tabStyle.selectedColor ?? .accentColor)
                        : (tabStyle.unselectedColor ?? .secondary))
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Previews

#Preview("Tabs - Two Tabs") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Tabs":{"tabItems":[{"title":{"literalString":"View One"},"child":"t1"},{"title":{"literalString":"View Two"},"child":"t2"}]}}},{"id":"t1","component":{"Text":{"text":{"literalString":"First tab content"}}}},{"id":"t2","component":{"Text":{"text":{"literalString":"Second tab content"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Tabs - Single Tab") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Tabs":{"tabItems":[{"title":{"literalString":"Only Tab"},"child":"t1"}]}}},{"id":"t1","component":{"Text":{"text":{"literalString":"Single tab content"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Tabs - Five Tabs (Segmented Boundary)") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Tabs":{"tabItems":[{"title":{"literalString":"One"},"child":"t1"},{"title":{"literalString":"Two"},"child":"t2"},{"title":{"literalString":"Three"},"child":"t3"},{"title":{"literalString":"Four"},"child":"t4"},{"title":{"literalString":"Five"},"child":"t5"}]}}},{"id":"t1","component":{"Text":{"text":{"literalString":"Tab 1 content"}}}},{"id":"t2","component":{"Text":{"text":{"literalString":"Tab 2 content"}}}},{"id":"t3","component":{"Text":{"text":{"literalString":"Tab 3 content"}}}},{"id":"t4","component":{"Text":{"text":{"literalString":"Tab 4 content"}}}},{"id":"t5","component":{"Text":{"text":{"literalString":"Tab 5 content"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Tabs - Many Tabs (Scrollable)") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Tabs":{"tabItems":[{"title":{"literalString":"Overview"},"child":"t1"},{"title":{"literalString":"Details"},"child":"t2"},{"title":{"literalString":"Reviews"},"child":"t3"},{"title":{"literalString":"Pricing"},"child":"t4"},{"title":{"literalString":"Support"},"child":"t5"},{"title":{"literalString":"FAQ"},"child":"t6"},{"title":{"literalString":"Updates"},"child":"t7"}]}}},{"id":"t1","component":{"Text":{"text":{"literalString":"Overview content"}}}},{"id":"t2","component":{"Text":{"text":{"literalString":"Details content"}}}},{"id":"t3","component":{"Text":{"text":{"literalString":"Reviews content"}}}},{"id":"t4","component":{"Text":{"text":{"literalString":"Pricing content"}}}},{"id":"t5","component":{"Text":{"text":{"literalString":"Support content"}}}},{"id":"t6","component":{"Text":{"text":{"literalString":"FAQ content"}}}},{"id":"t7","component":{"Text":{"text":{"literalString":"Updates content"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
