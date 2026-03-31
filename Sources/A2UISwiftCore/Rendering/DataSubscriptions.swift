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

// MARK: - DataSubscriptions
//
// A bag that holds live DataSubscription tokens and bulk-unsubscribes on demand.
//
// Purpose
// -------
// UIKit cells / AppKit views must cancel their reactive subscriptions when
// they are reused, deallocated, or moved off-screen.  Without a central
// cleanup point, subscriptions silently accumulate until the DataModel is
// disposed — the exact leak described in binder-layer-design.md §5.1.
//
// Usage (UIKit)
// -------------
//   class NameCell: UITableViewCell {
//       private var subscriptions = DataSubscriptions()
//
//       func configure(ctx: DataContext, props: TextFieldProperties) {
//           subscriptions.unsubscribeAll()          // ← clear previous cell's bindings
//           ctx.subscribeString(for: props.label) { [weak self] in
//               self?.label.text = $0
//           }.store(in: &subscriptions)
//       }
//
//       override func prepareForReuse() {
//           super.prepareForReuse()
//           subscriptions.unsubscribeAll()
//       }
//   }
//
// Design note
// -----------
// Intentionally NOT a deinit-based auto-unsubscribe bag (unlike Combine's
// Set<AnyCancellable>). DataContext is a surface-level shared object whose
// lifetime exceeds individual cells — see binder-layer-design.md §5.1.
// Callers control cleanup explicitly via unsubscribeAll() or prepareForReuse().

import Foundation

/// A mutable collection of `DataSubscription` tokens.
/// Unsubscribes all stored subscriptions on demand.
///
/// Mirrors the role of Combine's `Set<AnyCancellable>` but for
/// `DataSubscription`-based reactive bindings.
public struct DataSubscriptions {

    private var tokens: [() -> Void] = []

    public init() {}

    /// Cancels all stored subscriptions and empties the bag.
    public mutating func unsubscribeAll() {
        tokens.forEach { $0() }
        tokens.removeAll()
    }

    /// Stores a typed subscription in this bag.
    /// The subscription's `unsubscribe()` will be called when `unsubscribeAll()` is invoked.
    public mutating func store<T>(_ subscription: DataSubscription<T>) {
        tokens.append { subscription.unsubscribe() }
    }
}

// MARK: - DataSubscription.store(in:)

extension DataSubscription {

    /// Stores this subscription in a `DataSubscriptions` bag.
    /// Convenience that mirrors Combine's `.store(in: &cancellables)`.
    ///
    /// Example:
    /// ```swift
    /// ctx.subscribeString(for: props.label) { [weak self] in
    ///     self?.label.text = $0
    /// }.store(in: &subscriptions)
    /// ```
    @discardableResult
    public func store(in bag: inout DataSubscriptions) -> Self {
        bag.store(self)
        return self
    }
}
