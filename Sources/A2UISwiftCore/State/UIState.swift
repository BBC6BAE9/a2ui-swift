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

package protocol ComponentUIState: AnyObject {}

@Observable
package final class TabsUIState: ComponentUIState {
    package var selectedIndex: Int = 0
    package init() {}
}

@Observable
package final class ModalUIState: ComponentUIState {
    package var isPresented: Bool = false
    package init() {}
}

@Observable
package final class AudioPlayerUIState: ComponentUIState {
    package var isPlaying: Bool = false
    package var currentTime: Double = 0
    package var duration: Double = 0
    #if canImport(AVKit) && !os(watchOS)
    package var player: AVPlayer?
    package var timeObserver: Any?
    #endif
    package init() {}
}

@Observable
package final class VideoUIState: ComponentUIState, @unchecked Sendable {
    #if canImport(AVKit) && !os(watchOS)
    package var player: AVPlayer?
    #endif
    #if canImport(UIKit) && !os(watchOS) || canImport(AppKit)
    /// Cached first-frame thumbnail. Fetched once asynchronously, persists
    /// across LazyVStack recycling and tree rebuilds.
    package var thumbnail: PlatformImage?
    package var thumbnailLoaded = false
    #endif
    package init() {}
}

@Observable
package final class MultipleChoiceUIState: ComponentUIState {
    package var filterText: String = ""
    package init() {}
}
