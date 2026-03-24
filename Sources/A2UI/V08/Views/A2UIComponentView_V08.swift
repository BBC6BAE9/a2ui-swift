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

/// Recursively renders a pre-resolved `ComponentNode_V08` and its children.
///
/// All child resolution and template expansion is performed ahead-of-time by
/// `SurfaceViewModel_V08.rebuildComponentTree()`. This view reads `node.children`
/// directly and never resolves children at render time.
///
/// UI state (Tabs selectedIndex, Modal isPresented, etc.) lives on
/// `node.uiState` — an `@Observable` object that is migrated across tree
/// rebuilds by ID match, surviving LazyVStack view recycling.
public struct A2UIComponentView_V08: View {
    public let node: ComponentNode_V08
    public var viewModel: SurfaceViewModel_V08

    public init(node: ComponentNode_V08, viewModel: SurfaceViewModel_V08) {
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
    private func renderComponent(_ type: ComponentType_V08) -> some View {
        switch type {
        case .Text:
            A2UIText_V08(node: node, viewModel: viewModel)
        case .Image:
            A2UIImage_V08(node: node, viewModel: viewModel)
        case .Column:
            A2UIColumn_V08(node: node, viewModel: viewModel)
        case .Row:
            A2UIRow_V08(node: node, viewModel: viewModel)
        case .Card:
            A2UICard_V08(node: node, viewModel: viewModel)
        case .Button:
            A2UIButton_V08(node: node, viewModel: viewModel)
        case .Icon:
            A2UIIcon_V08(node: node, viewModel: viewModel)
        case .Divider:
            A2UIDivider_V08(node: node)
        case .TextField:
            A2UITextField_V08(node: node, viewModel: viewModel)
        case .CheckBox:
            A2UICheckBox_V08(node: node, viewModel: viewModel)
        case .Slider:
            A2UISlider_V08(node: node, viewModel: viewModel)
        case .DateTimeInput:
            A2UIDateTimeInput_V08(node: node, viewModel: viewModel)
        case .List:
            A2UIList_V08(node: node, viewModel: viewModel)
        case .Video:
            A2UIVideo_V08(node: node, viewModel: viewModel)
        case .AudioPlayer:
            A2UIAudioPlayer_V08(node: node, viewModel: viewModel)
        case .Tabs:
            A2UITabs_V08(node: node, viewModel: viewModel)
        case .Modal:
            A2UIModal_V08(node: node, viewModel: viewModel)
        case .MultipleChoice:
            A2UIMultipleChoice_V08(node: node, viewModel: viewModel)
        case .custom:
            A2UICustom_V08(node: node, viewModel: viewModel)
        }
    }
}
