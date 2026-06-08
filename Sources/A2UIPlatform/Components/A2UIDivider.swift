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

/// Spec v0.9 `Divider` — a thin separator line, horizontal or vertical.
/// Fully shared (background color + size constraint via shared helpers).
final class A2UIDivider: PlatformView, A2UIPlatformComponent {

    private let line = PlatformView()
    private var sizeConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        line.a2ui_setBackground(A2UIPlatformStyle.separator)
        addSubview(line)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        line.a2ui_setBackground(A2UIPlatformStyle.separator)
        addSubview(line)
    }

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        let props = try? node.typedProperties(DividerProperties.self)
        let vertical = (props?.axis ?? .horizontal) == .vertical
        a2ui_pinEdges(of: line)
        sizeConstraint?.isActive = false
        let t = A2UIPlatformStyle.dividerThickness
        sizeConstraint = vertical ? line.widthAnchor.constraint(equalToConstant: t)
                                  : line.heightAnchor.constraint(equalToConstant: t)
        sizeConstraint?.isActive = true
    }
}

#endif
