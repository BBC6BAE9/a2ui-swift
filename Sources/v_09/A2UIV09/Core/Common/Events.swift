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

// MARK: - Subscription

/// Standard cleanup handle returned by all subscriptions.
/// Mirrors WebCore `Subscription`.
public final class Subscription {
    private var _unsubscribe: (() -> Void)?

    init(_ unsubscribe: @escaping () -> Void) {
        self._unsubscribe = unsubscribe
    }

    /// Removes the listener from the event source.
    public func unsubscribe() {
        _unsubscribe?()
        _unsubscribe = nil
    }

    deinit {
        // Do NOT auto-unsubscribe on deinit; caller controls lifetime (mirrors TS behaviour).
    }
}

// MARK: - EventSource

/// Public interface exposed by models — allows ONLY subscribing to events.
/// Mirrors WebCore `EventSource<T>`.
public protocol EventSource<T> {
    associatedtype T
    /// Subscribes to the event. Returns a `Subscription` that can be used to unsubscribe.
    @discardableResult
    func subscribe(_ listener: @escaping (T) -> Void) -> Subscription
}

// MARK: - EventEmitter

/// Internal implementation used by models.
/// Conforms to `EventSource` and adds the `emit` method.
/// Mirrors WebCore `EventEmitter<T>`.
public final class EventEmitter<T>: EventSource {
    private var listeners: [(id: UUID, fn: (T) -> Void)] = []

    public init() {}

    /// Subscribes a listener. Returns a `Subscription` to unsubscribe.
    @discardableResult
    public func subscribe(_ listener: @escaping (T) -> Void) -> Subscription {
        let id = UUID()
        listeners.append((id: id, fn: listener))
        return Subscription { [weak self] in
            self?.listeners.removeAll { $0.id == id }
        }
    }

    /// Emits an event to all current subscribers.
    public func emit(_ data: T) {
        // Snapshot to allow listener mutations during iteration
        let snapshot = listeners
        for item in snapshot {
            item.fn(data)
        }
    }

    /// Removes all listeners.
    public func dispose() {
        listeners.removeAll()
    }
}
