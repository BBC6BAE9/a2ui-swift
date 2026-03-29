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

/// The root state model for the A2UI system.
/// Manages the collection of active surfaces.
/// Mirrors WebCore `SurfaceGroupModel`.
public final class SurfaceGroupModel {

    private var surfaces: [String: SurfaceModel] = [:]
    /// Tracks per-surface action subscriptions so we can unsubscribe on deletion.
    private var surfaceSubscriptions: [String: Subscription] = [:]

    private let _onSurfaceCreated = EventEmitter<SurfaceModel>()
    private let _onSurfaceDeleted = EventEmitter<String>()
    private let _onAction = EventEmitter<A2uiClientAction>()

    /// Fires when a new surface is added.
    /// Mirrors WebCore `onSurfaceCreated: EventSource<SurfaceModel>`.
    public var onSurfaceCreated: some EventSource<SurfaceModel> { _onSurfaceCreated }

    /// Fires when a surface is removed.
    /// Mirrors WebCore `onSurfaceDeleted: EventSource<string>`.
    public var onSurfaceDeleted: some EventSource<String> { _onSurfaceDeleted }

    /// Fires when an action is dispatched from ANY surface in the group.
    /// Mirrors WebCore `onAction: EventSource<A2uiClientAction>`.
    public var onAction: some EventSource<A2uiClientAction> { _onAction }

    public init() {}

    /// Adds a surface to the group.
    /// Ignores if a surface with the same ID already exists (mirrors WebCore: console.warn + return).
    public func addSurface(_ surface: SurfaceModel) {
        guard surfaces[surface.id] == nil else {
            print("A2UI: Surface with id '\(surface.id)' already exists. Ignoring.")
            return
        }

        surfaces[surface.id] = surface

        // Subscribe to surface actions and propagate; store subscription for cleanup
        let sub = surface.onAction.subscribe { [weak self] action in
            self?._onAction.emit(action)
        }
        surfaceSubscriptions[surface.id] = sub

        _onSurfaceCreated.emit(surface)
    }

    /// Removes a surface from the group by its ID.
    /// Unsubscribes from the surface's action emitter, then disposes of the surface.
    public func deleteSurface(_ id: String) {
        guard let surface = surfaces[id] else { return }

        // Unsubscribe before dispose so stale actions don't propagate
        surfaceSubscriptions[id]?.unsubscribe()
        surfaceSubscriptions.removeValue(forKey: id)

        surfaces.removeValue(forKey: id)
        surface.dispose()
        _onSurfaceDeleted.emit(id)
    }

    /// Retrieves a surface by its ID.
    public func getSurface(_ id: String) -> SurfaceModel? {
        surfaces[id]
    }

    /// Returns a read-only view of all active surfaces.
    /// Mirrors WebCore `surfacesMap: ReadonlyMap`.
    public var surfacesMap: [String: SurfaceModel] {
        surfaces
    }

    /// Disposes of the group and all its surfaces.
    public func dispose() {
        for id in Array(surfaces.keys) {
            deleteSurface(id)
        }
        _onSurfaceCreated.dispose()
        _onSurfaceDeleted.dispose()
        _onAction.dispose()
    }
}
