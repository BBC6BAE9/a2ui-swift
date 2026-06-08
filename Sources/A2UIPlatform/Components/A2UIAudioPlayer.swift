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

/// Spec v0.9 `AudioPlayer` — plays remote audio with a play/pause toggle.
/// `AVPlayer` is cross-platform; only the button control differs. Baseline.
final class A2UIAudioPlayer: PlatformView, A2UIPlatformComponent {

    private var player: AVPlayer?
    private var playing = false
    private var subscriptions = DataSubscriptions()

    #if canImport(UIKit) && !os(watchOS)
    private let button = UIButton(type: .system)
    #elseif canImport(AppKit)
    private let button = NSButton()
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        subscriptions.unsubscribeAll()
        guard let props = try? node.typedProperties(AudioPlayerProperties.self) else { return }
        let ctx = DataContext(surface: surface, path: node.dataContextPath)
        setURL(ctx.resolve(props.url))
        ctx.subscribeString(for: props.url) { [weak self] in self?.setURL($0) }
            .store(in: &subscriptions)
    }

    deinit { subscriptions.unsubscribeAll() }

    private func setURL(_ string: String) {
        guard let url = URL(string: string), !string.isEmpty else { return }
        player = AVPlayer(url: url)
        playing = false
        setTitle("Play")
    }

    @objc private func togglePlayback() {
        guard let player else { return }
        playing.toggle()
        playing ? player.play() : player.pause()
        setTitle(playing ? "Pause" : "Play")
    }

    // MARK: - Platform shell

    private func setupButton() {
        a2ui_pinEdges(of: button)
        #if canImport(UIKit) && !os(watchOS)
        button.addTarget(self, action: #selector(togglePlayback), for: .touchUpInside)
        #elseif canImport(AppKit)
        button.target = self
        button.action = #selector(togglePlayback)
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        #endif
        setTitle("Play")
    }

    private func setTitle(_ title: String) {
        #if canImport(UIKit) && !os(watchOS)
        button.setTitle(title, for: .normal)
        #elseif canImport(AppKit)
        button.title = title
        #endif
    }
}

#endif
