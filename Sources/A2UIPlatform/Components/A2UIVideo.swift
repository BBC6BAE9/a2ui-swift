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
import A2UISwiftCore

#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Spec v0.9 `Video` — plays a remote video via AVFoundation.
/// `AVPlayer` / `AVPlayerLayer` are cross-platform; only layer-hosting and the
/// frame-update hook differ between UIKit and AppKit. Baseline (no transport UI).
final class A2UIVideo: PlatformView, A2UIPlatformComponent {

    private let playerLayer = AVPlayerLayer()
    private var subscriptions = DataSubscriptions()

    override init(frame: CGRect) {
        super.init(frame: frame)
        attachLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        attachLayer()
    }

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        subscriptions.unsubscribeAll()
        guard let props = try? node.typedProperties(VideoProperties.self) else { return }
        let ctx = DataContext(surface: surface, path: node.dataContextPath)
        setURL(ctx.resolve(props.url))
        ctx.subscribeString(for: props.url) { [weak self] in self?.setURL($0) }
            .store(in: &subscriptions)
    }

    private func setURL(_ string: String) {
        guard let url = URL(string: string), !string.isEmpty else { return }
        playerLayer.player = AVPlayer(url: url)
    }

    // MARK: - Platform shell (layer hosting + frame sync)

    #if canImport(UIKit) && !os(watchOS)
    private func attachLayer() { layer.addSublayer(playerLayer) }
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
    #elseif canImport(AppKit)
    private func attachLayer() {
        wantsLayer = true
        layer?.addSublayer(playerLayer)
    }
    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
    #endif
}

#endif
