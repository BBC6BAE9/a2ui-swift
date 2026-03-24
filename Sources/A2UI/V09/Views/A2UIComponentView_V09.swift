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

/// Recursively renders a pre-resolved `ComponentNode_V09` and its children.
public struct A2UIComponentView_V09: View {
    public let node: ComponentNode_V09
    public var viewModel: SurfaceViewModel_V09

    public init(node: ComponentNode_V09, viewModel: SurfaceViewModel_V09) {
        self.node = node
        self.viewModel = viewModel
    }

    private var dataContextPath: String { node.dataContextPath }

    public var body: some View {
        renderComponent(node.type)
            .modifier(WeightModifier(weight: node.weight))
    }

    @ViewBuilder
    private func renderComponent(_ type: ComponentType_V09) -> some View {
        switch type {
        case .Text:
            A2UIText_V09(node: node, viewModel: viewModel)
        case .Image:
            A2UIImage_V09(node: node, viewModel: viewModel)
        case .Column:
            A2UIColumn_V09(node: node, viewModel: viewModel)
        case .Row:
            A2UIRow_V09(node: node, viewModel: viewModel)
        case .Card:
            A2UICard_V09(node: node, viewModel: viewModel)
        case .Button:
            A2UIButton_V09(node: node, viewModel: viewModel)
        case .Icon:
            A2UIIcon_V09(node: node, viewModel: viewModel)
        case .Divider:
            A2UIDivider_V09(node: node)
        case .TextField:
            A2UITextField_V09(node: node, viewModel: viewModel)
        case .CheckBox:
            A2UICheckBox_V09(node: node, viewModel: viewModel)
        case .Slider:
            A2UISlider_V09(node: node, viewModel: viewModel)
        case .DateTimeInput:
            A2UIDateTimeInput_V09(node: node, viewModel: viewModel)
        case .List:
            A2UIList_V09(node: node, viewModel: viewModel)
        case .Video:
            A2UIVideo_V09(node: node, viewModel: viewModel)
        case .AudioPlayer:
            A2UIAudioPlayer_V09(node: node, viewModel: viewModel)
        case .Tabs:
            A2UITabs_V09(node: node, viewModel: viewModel)
        case .Modal:
            A2UIModal_V09(node: node, viewModel: viewModel)
        case .ChoicePicker:
            A2UIChoicePicker_V09(node: node, viewModel: viewModel)
        case .custom:
            A2UICustom_V09(node: node, viewModel: viewModel)
        }
    }
}
