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

#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
