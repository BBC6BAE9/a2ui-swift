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

/// Recursively renders a pre-resolved `ComponentNode` and its children.
///
/// All child resolution and template expansion is performed ahead-of-time by
/// `SurfaceViewModel.rebuildComponentTree()`. This view reads `node.children`
/// directly and never resolves children at render time.
///
/// UI state (Tabs selectedIndex, Modal isPresented, etc.) lives on
/// `node.uiState` — an `@Observable` object that is migrated across tree
/// rebuilds by ID match, surviving LazyVStack view recycling.
public struct A2UIComponentView: View {
    public let node: ComponentNode
    public var viewModel: SurfaceViewModel

    public init(node: ComponentNode, viewModel: SurfaceViewModel) {
        self.node = node
        self.viewModel = viewModel
    }

    private var dataContextPath: String { node.dataContextPath }

    public var body: some View {
        renderComponent(node.type)
            .modifier(WeightModifier(weight: node.weight))
            .modifier(AccessibilityModifier(
                accessibility: node.accessibility,
                viewModel: viewModel,
                dataContextPath: dataContextPath
            ))
    }

    @ViewBuilder
    private func renderComponent(_ type: ComponentType) -> some View {
        switch type {
        case .Text:
            A2UIText(node: node, viewModel: viewModel)
        case .Image:
            A2UIImage(node: node, viewModel: viewModel)
        case .Column:
            A2UIColumn(node: node, viewModel: viewModel)
        case .Row:
            A2UIRow(node: node, viewModel: viewModel)
        case .Card:
            A2UICard(node: node, viewModel: viewModel)
        case .Button:
            A2UIButton(node: node, viewModel: viewModel)
        case .Icon:
            A2UIIcon(node: node, viewModel: viewModel)
        case .Divider:
            A2UIDivider(node: node)
        case .TextField:
            A2UITextField(node: node, viewModel: viewModel)
        case .CheckBox:
            A2UICheckBox(node: node, viewModel: viewModel)
        case .Slider:
            A2UISlider(node: node, viewModel: viewModel)
        case .DateTimeInput:
            A2UIDateTimeInput(node: node, viewModel: viewModel)
        case .List:
            A2UIList(node: node, viewModel: viewModel)
        case .Video:
            A2UIVideo(node: node, viewModel: viewModel)
        case .AudioPlayer:
            A2UIAudioPlayer(node: node, viewModel: viewModel)
        case .Tabs:
            A2UITabs(node: node, viewModel: viewModel)
        case .Modal:
            A2UIModal(node: node, viewModel: viewModel)
        case .MultipleChoice:
            A2UIMultipleChoice(node: node, viewModel: viewModel)
        case .custom:
            A2UICustom(node: node, viewModel: viewModel)
        }
    }
}
