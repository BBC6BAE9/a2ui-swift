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

/// Spec v0.9 `AudioPlayer` — remote audio with play/pause, a scrubber, and
/// elapsed/duration labels. `AVPlayer` + a periodic time observer drive the UI.
final class A2UIAudioPlayer: PlatformView, A2UIPlatformComponent {

    private var player: AVPlayer?
    private var playing = false
    private var timeObserver: Any?
    private var duration: Double = 0
    private var subscriptions = DataSubscriptions()

    private let elapsedLabel = A2UILabelView.makeFieldLabel()
    private let durationLabel = A2UILabelView.makeFieldLabel()

    #if canImport(UIKit) && !os(watchOS)
    private let button = UIButton(type: .system)
    private let slider = UISlider()
    #elseif canImport(AppKit)
    private let button = NSButton()
    private let slider = NSSlider()
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupControls()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupControls()
    }

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        subscriptions.unsubscribeAll()
        guard let props = try? node.typedProperties(AudioPlayerProperties.self) else { return }
        let ctx = DataContext(surface: surface, path: node.dataContextPath)
        a2ui_applyAccessibility(node.accessibility, dataContext: ctx)
        setURL(ctx.resolve(props.url))
        ctx.subscribeString(for: props.url) { [weak self] in self?.setURL($0) }
            .store(in: &subscriptions)
    }

    deinit {
        subscriptions.unsubscribeAll()
        removeObserver()
    }

    private func setURL(_ string: String) {
        removeObserver()
        // Stop and release the previous player so it doesn't keep playing /
        // leak when the URL changes or is cleared.
        player?.pause()
        player = nil
        playing = false
        setTitle("Play")
        guard let url = URL(string: string), !string.isEmpty else { return }
        let player = AVPlayer(url: url)
        self.player = player

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.tick(time.seconds)
        }
        Task { [weak self] in
            if let seconds = try? await player.currentItem?.asset.load(.duration).seconds,
               seconds.isFinite {
                await MainActor.run { self?.setDuration(seconds) }
            }
        }
    }

    private func setDuration(_ seconds: Double) {
        duration = seconds
        setSliderMax(seconds)
        durationLabel.text = Self.format(seconds)
    }

    private func tick(_ seconds: Double) {
        guard seconds.isFinite else { return }
        elapsedLabel.text = Self.format(seconds)
        setSliderValue(seconds)
    }

    private func removeObserver() {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
    }

    @objc private func togglePlayback() {
        guard let player else { return }
        playing.toggle()
        playing ? player.play() : player.pause()
        setTitle(playing ? "Pause" : "Play")
    }

    @objc private func scrub() {
        player?.seek(to: CMTime(seconds: sliderValue, preferredTimescale: 600))
    }

    private static func format(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Platform shell

    private func setupControls() {
        let row = a2ui_makeStack(vertical: false, spacing: 8)
        row.addArrangedSubview(button)
        row.addArrangedSubview(elapsedLabel)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(durationLabel)
        a2ui_applyWeight(slider, weight: 1, vertical: false)
        a2ui_pinEdges(of: row)
        setTitle("Play")

        #if canImport(UIKit) && !os(watchOS)
        button.addTarget(self, action: #selector(togglePlayback), for: .touchUpInside)
        slider.addTarget(self, action: #selector(scrub), for: .valueChanged)
        #elseif canImport(AppKit)
        button.target = self; button.action = #selector(togglePlayback)
        button.setButtonType(.momentaryPushIn); button.bezelStyle = .rounded
        slider.target = self; slider.action = #selector(scrub)
        #endif
    }

    private func setTitle(_ title: String) {
        #if canImport(UIKit) && !os(watchOS)
        button.setTitle(title, for: .normal)
        #elseif canImport(AppKit)
        button.title = title
        #endif
    }

    #if canImport(UIKit) && !os(watchOS)
    private var sliderValue: Double { Double(slider.value) }
    private func setSliderValue(_ v: Double) { slider.value = Float(v) }
    private func setSliderMax(_ v: Double) { slider.maximumValue = Float(v) }
    #elseif canImport(AppKit)
    private var sliderValue: Double { slider.doubleValue }
    private func setSliderValue(_ v: Double) { slider.doubleValue = v }
    private func setSliderMax(_ v: Double) { slider.maxValue = v }
    #endif
}

#endif
