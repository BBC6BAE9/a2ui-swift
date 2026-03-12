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

// MARK: - Design Notes
//
// AVPlayerViewController in ScrollView + LazyVStack causes severe scroll jank
// on iOS — the system runs Visual Look Up (VKCImageAnalyzer) on every
// appear/disappear cycle, blocking the main thread.
//
// Solution: Singleton SharedPlayerController
// - One AVPlayerViewController (iOS/tvOS/visionOS) or AVPlayerView (macOS)
//   shared across ALL Video components globally.
// - Inactive videos show a poster (async first-frame thumbnail + play button).
//   Tapping activates the singleton: attaches AVPlayer and reparents the VC's
//   .view into that video's container. Only one Video plays at a time.
// - The VC is never created/destroyed during scrolling — zero scroll overhead.
//
// Thumbnails are loaded via Task.detached (survives LazyVStack view recycling)
// and cached on VideoUIState, which persists with SurfaceViewModel.
// Fetches frame at t=1s to avoid common black first-frames.
//
// watchOS: AVKit unavailable, static placeholder only.

struct A2UIVideo: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(VideoProperties.self) {
            let urlString = viewModel.resolveString(
                props.url, dataContextPath: dataContextPath
            )
            let cr = style.videoStyle.cornerRadius ?? 10
            if !urlString.isEmpty, URL(string: urlString) != nil {
                VideoNodeView(
                    urlString: urlString,
                    uiState: node.uiState as? VideoUIState,
                    nodeId: node.id,
                    cornerRadius: cr
                )
            } else {
                RoundedRectangle(cornerRadius: cr)
                    .fill(Color.gray.opacity(0.15))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                    }
            }
        }
    }
}

// MARK: - SharedPlayerController (singleton, mutual exclusion)

#if canImport(AVKit) && !os(watchOS)

/// Global singleton that owns the one and only `AVPlayerViewController`.
/// All Video components share this instance. Only one Video can be "active"
/// (playing) at a time — activating a new one deactivates the previous.
@Observable
final class SharedPlayerController {
    static let shared = SharedPlayerController()

    /// The node ID of the currently active Video, or nil if none.
    var activeNodeId: String?

    #if os(iOS) || os(tvOS) || os(visionOS)
    /// The single reusable AVPlayerViewController.
    let playerViewController: AVPlayerViewController = {
        let vc = AVPlayerViewController()
        vc.entersFullScreenWhenPlaybackBegins = false
        if #available(iOS 16.0, tvOS 16.0, visionOS 1.0, *) {
            vc.allowsVideoFrameAnalysis = false
        }
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

    /// Activate a Video node: attach the player and start playback.
    func activate(nodeId: String, player: AVPlayer) {
        // Deactivate previous if different.
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

    /// Deactivate the current Video: pause and detach player.
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

    // MARK: - Poster

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

    // MARK: - Thumbnail

    /// Kicks off thumbnail generation in a detached task so it survives
    /// SwiftUI view lifecycle cancellation (LazyVStack recycling).
    private func loadThumbnailIfNeeded() async {
        guard let uiState, !uiState.thumbnailLoaded else { return }
        // Mark immediately to prevent duplicate loads.
        uiState.thumbnailLoaded = true

        let urlStr = urlString
        Task.detached(priority: .utility) {
            guard let url = URL(string: urlStr) else { return }
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 360)

            // Request 1 s in — many videos have a black frame at 0 s.
            // The generator snaps to the nearest available keyframe.
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
                uiState.thumbnail = UIImage(cgImage: cgImage)
                #elseif canImport(AppKit)
                uiState.thumbnail = NSImage(
                    cgImage: cgImage,
                    size: NSSize(width: cgImage.width, height: cgImage.height)
                )
                #endif
            }
        }
    }
}

// MARK: - EmbeddedPlayerView

/// Embeds the singleton AVPlayerViewController into the SwiftUI hierarchy
/// by adding its view as a subview of a container UIView. This avoids
/// SwiftUI's make/dismantle lifecycle — the VC is never recreated.
#if os(iOS) || os(tvOS) || os(visionOS)
struct EmbeddedPlayerView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let shared = SharedPlayerController.shared
        let vc = shared.playerViewController
        // The VC's view is added directly. Parent VC management is handled
        // by UIViewRepresentable's internal coordinator.
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
        // Remove the VC's view from this container but do NOT release the VC.
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
/// watchOS: AVKit is unavailable; show a placeholder.
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

// MARK: - Previews

#Preview("Video") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Video":{"url":{"literalString":"https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
