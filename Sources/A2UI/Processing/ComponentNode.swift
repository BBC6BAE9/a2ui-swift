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
#elseif canImport(AppKit)
import AppKit
#endif
import Observation

// MARK: - ComponentUIState Protocol & Concrete Types

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
public final class VideoUIState: ComponentUIState {
    #if canImport(AVKit) && !os(watchOS)
    public var player: AVPlayer?
    #endif
    #if canImport(UIKit) && !os(watchOS)
    /// Cached first-frame thumbnail. Fetched once asynchronously, persists
    /// across LazyVStack recycling and tree rebuilds.
    public var thumbnail: UIImage?
    public var thumbnailLoaded = false
    #elseif canImport(AppKit)
    public var thumbnail: NSImage?
    public var thumbnailLoaded = false
    #endif
}

@Observable
public final class MultipleChoiceUIState: ComponentUIState {
    public var filterText: String = ""
}

// MARK: - Accessibility Attributes

/// Accessibility attributes from the A2UI spec's `ComponentCommon`.
public struct A2UIAccessibility {
    public var label: StringValue?
    public var description: StringValue?
}

// MARK: - ComponentNode

/// A resolved node in the component tree.
///
/// The tree is rebuilt by `SurfaceViewModel.rebuildComponentTree()` whenever
/// the component buffer or data model changes. UI state (`uiState`) is
/// migrated across rebuilds by matching node IDs, so that stateful views
/// (Tabs selectedIndex, Modal isPresented, etc.) survive LazyVStack recycling.
@Observable
public final class ComponentNode: Identifiable {
    /// Full ID = baseComponentId + idSuffix (unique within the tree).
    public let id: String

    /// The key into `SurfaceViewModel.components` dictionary.
    public let baseComponentId: String

    /// Resolved component type.
    public let type: ComponentType

    /// Data context path for this node (e.g. "/items/0").
    public let dataContextPath: String

    /// Layout weight (flex-grow equivalent).
    public var weight: Double?

    /// Raw payload — view layer calls `typedProperties()` at render time so
    /// that path-bound values read from `@Observable dataModel` and trigger
    /// precise SwiftUI updates.
    public var payload: RawComponentPayload

    /// Pre-resolved child nodes.
    public var children: [ComponentNode]

    /// Per-node UI state. Rebuilt trees get a fresh default; the migration
    /// step replaces it with the previous instance (same object reference)
    /// so SwiftUI does not see a change.
    public var uiState: (any ComponentUIState)?

    /// Accessibility attributes parsed from the component instance.
    public var accessibility: A2UIAccessibility?

    public init(
        id: String,
        baseComponentId: String,
        type: ComponentType,
        dataContextPath: String,
        weight: Double?,
        payload: RawComponentPayload,
        children: [ComponentNode] = [],
        uiState: (any ComponentUIState)? = nil,
        accessibility: A2UIAccessibility? = nil
    ) {
        self.id = id
        self.baseComponentId = baseComponentId
        self.type = type
        self.dataContextPath = dataContextPath
        self.weight = weight
        self.payload = payload
        self.children = children
        self.uiState = uiState
        self.accessibility = accessibility
    }
}
