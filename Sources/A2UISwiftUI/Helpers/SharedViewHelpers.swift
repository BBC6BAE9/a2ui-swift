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

// Shared generic view helpers used by both V08 and V09 component views.
// These types have no version-specific dependencies and are duplicated here
// to keep each version target self-contained (mirroring WebCore's design).

#if canImport(AVKit) && !os(watchOS)
import AVKit
#endif
import SwiftUI
import A2UISwiftCore

// MARK: - AudioPlayerNodeView

#if canImport(AVKit) && !os(watchOS)
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

// MARK: - SharedPlayerController (singleton, mutual exclusion)

#if canImport(AVKit) && !os(watchOS)

@Observable
@MainActor
final class SharedPlayerController {
    static let shared = SharedPlayerController()

    var activeNodeId: String?

    #if os(iOS) || os(tvOS) || os(visionOS)
    let playerViewController: AVPlayerViewController = {
        let vc = AVPlayerViewController()
        vc.entersFullScreenWhenPlaybackBegins = false
        #if os(iOS) || os(tvOS)
        if #available(iOS 16.0, tvOS 16.0, visionOS 1.0, *) {
            vc.allowsVideoFrameAnalysis = false
        }
        #endif
        return vc
    }()
    #endif

    #if os(macOS)
    let playerView: AVPlayerView = {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        return view
    }()
    #endif

    private init() {}

    func activate(nodeId: String, player: AVPlayer) {
        if activeNodeId != nil, activeNodeId != nodeId {
            deactivate()
        }
        activeNodeId = nodeId
        #if os(iOS) || os(tvOS) || os(visionOS)
        playerViewController.player = player
        #elseif os(macOS)
        playerView.player = player
        #endif
        player.play()
    }

    func deactivate() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        playerViewController.player?.pause()
        playerViewController.player = nil
        #elseif os(macOS)
        playerView.player?.pause()
        playerView.player = nil
        #endif
        activeNodeId = nil
    }
}

// MARK: - VideoNodeView

struct VideoNodeView: View {
    let urlString: String
    var uiState: VideoUIState?
    let nodeId: String
    var cornerRadius: CGFloat = 10

    private var shared: SharedPlayerController { .shared }
    private var isActive: Bool { shared.activeNodeId == nodeId }

    var body: some View {
        ZStack {
            if isActive {
                EmbeddedPlayerView()
            } else {
                posterView
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task {
            await loadThumbnailIfNeeded()
        }
        .onDisappear {
            if isActive {
                shared.deactivate()
            }
        }
    }

    private var posterView: some View {
        Button {
            if let uiState {
                if uiState.player == nil, let url = URL(string: urlString) {
                    uiState.player = AVPlayer(url: url)
                }
                if let player = uiState.player {
                    shared.activate(nodeId: nodeId, player: player)
                }
            }
        } label: {
            ZStack {
                thumbnailBackground
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .foregroundStyle(.primary)
                            .offset(x: 2)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnailBackground: some View {
        #if canImport(UIKit) && !os(watchOS)
        if let thumb = uiState?.thumbnail {
            Image(uiImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color.clear.background(.fill.tertiary)
        }
        #elseif canImport(AppKit)
        if let thumb = uiState?.thumbnail {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color.clear.background(.fill.tertiary)
        }
        #else
        Color.clear.background(.fill.tertiary)
        #endif
    }

    private func loadThumbnailIfNeeded() async {
        #if !os(visionOS)
        guard let uiState, !uiState.thumbnailLoaded else { return }
        uiState.thumbnailLoaded = true

        let urlStr = urlString
        let capturedState = uiState
        Task.detached(priority: .utility) {
            guard let url = URL(string: urlStr) else { return }
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 360)

            let time = CMTime(seconds: 1, preferredTimescale: 600)
            let cgImage: CGImage?
            if #available(iOS 16.0, macOS 13.0, tvOS 16.0, visionOS 1.0, *) {
                cgImage = try? await generator.image(at: time).image
            } else {
                cgImage = try? generator.copyCGImage(at: time, actualTime: nil)
            }
            guard let cgImage else { return }

            await MainActor.run {
                #if canImport(UIKit) && !os(watchOS)
                capturedState.thumbnail = PlatformImage(cgImage: cgImage)
                #elseif canImport(AppKit)
                capturedState.thumbnail = PlatformImage(
                    cgImage: cgImage,
                    size: NSSize(width: cgImage.width, height: cgImage.height)
                )
                #endif
            }
        }
        #endif
    }
}

// MARK: - EmbeddedPlayerView

#if os(iOS) || os(tvOS) || os(visionOS)
struct EmbeddedPlayerView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        let shared = SharedPlayerController.shared
        let vc = shared.playerViewController
        vc.view.frame = container.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(vc.view)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        let vc = SharedPlayerController.shared.playerViewController
        if vc.view.superview !== container {
            vc.view.frame = container.bounds
            vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(vc.view)
        }
    }

    static func dismantleUIView(_ container: UIView, coordinator: ()) {
        let vc = SharedPlayerController.shared.playerViewController
        if vc.view.superview === container {
            vc.view.removeFromSuperview()
        }
    }
}
#elseif os(macOS)
struct EmbeddedPlayerView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let shared = SharedPlayerController.shared
        let playerView = shared.playerView
        playerView.frame = container.bounds
        playerView.autoresizingMask = [.width, .height]
        container.addSubview(playerView)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        let playerView = SharedPlayerController.shared.playerView
        if playerView.superview !== container {
            playerView.frame = container.bounds
            playerView.autoresizingMask = [.width, .height]
            container.addSubview(playerView)
        }
    }

    static func dismantleNSView(_ container: NSView, coordinator: ()) {
        let playerView = SharedPlayerController.shared.playerView
        if playerView.superview === container {
            playerView.removeFromSuperview()
        }
    }
}
#endif

#else
// MARK: - VideoNodeView (watchOS)

struct VideoNodeView: View {
    let urlString: String
    var uiState: VideoUIState?
    let nodeId: String
    var cornerRadius: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.15))
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                Image(systemName: "video.slash")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
    }
}
#endif

// MARK: - A2UITextFieldView

struct A2UITextFieldView: View {
    let label: String
    @Binding var text: String
    let variant: String?
    var checksErrorMessage: String? = nil

    @Environment(\.a2uiStyle) private var style
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading) {
            fieldForVariant
                .focused($isFocused)

            if let msg = checksErrorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(style.textFieldStyle.errorColor ?? .red)
            }
        }
    }

    @ViewBuilder
    private var fieldForVariant: some View {
        let tfStyle = style.textFieldStyle

        switch variant {
        case "obscured":
            SecureField(label, text: $text)
                #if !os(watchOS) && !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif

        case "longText":
            #if os(watchOS) || os(tvOS)
            SwiftUI.TextField(label, text: $text)
            #else
            VStack(alignment: .leading) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let bg = tfStyle.longTextBackgroundColor {
                    TextEditor(text: $text)
                        .frame(minHeight: tfStyle.longTextMinHeight ?? 100)
                        .scrollContentBackground(.hidden)
                        .padding()
                        .background(bg, in: .rect(cornerRadius: 8, style: .continuous))
                } else {
                    TextEditor(text: $text)
                        .frame(minHeight: tfStyle.longTextMinHeight ?? 100)
                        .scrollContentBackground(.hidden)
                        .padding()
                        .background(.fill.quaternary, in: .rect(cornerRadius: 8, style: .continuous))
                }
            }
            #endif

        case "number":
            SwiftUI.TextField(label, text: $text)
                #if !os(watchOS) && !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif

        case "date":
            SwiftUI.TextField(label, text: $text)
                #if !os(watchOS) && !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif

        case "shortText":
            SwiftUI.TextField(label, text: $text)
                #if !os(watchOS) && !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif

        default:
            SwiftUI.TextField(label, text: $text)
                #if !os(watchOS) && !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
        }
    }

}

// MARK: - MultipleChoiceLogic

enum MultipleChoiceLogic {
    static func toggle(
        value: String,
        in selections: [String],
        maxAllowed: Int?
    ) -> [String] {
        var result = selections
        if let idx = result.firstIndex(of: value) {
            result.remove(at: idx)
        } else {
            if maxAllowed == 1 {
                result = [value]
            } else if let max = maxAllowed, result.count >= max {
                return result
            } else {
                result.append(value)
            }
        }
        return result
    }

    static func filter(
        options: [(label: String, value: String)],
        query: String
    ) -> [(label: String, value: String)] {
        guard !query.isEmpty else { return options }
        return options.filter {
            $0.label.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - FlowLayout (Chips)

struct FlowLayout: Layout {
    var spacing: CGFloat?

    func sizeThatFits(
        proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrange(
        proposal: ProposedViewSize, subviews: Subviews
    ) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        let gap = spacing ?? 8
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + gap
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + gap
        }

        return ArrangeResult(
            size: CGSize(width: maxWidth, height: y + rowHeight),
            positions: positions
        )
    }
}
