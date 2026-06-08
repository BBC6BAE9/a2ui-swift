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

// MARK: - Shared layout helpers
//
// `NSLayoutAnchor` / `NSLayoutConstraint` are API-identical on `UIView` and
// `NSView`, so every constraint helper here is written ONCE for both platforms.

#if (canImport(UIKit) && !os(watchOS)) || canImport(AppKit)
import A2UISwiftCore

#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Recursively recolors every text label under `view` — used by Button to make
/// its child label read against the fill (SwiftUI does this via `.foregroundStyle`).
func a2ui_recolorLabels(in view: PlatformView, color: PlatformColor) {
    #if canImport(UIKit) && !os(watchOS)
    if let label = view as? UILabel { label.textColor = color }
    #elseif canImport(AppKit)
    if let field = view as? NSTextField { field.textColor = color }
    #endif
    for sub in view.subviews { a2ui_recolorLabels(in: sub, color: color) }
}

/// Wraps a view in a container that insets it on all sides — the imperative
/// equivalent of SwiftUI's `.padding(leafMargin)`, which every leaf component
/// applies for breathing room.
func a2ui_padded(_ view: PlatformView, inset: CGFloat) -> PlatformView {
    let container = PlatformView()
    container.a2ui_pinEdges(of: view, inset: inset)
    return container
}

extension PlatformView {

    /// Pins all four edges of `subview` to this view, optionally inset.
    /// Adds `subview` if it is not already a child.
    func a2ui_pinEdges(of subview: PlatformView, inset: CGFloat = 0) {
        if subview.superview !== self { addSubview(subview) }
        subview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subview.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            subview.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            subview.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            subview.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
        ])
    }
}

extension PlatformView {

    /// Sets a solid background color. `UIView.backgroundColor` vs
    /// `NSView.layer.backgroundColor` is one of the small per-framework gaps,
    /// isolated here once.
    func a2ui_setBackground(_ color: PlatformColor) {
        #if canImport(UIKit) && !os(watchOS)
        backgroundColor = color
        #elseif canImport(AppKit)
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
        #endif
    }

    /// Sets a corner radius (layer-backed on AppKit).
    func a2ui_setCornerRadius(_ radius: CGFloat) {
        #if canImport(UIKit) && !os(watchOS)
        layer.cornerRadius = radius
        layer.masksToBounds = true
        #elseif canImport(AppKit)
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.masksToBounds = true
        #endif
    }
}

/// Replaces a stack's arranged subviews with freshly-built views for `children`.
/// Shared by every stack-backed container (Row, Column, List).
func a2ui_populate(
    stack: PlatformStackView,
    children: [ComponentNode],
    surface: SurfaceModel,
    factory: ComponentFactory
) {
    for view in stack.arrangedSubviews {
        stack.removeArrangedSubview(view)
        view.removeFromSuperview()
    }
    for child in children {
        stack.addArrangedSubview(factory.makeView(for: child, surface: surface))
    }
}

/// Creates a stack view configured for the given axis. The construction differs
/// between frameworks (`axis` vs `orientation`), so it is isolated here once
/// rather than smeared across every container component.
func a2ui_makeStack(vertical: Bool, spacing: CGFloat = 0) -> PlatformStackView {
    let stack = PlatformStackView()
    stack.spacing = spacing
    #if canImport(UIKit) && !os(watchOS)
    stack.axis = vertical ? .vertical : .horizontal
    stack.alignment = .fill
    stack.distribution = .fill
    #elseif canImport(AppKit)
    stack.orientation = vertical ? .vertical : .horizontal
    stack.alignment = vertical ? .leading : .top
    stack.distribution = .fill
    #endif
    return stack
}

#endif
