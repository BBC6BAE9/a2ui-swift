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
public struct A2UIComponentView: View {
    public let node: ComponentNode
    public let surface: SurfaceModel

    public init(node: ComponentNode, surface: SurfaceModel) {
        self.node = node
        self.surface = surface
    }

    public var body: some View {
        renderComponent(node.type)
            .modifier(WeightModifier(weight: node.weight))
    }

    @ViewBuilder
    private func renderComponent(_ type: ComponentType) -> some View {
        switch type {
        case .Text:         A2UIText(node: node, surface: surface)
        case .Image:        A2UIImage(node: node, surface: surface)
        case .Column:       A2UIColumn(node: node, surface: surface)
        case .Row:          A2UIRow(node: node, surface: surface)
        case .Card:         A2UICard(node: node, surface: surface)
        case .Button:       A2UIButton(node: node, surface: surface)
        case .Icon:         A2UIIcon(node: node, surface: surface)
        case .Divider:      A2UIDivider(node: node, surface: surface)
        case .TextField:    A2UITextField(node: node, surface: surface)
        case .CheckBox:     A2UICheckBox(node: node, surface: surface)
        case .Slider:       A2UISlider(node: node, surface: surface)
        case .DateTimeInput:A2UIDateTimeInput(node: node, surface: surface)
        case .List:         A2UIList(node: node, surface: surface)
        case .Video:        A2UIVideo(node: node, surface: surface)
        case .AudioPlayer:  A2UIAudioPlayer(node: node, surface: surface)
        case .Tabs:         A2UITabs(node: node, surface: surface)
        case .Modal:        A2UIModal(node: node, surface: surface)
        case .ChoicePicker: A2UIChoicePicker(node: node, surface: surface)
        case .custom:       A2UICustom(node: node, surface: surface)
        }
    }
}
