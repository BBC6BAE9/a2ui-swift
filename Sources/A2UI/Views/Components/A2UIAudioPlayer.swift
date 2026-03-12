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

#if canImport(AVKit) && !os(watchOS)
import AVKit
#endif
import SwiftUI

struct A2UIAudioPlayer: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(AudioPlayerProperties.self) {
            AudioPlayerNodeView(
                url: viewModel.resolveString(props.url, dataContextPath: dataContextPath),
                label: props.description.map {
                    viewModel.resolveString($0, dataContextPath: dataContextPath)
                },
                uiState: node.uiState as? AudioPlayerUIState,
                apStyle: style.audioPlayerStyle
            )
        }
    }
}

// MARK: - AudioPlayerNodeView

#if canImport(AVKit) && !os(watchOS)
/// Audio player with progress bar, matching `<audio controls>` functionality.
struct AudioPlayerNodeView: View {
    let url: String
    let label: String?
    var uiState: AudioPlayerUIState?
    var apStyle: A2UIStyle.AudioPlayerComponentStyle = .init()

    private var tint: Color { apStyle.tintColor ?? .accentColor }

    var body: some View {
        VStack(spacing: 8) {
            if let label, !label.isEmpty {
                HStack {
                    Text(label)
                        .font(apStyle.labelFont ?? .subheadline.weight(.medium))
                        .lineLimit(2)
                    Spacer()
                }
            }

            HStack(spacing: 12) {
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: (uiState?.isPlaying ?? false) ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(tint)
                }
                .buttonStyle(.plain)

                if let uiState, uiState.duration > 0 {
                    Text(formatTime(uiState.currentTime))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    #if os(tvOS)
                    ProgressView(value: uiState.currentTime, total: max(uiState.duration, 1))
                        .tint(tint)
                    #else
                    Slider(
                        value: Binding(
                            get: { uiState.currentTime },
                            set: { newTime in
                                uiState.currentTime = newTime
                                let target = CMTime(seconds: newTime, preferredTimescale: 600)
                                uiState.player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
                            }
                        ),
                        in: 0...max(uiState.duration, 1)
                    )
                    .tint(tint)
                    #endif

                    Text(formatTime(uiState.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: apStyle.cornerRadius ?? 10))
        .task(id: url) {
            guard let uiState, uiState.player == nil,
                  !url.isEmpty, let mediaUrl = URL(string: url) else { return }
            let player = await Task.detached(priority: .userInitiated) {
                AVPlayer(url: mediaUrl)
            }.value
            guard !Task.isCancelled else { return }
            uiState.player = player
            setupTimeObserver(player: player, state: uiState)
            observeDuration(player: player, state: uiState)
        }
        .onDisappear {
            cleanupObserver()
            uiState?.player?.pause()
            uiState?.isPlaying = false
        }
    }

    private func togglePlayback() {
        guard let uiState, let player = uiState.player else { return }
        if uiState.isPlaying {
            player.pause()
        } else {
            player.play()
        }
        uiState.isPlaying.toggle()
    }

    private func setupTimeObserver(player: AVPlayer, state: AudioPlayerUIState) {
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        state.timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard !time.seconds.isNaN else { return }
            state.currentTime = time.seconds
        }
    }

    private func observeDuration(player: AVPlayer, state: AudioPlayerUIState) {
        Task {
            guard let item = player.currentItem else { return }
            let dur = try? await item.asset.load(.duration)
            if let dur, !dur.seconds.isNaN, !Task.isCancelled {
                state.duration = dur.seconds
            }
        }
    }

    private func cleanupObserver() {
        guard let uiState else { return }
        if let observer = uiState.timeObserver {
            uiState.player?.removeTimeObserver(observer)
            uiState.timeObserver = nil
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN, seconds.isFinite else { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
#else
/// watchOS: AVKit is unavailable; show a static audio label.
struct AudioPlayerNodeView: View {
    let url: String
    let label: String?
    var uiState: AudioPlayerUIState?
    var apStyle: A2UIStyle.AudioPlayerComponentStyle = .init()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.title)
                .foregroundStyle(.tertiary)

            if let label, !label.isEmpty {
                Text(label)
                    .font(apStyle.labelFont ?? .subheadline)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: apStyle.cornerRadius ?? 10))
    }
}
#endif

// MARK: - Previews

#Preview("AudioPlayer") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"AudioPlayer":{"url":{"literalString":"https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"},"description":{"literalString":"Sample Audio Track"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
