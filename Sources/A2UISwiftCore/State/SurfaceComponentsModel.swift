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

// MARK: - Errors

public enum SurfaceComponentsError: Error, LocalizedError {
    case duplicateComponent(id: String)

    public var errorDescription: String? {
        switch self {
        case .duplicateComponent(let id):
            return "Component with id '\(id)' already exists."
        }
    }
}

// MARK: - SurfaceComponentsModel

/// Manages the collection of components for a specific surface.
/// Mirrors WebCore `SurfaceComponentsModel`.
@Observable
public final class SurfaceComponentsModel {
    // Insertion-ordered backing store: keys in insertion order + lookup dict
    private var insertionOrder: [String] = []
    private var componentMap: [String: ComponentModel] = [:]

    private let _onCreated = EventEmitter<ComponentModel>()
    private let _onDeleted = EventEmitter<String>()

    /// Fires when a new component is added to the model.
    /// Mirrors WebCore `onCreated: EventSource<ComponentModel>`.
    public var onCreated: some EventSource<ComponentModel> { _onCreated }

    /// Fires when a component is removed, providing the ID of the deleted component.
    /// Mirrors WebCore `onDeleted: EventSource<string>`.
    public var onDeleted: some EventSource<String> { _onDeleted }

    public init() {}

    /// Retrieves a component by its ID. Returns nil if not found.
    public func get(_ id: String) -> ComponentModel? {
        componentMap[id]
    }

    /// Returns components in insertion order as (id, ComponentModel) pairs.
    /// Mirrors WebCore `entries` iterator.
    public var entries: [(String, ComponentModel)] {
        insertionOrder.compactMap { id in
            componentMap[id].map { (id, $0) }
        }
    }

    /// All components in the collection (insertion order).
    public var all: [ComponentModel] {
        insertionOrder.compactMap { componentMap[$0] }
    }

    /// Number of components in the collection.
    public var count: Int {
        componentMap.count
    }

    /// Adds a component. Throws if a component with the same ID already exists.
    public func addComponent(_ component: ComponentModel) throws {
        guard componentMap[component.id] == nil else {
            throw SurfaceComponentsError.duplicateComponent(id: component.id)
        }
        insertionOrder.append(component.id)
        componentMap[component.id] = component
        _onCreated.emit(component)
    }

    /// Removes a component by ID. Disposes the component on removal.
    /// No-op if not found.
    public func removeComponent(_ id: String) {
        guard let component = componentMap[id] else { return }
        componentMap.removeValue(forKey: id)
        insertionOrder.removeAll { $0 == id }
        component.dispose()
        _onDeleted.emit(id)
    }

    /// Disposes of the model and all its components.
    public func dispose() {
        for component in componentMap.values {
            component.dispose()
        }
        componentMap.removeAll()
        insertionOrder.removeAll()
        _onCreated.dispose()
        _onDeleted.dispose()
    }
}
