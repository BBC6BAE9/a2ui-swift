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

// MARK: - ObservableValue_V08 (Fine-grained Data Model)

/// A single observable slot in the data model.
///
/// Each top-level key in `DataStore_V08.storage` is wrapped in its own
/// `ObservableValue_V08`. When a View reads `observableValue.value`, SwiftUI's
/// `@Observable` tracking registers a dependency on **this specific slot**
/// — not the entire data model dictionary. This means updating key "A"
/// will only invalidate Views that read key "A", leaving Views that read
/// key "B" untouched.
@Observable
public final class ObservableValue_V08 {
    public var value: AnyCodable

    public init(_ value: AnyCodable) {
        self.value = value
    }
}

// MARK: - DataStore_V08

/// Observable data store for a single A2UI surface.
/// Analogous to the data model management in web_core's A2uiMessageProcessor.
///
/// Owns the `[String: ObservableValue_V08]` dictionary and all path resolution,
/// read, and write logic. `SurfaceViewModel_V08` delegates data operations here.
@Observable
public final class DataStore_V08 {
    /// Fine-grained observable data store. Each top-level key is wrapped in
    /// its own `ObservableValue_V08` so that mutations to one key do not
    /// invalidate Views that only read a different key.
    private var storage: [String: ObservableValue_V08] = [:]

    public init() {}

    // MARK: - Bulk Accessors

    /// Backward-compatible computed accessor that materialises the data model
    /// as a plain dictionary. Useful for tests and bulk inspection.
    /// **Writing** through this setter replaces the entire store (all keys
    /// are touched), so prefer `setData(path:value:)` for targeted updates.
    public var dataModel: [String: AnyCodable] {
        get {
            storage.mapValues { $0.value }
        }
        set {
            // Build a new store, reusing existing ObservableValue_V08 objects
            // for keys whose value hasn't changed.
            var updated: [String: ObservableValue_V08] = [:]
            for (key, value) in newValue {
                if let existing = storage[key] {
                    existing.value = value
                    updated[key] = existing
                } else {
                    updated[key] = ObservableValue_V08(value)
                }
            }
            storage = updated
        }
    }

    /// All top-level keys currently in the data store (for debugging).
    public var dataStoreKeys: [String] {
        Array(storage.keys).sorted()
    }

    /// Remove all entries (used by `handleDeleteSurface`).
    public func removeAll() {
        storage.removeAll()
    }

    // MARK: - Path Resolution

    /// Normalize bracket/dot notation to slash-delimited paths.
    /// `bookRecommendations[0].title` → `bookRecommendations/0/title`
    /// `book.0.title` → `book/0/title`
    /// `/items[0]/title` → `/items/0/title`
    public func normalizePath(_ path: String) -> String {
        if path == "." || path == "/" { return path }
        guard path.contains("[") || path.contains(".") else { return path }

        // Replace bracket notation [N] with .N
        let dotPath = path.replacingOccurrences(
            of: "\\[(\\d+)\\]", with: ".$1", options: .regularExpression
        )

        // Split by dots, then split each segment by slashes to flatten
        let segments = dotPath
            .split(separator: ".")
            .flatMap { $0.split(separator: "/") }
            .map(String.init)
        guard !segments.isEmpty else { return path }

        let joined = segments.joined(separator: "/")
        return path.hasPrefix("/") ? "/\(joined)" : joined
    }

    /// Resolve a relative path against a data context path into an absolute path.
    public func resolvePath(_ path: String, context: String) -> String {
        let normalized = normalizePath(path)
        if normalized == "." || normalized.isEmpty { return context }
        if normalized.hasPrefix("/") { return normalized }
        if context == "/" { return "/\(normalized)" }
        let base = context.hasSuffix("/") ? context : "\(context)/"
        return "\(base)\(normalized)"
    }

    // MARK: - Data Read

    /// Traverse the data model by a slash-delimited path.
    /// Supports: `/name`, `/items/0/title`, `/items/item1/name`, etc.
    ///
    /// The first segment is resolved against `storage`, so SwiftUI only
    /// tracks the specific `ObservableValue_V08` for that top-level key.
    public func getDataByPath(_ path: String) -> AnyCodable? {
        let normalized = normalizePath(path)
        let segments = normalized.split(separator: "/").map(String.init)
        guard let firstKey = segments.first else { return nil }

        // Read from the per-key ObservableValue_V08 — this is the observation
        // boundary. SwiftUI will only track THIS slot, not the whole store.
        guard let slot = storage[firstKey] else { return nil }
        let current: AnyCodable = slot.value

        return DataStoreUtils.traverseSegments(segments.dropFirst(), in: current)
    }

    // MARK: - Data Write

    /// Write a value into the data model at a given path (for input components).
    public func setData(path: String, value: AnyCodable, dataContextPath: String = "/") {
        let fullPath = resolvePath(path, context: dataContextPath)
        let segments = fullPath.split(separator: "/").map(String.init)
        guard !segments.isEmpty else { return }

        if segments.count == 1 {
            setTopLevelData(key: segments[0], value: value)
            return
        }
        setNestedValue(path: fullPath, value: value)
    }

    // MARK: - Array Data Helpers (MultipleChoice)

    /// Resolve a `StringListValue_V08` to an array of selected value strings.
    /// When both `path` and a literal array are present, the literal seeds the data model once.
    public func resolveStringArray(
        _ selections: StringListValue_V08,
        dataContextPath: String = "/"
    ) -> [String] {
        if let path = selections.path {
            let full = resolvePath(path, context: dataContextPath)
            if let literal = selections.literalArray, getDataByPath(full) == nil {
                let arr: AnyCodable = .array(literal.map { .string($0) })
                setData(path: path, value: arr, dataContextPath: dataContextPath)
            }
            if case .array(let items) = getDataByPath(full) {
                return items.compactMap(\.stringValue)
            }
        }
        if let arr = selections.literalArray { return arr }
        return []
    }

    /// Write an array of strings into the data model at the given path.
    public func setStringArray(
        path: String, values: [String],
        dataContextPath: String = "/"
    ) {
        let arr: AnyCodable = .array(values.map { .string($0) })
        setData(path: path, value: arr, dataContextPath: dataContextPath)
    }

    // MARK: - Top-level Data Write

    /// Write a value to a top-level key in the data store, reusing an
    /// existing `ObservableValue_V08` when the key already exists so that only
    /// Views observing this specific key are invalidated.
    private func setTopLevelData(key: String, value: AnyCodable) {
        if let existing = storage[key] {
            existing.value = value
        } else {
            storage[key] = ObservableValue_V08(value)
        }
    }

    // MARK: - Nested Path Write

    private func setNestedValue(path: String, value: AnyCodable) {
        let segments = path.split(separator: "/").map(String.init)
        guard let topKey = segments.first else { return }

        let existingTop = storage[topKey]?.value ?? .dictionary([:])
        if segments.count == 1 {
            setTopLevelData(key: topKey, value: value)
            return
        }

        let rest = segments.dropFirst()
        let updated = DataStoreUtils.setValue(value, in: existingTop, along: rest)
        setTopLevelData(key: topKey, value: updated)
    }

}
