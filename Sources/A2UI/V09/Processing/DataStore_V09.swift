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

// MARK: - ObservableValue_V09

@Observable
public final class ObservableValue_V09 {
    public var value: AnyCodable

    public init(_ value: AnyCodable) {
        self.value = value
    }
}

// MARK: - DataStore_V09

/// Observable data store for a single v0.9 A2UI surface.
/// Uses native JSON Pointer paths (RFC 6901) — no bracket/dot normalization needed.
@Observable
public final class DataStore_V09 {
    private var storage: [String: ObservableValue_V09] = [:]

    public init() {}

    // MARK: - Bulk Accessors

    public var dataModel: [String: AnyCodable] {
        get { storage.mapValues { $0.value } }
        set {
            var updated: [String: ObservableValue_V09] = [:]
            for (key, value) in newValue {
                if let existing = storage[key] {
                    existing.value = value
                    updated[key] = existing
                } else {
                    updated[key] = ObservableValue_V09(value)
                }
            }
            storage = updated
        }
    }

    public var dataStoreKeys: [String] {
        Array(storage.keys).sorted()
    }

    public func removeAll() {
        storage.removeAll()
    }

    // MARK: - Path Resolution (JSON Pointer)

    /// v0.9 paths are already JSON Pointers — just normalize trailing slashes.
    public func normalizePath(_ path: String) -> String {
        if path == "/" || path.isEmpty { return path }
        // Remove trailing slash
        var result = path
        while result.count > 1 && result.hasSuffix("/") {
            result = String(result.dropLast())
        }
        return result
    }

    /// Resolve a path against a data context. v0.9 uses JSON Pointer (RFC 6901).
    /// Absolute paths start with `/`, relative paths are appended to context.
    public func resolvePath(_ path: String, context: String) -> String {
        let normalized = normalizePath(path)
        if normalized.isEmpty { return context }
        if normalized.hasPrefix("/") { return normalized }
        if context == "/" { return "/\(normalized)" }
        let base = context.hasSuffix("/") ? context : "\(context)/"
        return "\(base)\(normalized)"
    }

    // MARK: - Data Read

    public func getDataByPath(_ path: String) -> AnyCodable? {
        let normalized = normalizePath(path)
        let segments = normalized.split(separator: "/").map(String.init)
        guard let firstKey = segments.first else {
            // Root path "/" — return entire data model as dictionary
            if normalized == "/" || normalized.isEmpty {
                return .dictionary(dataModel)
            }
            return nil
        }

        guard let slot = storage[firstKey] else { return nil }
        let current: AnyCodable = slot.value

        return DataStoreUtils.traverseSegments(segments.dropFirst(), in: current)
    }

    // MARK: - Data Write

    /// v0.9 updateDataModel: set value at a JSON Pointer path.
    /// If path is nil or "/", replaces entire data model.
    public func handleUpdateDataModel(path: String?, value: AnyCodable?) {
        let resolvedPath = path ?? "/"

        if resolvedPath == "/" || resolvedPath.isEmpty {
            // Replace entire data model
            if case .dictionary(let dict) = value {
                for (key, val) in dict {
                    setTopLevelData(key: key, value: val)
                }
            } else if let val = value {
                // Shouldn't happen per spec, but handle gracefully
                setTopLevelData(key: "_root", value: val)
            }
            // If value is nil, clear (delete) the data model
            if value == nil {
                removeAll()
            }
            return
        }

        if let val = value {
            setData(path: resolvedPath, value: val)
        } else {
            // value omitted means delete at path
            deleteData(path: resolvedPath)
        }
    }

    /// Write a value at a JSON Pointer path.
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

    /// Delete a value at a JSON Pointer path.
    public func deleteData(path: String) {
        let segments = path.split(separator: "/").map(String.init)
        guard !segments.isEmpty else { return }

        if segments.count == 1 {
            storage.removeValue(forKey: segments[0])
            return
        }

        // For nested deletions, set to null
        setNestedValue(path: path, value: .null)
    }

    // MARK: - Array Data Helpers

    /// Resolve a `DynamicStringList_V09` to an array of strings.
    public func resolveStringList(
        _ value: DynamicStringList_V09,
        dataContextPath: String = "/"
    ) -> [String] {
        switch value {
        case .literal(let arr):
            return arr
        case .dataBinding(let path):
            let fullPath = resolvePath(path, context: dataContextPath)
            if case .array(let items) = getDataByPath(fullPath) {
                return items.compactMap(\.stringValue)
            }
            return []
        case .functionCall:
            // Function calls not yet implemented
            return []
        }
    }

    /// Write an array of strings at a path.
    public func setStringArray(
        path: String, values: [String],
        dataContextPath: String = "/"
    ) {
        let arr: AnyCodable = .array(values.map { .string($0) })
        setData(path: path, value: arr, dataContextPath: dataContextPath)
    }

    // MARK: - Private

    private func setTopLevelData(key: String, value: AnyCodable) {
        if let existing = storage[key] {
            existing.value = value
        } else {
            storage[key] = ObservableValue_V09(value)
        }
    }

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
