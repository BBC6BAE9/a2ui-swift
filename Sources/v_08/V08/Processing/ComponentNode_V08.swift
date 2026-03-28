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

import Observation

// MARK: - Accessibility Attributes

/// Accessibility attributes from the A2UI spec's `ComponentCommon`.
public struct A2UIAccessibility_V08 {
    public var label: StringValue_V08?
    public var description: StringValue_V08?
}

// MARK: - ComponentNode_V08

/// A resolved node in the component tree.
///
/// The tree is rebuilt by `SurfaceViewModel_V08.rebuildComponentTree()` whenever
/// the component buffer or data model changes. UI state (`uiState`) is
/// migrated across rebuilds by matching node IDs, so that stateful views
/// (Tabs selectedIndex, Modal isPresented, etc.) survive LazyVStack recycling.
@Observable
public final class ComponentNode_V08: Identifiable {
    /// Full ID = baseComponentId + idSuffix (unique within the tree).
    public let id: String

    /// The key into `SurfaceViewModel_V08.components` dictionary.
    public let baseComponentId: String

    /// Resolved component type.
    public let type: ComponentType_V08

    /// Data context path for this node (e.g. "/items/0").
    public let dataContextPath: String

    /// Layout weight (flex-grow equivalent).
    public var weight: Double?

    /// Raw payload — view layer calls `typedProperties()` at render time so
    /// that path-bound values read from `@Observable dataModel` and trigger
    /// precise SwiftUI updates.
    public var payload: RawComponentPayload_V08

    /// Pre-resolved child nodes.
    public var children: [ComponentNode_V08]

    /// Per-node UI state. Rebuilt trees get a fresh default; the migration
    /// step replaces it with the previous instance (same object reference)
    /// so SwiftUI does not see a change.
    public var uiState: (any ComponentUIState)?

    /// Accessibility attributes parsed from the component instance.
    public var accessibility: A2UIAccessibility_V08?

    public init(
        id: String,
        baseComponentId: String,
        type: ComponentType_V08,
        dataContextPath: String,
        weight: Double?,
        payload: RawComponentPayload_V08,
        children: [ComponentNode_V08] = [],
        uiState: (any ComponentUIState)? = nil,
        accessibility: A2UIAccessibility_V08? = nil
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
