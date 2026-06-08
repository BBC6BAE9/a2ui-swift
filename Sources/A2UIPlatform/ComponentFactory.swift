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

#if (canImport(UIKit) && !os(watchOS)) || canImport(AppKit)
import A2UISwiftCore

#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - ComponentFactory
//
// The single `ComponentNode → PlatformView` dispatch point. Recursion is
// confined here: container components call back into `makeView` for their
// children, so no component ever recurses the tree itself. A registry could
// later replace the `switch` to support custom components; the switch keeps the
// vertical slice small and is the obvious extension point.

public final class ComponentFactory {

    public init() {}

    /// Builds the platform view for `node`, binds it to `surface`, and returns it.
    /// Container components recurse via this same method for `node.children`.
    public func makeView(for node: ComponentNode, surface: SurfaceModel) -> PlatformView {
        let component = makeComponent(for: node.type)
        component.configure(node: node, surface: surface, factory: self)
        return component
    }

    private func makeComponent(for type: ComponentType) -> PlatformView & A2UIPlatformComponent {
        switch type {
        case .Text:
            return A2UIText()
        case .Row:
            return A2UIStack(vertical: false)
        case .Column:
            return A2UIStack(vertical: true)
        case .List:
            return A2UIList()
        case .Divider:
            return A2UIDivider()
        case .Card:
            return A2UICard()
        case .Button:
            return A2UIButton()
        case .Image:
            return A2UIImage()
        case .Icon:
            return A2UIIcon()
        case .TextField:
            return A2UITextField()
        case .CheckBox:
            return A2UICheckBox()
        case .Slider:
            return A2UISlider()
        case .ChoicePicker:
            return A2UIChoicePicker()
        case .DateTimeInput:
            return A2UIDateTimeInput()
        case .Tabs:
            return A2UITabs()
        case .Modal:
            return A2UIModal()
        case .Video:
            return A2UIVideo()
        case .AudioPlayer:
            return A2UIAudioPlayer()
        case .custom:
            // Custom components are a host-app extension point — not yet wired.
            return A2UIUnsupported(type: type)
        }
    }
}

#endif
