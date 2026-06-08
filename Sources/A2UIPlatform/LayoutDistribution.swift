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

// MARK: - Justify / Align / Weight
//
// Mirrors SwiftUI's Row/Column distribution: main-axis `justify` is emulated with
// flexible spacer views (UIKit/AppKit stacks have no `justify`), cross-axis
// `align` maps to the stack's alignment, and per-child `weight` (flex-grow) is
// approximated by lowering the child's hugging priority so it expands.

/// A view that expands to absorb free space along `axis` (a flex spacer).
func a2ui_makeSpacer(vertical: Bool) -> PlatformView {
    let spacer = PlatformView()
    let axis: PlatformLayoutAxis = vertical ? .vertical : .horizontal
    spacer.setContentHuggingPriority(.defaultLow, for: axis)
    spacer.setContentCompressionResistancePriority(.defaultLow, for: axis)
    return spacer
}

/// Lowers a weighted child's hugging priority so it grows along the main axis.
func a2ui_applyWeight(_ view: PlatformView, weight: Double?, vertical: Bool) {
    guard let weight, weight > 0 else { return }
    let axis: PlatformLayoutAxis = vertical ? .vertical : .horizontal
    view.setContentHuggingPriority(PlatformLayoutPriority(rawValue: 1), for: axis)
    view.setContentCompressionResistancePriority(PlatformLayoutPriority(rawValue: 1), for: axis)
    _ = weight // proportional multi-weight is a later refinement; >0 means "grow".
}

/// Populates a stack with `children`, inserting spacers to realize `justify`,
/// and applying per-child weight. Shared by Row/Column.
func a2ui_populateDistributed(
    stack: PlatformStackView,
    children: [ComponentNode],
    justify: Justify?,
    vertical: Bool,
    surface: SurfaceModel,
    factory: ComponentFactory
) {
    for view in stack.arrangedSubviews {
        stack.removeArrangedSubview(view)
        view.removeFromSuperview()
    }

    func spacer() { stack.addArrangedSubview(a2ui_makeSpacer(vertical: vertical)) }
    func addChildren() {
        for (i, child) in children.enumerated() {
            let view = factory.makeView(for: child, surface: surface)
            a2ui_applyWeight(view, weight: child.weight, vertical: vertical)
            stack.addArrangedSubview(view)
            if justify == .spaceBetween, i < children.count - 1 { spacer() }
            if justify == .spaceAround { /* handled below */ }
        }
    }

    switch justify {
    case .center:
        spacer(); addChildren(); spacer()
    case .end:
        spacer(); addChildren()
    case .spaceBetween:
        addChildren() // spacers interleaved inside addChildren()
    case .spaceAround:
        for child in children {
            spacer()
            let view = factory.makeView(for: child, surface: surface)
            a2ui_applyWeight(view, weight: child.weight, vertical: vertical)
            stack.addArrangedSubview(view)
        }
        spacer()
    case .spaceEvenly:
        spacer()
        for child in children {
            let view = factory.makeView(for: child, surface: surface)
            a2ui_applyWeight(view, weight: child.weight, vertical: vertical)
            stack.addArrangedSubview(view)
            spacer()
        }
    default: // start, stretch, nil
        addChildren()
    }
}

/// Maps cross-axis `align` to the stack's native alignment.
#if canImport(UIKit) && !os(watchOS)
func a2ui_applyAlignment(_ stack: UIStackView, align: Align?, vertical: Bool) {
    switch align {
    case .center: stack.alignment = .center
    case .end:    stack.alignment = vertical ? .trailing : .bottom
    case .stretch: stack.alignment = .fill
    default:      stack.alignment = vertical ? .leading : .top // start / nil
    }
}
typealias PlatformLayoutPriority = UILayoutPriority
typealias PlatformLayoutAxis = NSLayoutConstraint.Axis
#elseif canImport(AppKit)
func a2ui_applyAlignment(_ stack: NSStackView, align: Align?, vertical: Bool) {
    switch align {
    case .center: stack.alignment = vertical ? .centerX : .centerY
    case .end:    stack.alignment = vertical ? .trailing : .bottom
    default:      stack.alignment = vertical ? .leading : .top // start / stretch / nil
    }
}
typealias PlatformLayoutPriority = NSLayoutConstraint.Priority
typealias PlatformLayoutAxis = NSLayoutConstraint.Orientation
#endif

#endif
