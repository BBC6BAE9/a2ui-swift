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

// MARK: - ObservableValue (Fine-grained Data Model)

/// A single observable slot in the data model.
///
/// Each top-level key in `DataStore.storage` is wrapped in its own
/// `ObservableValue`. When a View reads `observableValue.value`, SwiftUI's
/// `@Observable` tracking registers a dependency on **this specific slot**
/// — not the entire data model dictionary. This means updating key "A"
/// will only invalidate Views that read key "A", leaving Views that read
/// key "B" untouched.
@Observable
public final class ObservableValue {
    public var value: AnyCodable

    public init(_ value: AnyCodable) {
        self.value = value
    }
}

// MARK: - DataStore

/// Observable data store for a single A2UI surface.
/// Analogous to the data model management in web_core's A2uiMessageProcessor.
///
/// Owns the `[String: ObservableValue]` dictionary and all path resolution,
/// read, and write logic. `SurfaceViewModel` delegates data operations here.
@Observable
public final class DataStore {
    /// Fine-grained observable data store. Each top-level key is wrapped in
    /// its own `ObservableValue` so that mutations to one key do not
    /// invalidate Views that only read a different key.
    private var storage: [String: ObservableValue] = [:]

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
            // Build a new store, reusing existing ObservableValue objects
            // for keys whose value hasn't changed.
            var updated: [String: ObservableValue] = [:]
            for (key, value) in newValue {
                if let existing = storage[key] {
                    existing.value = value
                    updated[key] = existing
                } else {
                    updated[key] = ObservableValue(value)
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
    /// tracks the specific `ObservableValue` for that top-level key.
    public func getDataByPath(_ path: String) -> AnyCodable? {
        let normalized = normalizePath(path)
        let segments = normalized.split(separator: "/").map(String.init)
        guard let firstKey = segments.first else { return nil }

        // Read from the per-key ObservableValue — this is the observation
        // boundary. SwiftUI will only track THIS slot, not the whole store.
        guard let slot = storage[firstKey] else { return nil }
        var current: AnyCodable = slot.value

        for segment in segments.dropFirst() {
            switch current {
            case .dictionary(let dict):
                guard let next = dict[segment] else { return nil }
                current = next
            case .array(let arr):
                guard let index = Int(segment), index >= 0, index < arr.count else { return nil }
                current = arr[index]
            default:
                return nil
            }
        }
        return current
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

    /// Resolve a `StringListValue` to an array of selected value strings.
    /// When both `path` and a literal array are present, the literal seeds the data model once.
    public func resolveStringArray(
        _ selections: StringListValue,
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
    /// existing `ObservableValue` when the key already exists so that only
    /// Views observing this specific key are invalidated.
    private func setTopLevelData(key: String, value: AnyCodable) {
        if let existing = storage[key] {
            existing.value = value
        } else {
            storage[key] = ObservableValue(value)
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
        let updated = Self.setValue(value, in: existingTop, along: rest)
        setTopLevelData(key: topKey, value: updated)
    }

    private static func setValue(
        _ value: AnyCodable,
        in container: AnyCodable,
        along segments: ArraySlice<String>
    ) -> AnyCodable {
        guard let key = segments.first else { return value }
        let rest = segments.dropFirst()

        if let index = Int(key) {
            // Numeric key → array container
            var arr: [AnyCodable]
            if case .array(let existing) = container {
                arr = existing
            } else {
                arr = []
            }
            // Extend array if needed
            while arr.count <= index {
                arr.append(.dictionary([:]))
            }
            let nextDefault: AnyCodable = {
                guard let nextKey = rest.first else { return value }
                return Int(nextKey) != nil ? .array([]) : .dictionary([:])
            }()
            let child: AnyCodable
            if rest.isEmpty {
                child = arr[index]
            } else if case .dictionary(let d) = arr[index], d.isEmpty {
                child = nextDefault
            } else {
                child = arr[index]
            }
            arr[index] = rest.isEmpty ? value : setValue(value, in: child, along: rest)
            return .array(arr)
        }

        switch container {
        case .dictionary(var dict):
            let nextDefault: AnyCodable = {
                guard let nextKey = rest.first else { return value }
                return Int(nextKey) != nil ? .array([]) : .dictionary([:])
            }()
            let child = dict[key] ?? nextDefault
            dict[key] = rest.isEmpty ? value : setValue(value, in: child, along: rest)
            return .dictionary(dict)
        case .array(var arr):
            guard let index = Int(key), index >= 0, index < arr.count else { return container }
            arr[index] = rest.isEmpty ? value : setValue(value, in: arr[index], along: rest)
            return .array(arr)
        default:
            // Container is a leaf value but we need to go deeper — create dict
            var dict: [String: AnyCodable] = [:]
            let nextDefault: AnyCodable = {
                guard let nextKey = rest.first else { return value }
                return Int(nextKey) != nil ? .array([]) : .dictionary([:])
            }()
            dict[key] = rest.isEmpty ? value : setValue(value, in: nextDefault, along: rest)
            return .dictionary(dict)
        }
    }
}
