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
/// Spec v0.9 Tabs — adaptive tab container with `tabs` (required).
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
    let surface: SurfaceModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(TabsProperties.self) {
            let dc = DataContext(surface: surface, path: dataContextPath)
            let titles = props.tabs.map { dc.resolve($0.title) }
            TabsNodeView(
                titles: titles,
                childNodes: node.children,
                uiState: node.uiState as? TabsUIState ?? TabsUIState(),
                surface: surface
            )
            .a2uiAccessibility(node.accessibility, dataContext: dc)
            .padding(style.leafMargin)
        }
    }
}

// MARK: - TabsNodeView

/// Adaptive tabs: ≤5 uses system `Picker(.segmented)`, >5 uses `ScrollView(.horizontal)` + `Button(.bordered)`.
struct TabsNodeView: View {
    let titles: [String]
    let childNodes: [ComponentNode]
    var uiState: TabsUIState
    let surface: SurfaceModel

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
                    surface: surface
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
