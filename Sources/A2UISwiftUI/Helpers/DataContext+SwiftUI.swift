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

import SwiftUI
import A2UISwiftCore

// MARK: - DataContext+SwiftUI
//
// SwiftUI-specific extensions on DataContext.
// Provides `Binding<T>` factory methods for two-way data binding to the DataModel.
//
// Design: mirrors binder-layer-design.md §4.1 (DataContext+SwiftUI.swift layer).
//
// Architecture:
//   get: reads PathSlot.value via DataContext — SwiftUI builds a per-path reactive dependency.
//   set: writes back through DataContext.set() — updates DataModel, PathSlot fires, view re-renders.
//
// These methods must be called from a @MainActor context (e.g., inside SwiftUI View.body).

extension DataContext {

    // MARK: - stringBinding(for:)

    /// Returns a two-way `Binding<String>` for a `DynamicString?`.
    ///
    /// - `get`: resolves the dynamic value reactively (PathSlot @Observable in SwiftUI body).
    /// - `set`: writes back to DataModel only if the value is a data binding; no-op for literals.
    ///
    /// Mirrors binder-layer-design.md §4.1 `stringBinding(for:)`.
    @MainActor
    public func stringBinding(for value: DynamicString?) -> Binding<String> {
        let fallback: String = {
            if case .literal(let s) = value { return s }
            return ""
        }()
        return Binding<String>(
            get: {
                guard let value else { return fallback }
                return self.resolve(value)
            },
            set: { newValue in
                guard case .dataBinding(let path) = value else { return }
                try? self.set(path, value: .string(newValue))
            }
        )
    }

    // MARK: - boolBinding(for:)

    /// Returns a two-way `Binding<Bool>` for a `DynamicBoolean`.
    ///
    /// - `get`: resolves the dynamic value reactively (PathSlot @Observable in SwiftUI body).
    /// - `set`: writes back to DataModel only if the value is a data binding.
    ///
    /// Mirrors binder-layer-design.md §4.1 `boolBinding(for:)`.
    @MainActor
    public func boolBinding(for value: DynamicBoolean) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.resolve(value) },
            set: { newValue in
                guard case .dataBinding(let path) = value else { return }
                try? self.set(path, value: .bool(newValue))
            }
        )
    }

    // MARK: - doubleBinding(for:fallback:)

    /// Returns a two-way `Binding<Double>` for a `DynamicNumber`.
    ///
    /// - `get`: resolves the dynamic value reactively; uses `fallback` when the resolved
    ///   value is `nil` (path not yet populated) or the value is a literal.
    /// - `set`: writes back to DataModel only if the value is a data binding.
    ///
    /// Mirrors binder-layer-design.md §4.1 `doubleBinding(for:)`.
    @MainActor
    public func doubleBinding(for value: DynamicNumber, fallback: Double = 0) -> Binding<Double> {
        let effectiveFallback: Double = {
            if case .literal(let n) = value { return n }
            return fallback
        }()
        return Binding<Double>(
            get: { self.resolve(value) ?? effectiveFallback },
            set: { newValue in
                guard case .dataBinding(let path) = value else { return }
                try? self.set(path, value: .number(newValue))
            }
        )
    }

    // MARK: - dateBinding(for:)

    /// Returns a two-way `Binding<Date>` for a `DynamicString` containing an ISO 8601 date.
    ///
    /// - `get`: resolves the string, parses with `ISO8601DateFormatter`; falls back to `Date()`.
    /// - `set`: formats the new `Date` to ISO 8601 and writes back to DataModel.
    ///
    /// Mirrors binder-layer-design.md §4.1 `dateBinding(for:)`.
    @MainActor
    public func dateBinding(for value: DynamicString) -> Binding<Date> {
        Binding<Date>(
            get: {
                let str = self.resolve(value)
                return Self._iso8601Formatter.date(from: str) ?? Date()
            },
            set: { newValue in
                guard case .dataBinding(let path) = value else { return }
                try? self.set(path, value: .string(Self._iso8601Formatter.string(from: newValue)))
            }
        )
    }

    // MARK: - Private

    // Shared ISO8601 formatter — nonisolated(unsafe) because ISO8601DateFormatter is not Sendable
    // but the formatter itself is safe to use from MainActor only (matches @MainActor methods above).
    private static nonisolated(unsafe) let _iso8601Formatter = ISO8601DateFormatter()
}
