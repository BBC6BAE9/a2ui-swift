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

import Foundation
import Observation

/// Represents the state model for an individual UI component.
/// Mirrors WebCore `ComponentModel`.
///
/// - `id` and `type` are immutable (component identity never changes).
/// - `properties` is observable — SwiftUI views that read it will auto-refresh on change.
@Observable
public final class ComponentModel: Identifiable {
    public let id: String
    public let type: String

    private let _onUpdated = EventEmitter<ComponentModel>()

    /// Fires whenever the component's properties are replaced or mutated.
    /// Mirrors WebCore `onUpdated: EventSource<ComponentModel>`.
    public var onUpdated: some EventSource<ComponentModel> { _onUpdated }

    public var properties: [String: AnyCodable] {
        didSet { _onUpdated.emit(self) }
    }

    public init(id: String, type: String, properties: [String: AnyCodable] = [:]) {
        self.id = id
        self.type = type
        self.properties = properties
    }

    /// Flat representation merging identity + properties.
    /// Mirrors WebCore `componentTree` getter.
    public var componentTree: [String: AnyCodable] {
        var tree = properties
        tree["id"] = .string(id)
        tree["type"] = .string(type)
        return tree
    }

    /// Disposes of the component and its event emitters.
    /// Mirrors WebCore `ComponentModel.dispose()`.
    public func dispose() {
        _onUpdated.dispose()
    }
}
