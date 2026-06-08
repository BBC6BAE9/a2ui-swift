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

/// Spec v0.9 `List` — a scrollable container for children.
///
/// Children come pre-expanded by `ComponentTreeBuilder` (templates already
/// resolved), so populating the stack is shared verbatim with Row/Column via
/// `a2ui_populate`. The ONLY platform-specific part is the scroll container
/// wiring — this is exactly the UIKit/AppKit divergence we expected:
/// `UIScrollView` + content-layout-guide vs `NSScrollView` + a flipped
/// document view. Slice scope: vertical scrolling (the spec default);
/// horizontal is a later refinement.
final class A2UIList: PlatformView, A2UIPlatformComponent {

    private let stack = a2ui_makeStack(vertical: true)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupScrollContainer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScrollContainer()
    }

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        a2ui_populate(stack: stack, children: node.children, surface: surface, factory: factory)
    }

    // MARK: - Platform shell (scroll container)

    #if canImport(UIKit) && !os(watchOS)
    private func setupScrollContainer() {
        let scroll = UIScrollView()
        a2ui_pinEdges(of: scroll)
        scroll.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            // Vertical scroll: pin content width to the viewport.
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])
    }
    #elseif canImport(AppKit)
    private func setupScrollContainer() {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        a2ui_pinEdges(of: scroll)

        // NSView is bottom-left origin; a flipped document view makes the list
        // start at the top and scroll down, matching UIKit behavior.
        let document = A2UIFlippedView()
        document.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
        ])

        scroll.documentView = document
        document.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            // Vertical scroll: fill viewport width, grow in height.
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])
    }
    #endif

    /// The rendered child views, in order. Exposed for tests / introspection.
    var arrangedChildren: [PlatformView] { stack.arrangedSubviews }
}

#if canImport(AppKit)
/// A top-origin NSView so list content flows downward like UIKit.
private final class A2UIFlippedView: NSView {
    override var isFlipped: Bool { true }
}
#endif

#endif
