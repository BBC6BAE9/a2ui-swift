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

/// Spec v0.9 `Video` — a 16:9 video player.
///
/// Uses `AVPlayerLayer` directly (not `AVPlayerViewController`, whose view needs
/// a parent view controller to lay out — unavailable in a pure-view renderer).
/// Tap toggles play/pause; a play badge shows when paused.
final class A2UIVideo: PlatformView, A2UIPlatformComponent {

    private let playerLayer = AVPlayerLayer()
    private let playBadge = PlatformImageView()
    private var subscriptions = DataSubscriptions()
    private var playing = false

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
        playerLayer.player = AVPlayer(url: url)
        playing = false
        updateBadge()
    }

    @objc private func toggle() {
        guard let player = playerLayer.player else { return }
        playing.toggle()
        playing ? player.play() : player.pause()
        updateBadge()
    }

    private func updateBadge() {
        playBadge.isHidden = playing
        #if canImport(UIKit) && !os(watchOS)
        playBadge.image = UIImage(systemName: "play.circle.fill")
        #elseif canImport(AppKit)
        playBadge.image = NSImage(systemSymbolName: "play.circle.fill", accessibilityDescription: "Play")
        #endif
    }

    // MARK: - Platform shell

    private func setup() {
        // Give the layer a real size in a stack. A 16:9 aspect ratio plus a
        // minimum height (so it shows even before width resolves).
        translatesAutoresizingMaskIntoConstraints = false
        let aspect = heightAnchor.constraint(equalTo: widthAnchor, multiplier: 9.0 / 16.0)
        aspect.priority = .defaultHigh
        aspect.isActive = true
        heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        playerLayer.videoGravity = .resizeAspect
        a2ui_setBackground(.black)
        playBadge.translatesAutoresizingMaskIntoConstraints = false

        #if canImport(UIKit) && !os(watchOS)
        layer.addSublayer(playerLayer)
        playBadge.tintColor = .white
        addSubview(playBadge)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggle)))
        #elseif canImport(AppKit)
        wantsLayer = true
        layer?.addSublayer(playerLayer)
        playBadge.contentTintColor = .white
        addSubview(playBadge)
        addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(toggle)))
        #endif

        NSLayoutConstraint.activate([
            playBadge.centerXAnchor.constraint(equalTo: centerXAnchor),
            playBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            playBadge.widthAnchor.constraint(equalToConstant: 48),
            playBadge.heightAnchor.constraint(equalToConstant: 48),
        ])
        updateBadge()
    }

    #if canImport(UIKit) && !os(watchOS)
    override func layoutSubviews() { super.layoutSubviews(); playerLayer.frame = bounds }
    #elseif canImport(AppKit)
    override func layout() { super.layout(); playerLayer.frame = bounds }
    #endif
}

#endif
