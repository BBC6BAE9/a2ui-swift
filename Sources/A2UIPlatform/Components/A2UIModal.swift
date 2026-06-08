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

/// Spec v0.9 `Modal` — a trigger that presents content modally.
///
/// Uses the system presentation (matching SwiftUI's `.sheet` + close button):
/// UIKit presents a navigation controller as a sheet (medium/large detents) with
/// a Close bar button; AppKit presents a sheet with a Done button. When no host
/// view controller is available (e.g. in tests) it falls back to a dimmed overlay.
final class A2UIModal: PlatformView, A2UIPlatformComponent {

    private var contentView: PlatformView?
    private var overlay: PlatformView?
    private var presentedController: AnyObject?
    private var uiState: ModalUIState?
    private var actionSubscription: Subscription?

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        actionSubscription?.unsubscribe()
        subviews.forEach { $0.removeFromSuperview() }
        uiState = node.uiState as? ModalUIState
        guard node.children.count >= 1 else { return }

        let triggerNode = node.children[0]
        let trigger = factory.makeView(for: triggerNode, surface: surface)
        a2ui_pinEdges(of: trigger)
        if node.children.count >= 2 {
            contentView = factory.makeView(for: node.children[1], surface: surface)
        }

        // A normal Button trigger opens the modal: when its action fires, present.
        let triggerIds = Self.componentIds(in: triggerNode)
        actionSubscription = surface.onAction.subscribe { [weak self] action in
            if triggerIds.contains(action.sourceComponentId) { self?.present() }
        }
        if uiState?.isPresented == true { present() }
    }

    deinit { actionSubscription?.unsubscribe() }

    private static func componentIds(in node: ComponentNode) -> Set<String> {
        var ids: Set<String> = [node.baseComponentId]
        for child in node.children { ids.formUnion(componentIds(in: child)) }
        return ids
    }

    @objc private func present() {
        uiState?.isPresented = true
        guard let contentView, presentedController == nil, overlay == nil else { return }
        #if canImport(UIKit) && !os(watchOS)
        if let parent = a2ui_parentViewController, parent.presentedViewController == nil {
            presentSheet(contentView, from: parent); return
        }
        #elseif canImport(AppKit)
        if let presenter = window?.contentViewController {
            presentSheet(contentView, from: presenter); return
        }
        #endif
        presentOverlay(contentView) // fallback (no host view controller)
    }

    @objc private func dismiss() {
        uiState?.isPresented = false
        #if canImport(UIKit) && !os(watchOS)
        (presentedController as? UIViewController)?.presentingViewController?.dismiss(animated: true)
        #elseif canImport(AppKit)
        (presentedController as? NSViewController)?.dismiss(nil)
        #endif
        presentedController = nil
        overlay?.removeFromSuperview()
        overlay = nil
    }

    // MARK: - System sheet

    #if canImport(UIKit) && !os(watchOS)
    private func presentSheet(_ content: UIView, from parent: UIViewController) {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(scroll)
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 8),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -8),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -8),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -16),
        ])
        let nav = UINavigationController(rootViewController: vc)
        vc.navigationItem.rightBarButtonItem =
            UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(dismiss))
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        presentedController = nav
        parent.present(nav, animated: true)
    }
    #elseif canImport(AppKit)
    private func presentSheet(_ content: NSView, from presenter: NSViewController) {
        let container = NSView()
        let done = NSButton(title: "Done", target: self, action: #selector(dismiss))
        done.bezelStyle = .rounded
        done.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(done)
        container.addSubview(content)
        NSLayoutConstraint.activate([
            done.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            done.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: done.bottomAnchor, constant: 12),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            container.widthAnchor.constraint(equalToConstant: 420),
        ])
        let vc = NSViewController()
        vc.view = container
        presentedController = vc
        presenter.presentAsSheet(vc)
    }
    #endif

    // MARK: - Overlay fallback (no host view controller, e.g. tests)

    private func presentOverlay(_ content: PlatformView) {
        let host: PlatformView = self
        let dim = PlatformView()
        dim.a2ui_setBackground(.black.withAlphaComponent(0.4))
        host.a2ui_pinEdges(of: dim)
        dim.a2ui_pinEdges(of: content, inset: 24)
        #if canImport(UIKit) && !os(watchOS)
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismiss)))
        #elseif canImport(AppKit)
        dim.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(dismiss)))
        #endif
        overlay = dim
    }
}

#endif
