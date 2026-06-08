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

/// Spec v0.9 `Modal` — a trigger that reveals content over the surface.
///
/// Children are pre-resolved as `[trigger, content]`. Baseline: the trigger is
/// shown inline; tapping it overlays the content (dimmed, tap-to-dismiss) on the
/// host view. Full modal presentation (its own controller / window) is deferred.
final class A2UIModal: PlatformView, A2UIPlatformComponent {

    private var contentView: PlatformView?
    private var overlay: PlatformView?

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        subviews.forEach { $0.removeFromSuperview() }
        guard node.children.count >= 1 else { return }

        let trigger = factory.makeView(for: node.children[0], surface: surface)
        a2ui_pinEdges(of: trigger)
        if node.children.count >= 2 {
            contentView = factory.makeView(for: node.children[1], surface: surface)
        }
        #if canImport(UIKit) && !os(watchOS)
        trigger.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(present)))
        trigger.isUserInteractionEnabled = true
        #elseif canImport(AppKit)
        trigger.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(present)))
        #endif
    }

    @objc private func present() {
        guard let contentView, overlay == nil else { return }
        #if canImport(UIKit) && !os(watchOS)
        let host: PlatformView = window ?? self
        #elseif canImport(AppKit)
        let host: PlatformView = window?.contentView ?? self
        #endif
        let dim = PlatformView()
        dim.a2ui_setBackground(.black.withAlphaComponent(0.4))
        host.a2ui_pinEdges(of: dim)
        dim.a2ui_pinEdges(of: contentView, inset: 24)
        #if canImport(UIKit) && !os(watchOS)
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismiss)))
        #elseif canImport(AppKit)
        dim.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(dismiss)))
        #endif
        overlay = dim
    }

    @objc private func dismiss() {
        overlay?.removeFromSuperview()
        overlay = nil
    }
}

#endif
