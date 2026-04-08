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

// MARK: - ComponentNode

/// A resolved node in the v0.9 component tree.
/// v0.9 uses flat component format — properties stored directly in the instance.
@Observable
public final class ComponentNode: Identifiable {
    public let id: String
    public let baseComponentId: String
    public let type: ComponentType
    public let dataContextPath: String
    public var weight: Double?

    /// v0.9 stores properties directly on the instance (flat format).
    public var instance: RawComponent

    public var children: [ComponentNode]
    package var uiState: (any ComponentUIState)?
    public var accessibility: A2UIAccessibility?

    package init(
        id: String,
        baseComponentId: String,
        type: ComponentType,
        dataContextPath: String,
        weight: Double?,
        instance: RawComponent,
        children: [ComponentNode] = [],
        uiState: (any ComponentUIState)? = nil,
        accessibility: A2UIAccessibility? = nil
    ) {
        self.id = id
        self.baseComponentId = baseComponentId
        self.type = type
        self.dataContextPath = dataContextPath
        self.weight = weight
        self.instance = instance
        self.children = children
        self.uiState = uiState
        self.accessibility = accessibility
    }

    /// Decode the properties into a strongly-typed struct.
    public func typedProperties<T: Decodable>(_ type: T.Type) throws -> T {
        try instance.typedProperties(type)
    }
}
