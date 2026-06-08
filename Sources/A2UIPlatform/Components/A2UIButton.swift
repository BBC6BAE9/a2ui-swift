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

/// Spec v0.9 `Button` — wraps a single child, dispatches an action on tap.
///
/// Implemented as a tappable container (not UIButton/NSButton) so the arbitrary
/// child content and the action wiring stay shared; only the gesture-recognizer
/// class name differs per platform. Disabled while any `check` fails (spec §617).
final class A2UIButton: PlatformView, A2UIPlatformComponent {

    private var hosted: PlatformView?
    private var action: Action?
    private var dataContext: DataContext?
    private var surface: SurfaceModel?
    private var sourceComponentId = ""
    private var checks: [CheckRule]?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGesture()
        a2ui_setCornerRadius(A2UIPlatformStyle.cornerRadius)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGesture()
        a2ui_setCornerRadius(A2UIPlatformStyle.cornerRadius)
    }

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        guard let props = try? node.typedProperties(ButtonProperties.self) else { return }
        self.action = props.action
        self.surface = surface
        self.sourceComponentId = node.baseComponentId
        self.checks = props.checks
        self.dataContext = DataContext(surface: surface, path: node.dataContextPath)

        hosted?.removeFromSuperview()
        guard let child = node.children.first else { hosted = nil; return }
        let view = factory.makeView(for: child, surface: surface)
        a2ui_pinEdges(of: view, inset: A2UIPlatformStyle.leafMargin)
        hosted = view
    }

    private func setupGesture() {
        #if canImport(UIKit) && !os(watchOS)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        #elseif canImport(AppKit)
        addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(handleTap)))
        #endif
    }

    @objc func handleTap() {
        guard let dataContext, let surface, let action else { return }
        // Spec §617: a failing check disables the button.
        if dataContext.firstFailingCheckMessage(checks) != nil { return }
        a2ui_dispatch(action, from: sourceComponentId, dataContext: dataContext, surface: surface)
    }
}

#endif
