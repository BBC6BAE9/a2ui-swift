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

#if canImport(AVFoundation) && !os(watchOS)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
/// Platform-agnostic image type.
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
/// Platform-agnostic image type.
public typealias PlatformImage = NSImage
#endif
import Observation

// MARK: - ComponentUIState Protocol & Concrete Types
// Shared across protocol versions — pure SwiftUI state, no protocol-specific fields.

public protocol ComponentUIState: AnyObject {}

@Observable
public final class TabsUIState: ComponentUIState {
    public var selectedIndex: Int = 0
}

@Observable
public final class ModalUIState: ComponentUIState {
    public var isPresented: Bool = false
}

@Observable
public final class AudioPlayerUIState: ComponentUIState {
    public var isPlaying: Bool = false
    public var currentTime: Double = 0
    public var duration: Double = 0
    #if canImport(AVKit) && !os(watchOS)
    public var player: AVPlayer?
    var timeObserver: Any?
    #endif
}

@Observable
public final class VideoUIState: ComponentUIState, @unchecked Sendable {
    #if canImport(AVKit) && !os(watchOS)
    public var player: AVPlayer?
    #endif
    #if canImport(UIKit) && !os(watchOS) || canImport(AppKit)
    /// Cached first-frame thumbnail. Fetched once asynchronously, persists
    /// across LazyVStack recycling and tree rebuilds.
    public var thumbnail: PlatformImage?
    public var thumbnailLoaded = false
    #endif
}

@Observable
public final class MultipleChoiceUIState: ComponentUIState {
    public var filterText: String = ""
}
