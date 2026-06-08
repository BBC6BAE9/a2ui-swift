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

/// Spec v0.9 `Video` — remote video with native transport controls.
/// Uses AVKit (`AVPlayerViewController` on UIKit, `AVPlayerView` on AppKit) so
/// playback/scrubbing UI matches the platform, mirroring the SwiftUI renderer.
final class A2UIVideo: PlatformView, A2UIPlatformComponent {

    private var subscriptions = DataSubscriptions()

    #if canImport(UIKit) && !os(watchOS)
    private let controller = AVPlayerViewController()
    #elseif canImport(AppKit)
    private let playerView = AVPlayerView()
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        attach()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        attach()
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

    deinit { subscriptions.unsubscribeAll() }

    private func setURL(_ string: String) {
        guard let url = URL(string: string), !string.isEmpty else { return }
        let player = AVPlayer(url: url)
        #if canImport(UIKit) && !os(watchOS)
        controller.player = player
        #elseif canImport(AppKit)
        playerView.player = player
        #endif
    }

    private func attach() {
        #if canImport(UIKit) && !os(watchOS)
        controller.showsPlaybackControls = true
        a2ui_pinEdges(of: controller.view)
        #elseif canImport(AppKit)
        playerView.controlsStyle = .inline
        a2ui_pinEdges(of: playerView)
        #endif
    }
}

#endif
