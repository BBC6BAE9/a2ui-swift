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
import Foundation
import AVFoundation
import AVKit
import A2UISwiftCore

#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Spec v0.9 `Video` — a 16:9 player with native transport controls.
///
/// UIKit: hosts an `AVPlayerViewController` and attaches it to the nearest parent
/// view controller once on-screen (its view needs that to lay out and play).
/// AppKit: uses `AVPlayerView` directly. A 16:9 aspect ratio + minimum height
/// give the player a real size inside a stack.
final class A2UIVideo: PlatformView, A2UIPlatformComponent {

    private var subscriptions = DataSubscriptions()

    #if canImport(UIKit) && !os(watchOS)
    private let controller = AVPlayerViewController()
    #elseif canImport(AppKit)
    private let playerView = AVPlayerView()
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        subscriptions.unsubscribeAll()
        guard let props = try? node.typedProperties(VideoProperties.self) else { return }
        let ctx = DataContext(surface: surface, path: node.dataContextPath)
        a2ui_applyAccessibility(node.accessibility, dataContext: ctx)
        setURL(ctx.resolve(props.url))
        ctx.subscribeString(for: props.url) { [weak self] in self?.setURL($0) }
            .store(in: &subscriptions)
    }

    private func setURL(_ string: String) {
        guard let url = URL(string: string), !string.isEmpty else { return }
        let player = AVPlayer(url: url)
        #if canImport(UIKit) && !os(watchOS)
        controller.player = player
        #elseif canImport(AppKit)
        playerView.player = player
        #endif
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        let aspect = heightAnchor.constraint(equalTo: widthAnchor, multiplier: 9.0 / 16.0)
        aspect.priority = .defaultHigh
        aspect.isActive = true
        heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        a2ui_setBackground(.black)

        #if canImport(UIKit) && !os(watchOS)
        controller.view.backgroundColor = .black
        controller.showsPlaybackControls = true
        // The controller's view is attached in didMoveToWindow, in the correct
        // child-VC order (addChild → addSubview → didMove) so its controls work.
        #elseif canImport(AppKit)
        playerView.controlsStyle = .inline
        a2ui_pinEdges(of: playerView)
        #endif
    }

    #if canImport(UIKit) && !os(watchOS)
    // Attach/detach the player view controller to the hosting VC so its view
    // lays out, its controls appear, and it is released on every rebuild
    // (the view is removed from the window) — otherwise the controller leaks.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            guard controller.parent == nil, let parent = a2ui_parentViewController else { return }
            parent.addChild(controller)
            a2ui_pinEdges(of: controller.view)
            controller.didMove(toParent: parent)
        } else {
            controller.willMove(toParent: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParent()
        }
    }
    #endif
}

#endif
