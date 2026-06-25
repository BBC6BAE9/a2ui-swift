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


// MARK: - PathSlot

/// Each data path has its own observable box.
/// A SwiftUI view is bound only to the box it reads.
/// Equivalent to WebCore's per-path `Signal<T>`.
/// Internal — not exported. Callers outside the module use DataModel.get() / DataContext.
/// Mirrors WebCore's internal per-path Signal (not exported from data-model.ts).
@Observable
final class PathSlot {
    internal(set) var value: AnyCodable?

    /// Synchronous notification emitter — fired whenever the slot's value changes.
    /// Used by `DataContext.subscribeDynamicValue` to deliver reactive updates immediately.
    internal let onChange = EventEmitter<AnyCodable?>()

    init(_ value: AnyCodable?) {
        self.value = value
    }

    /// Updates value and fires synchronous subscribers.
    internal func update(_ newValue: AnyCodable?) {
        self.value = newValue
        onChange.emit(newValue)
    }
}

// MARK: - DataModel

/// A standalone, observable data store representing the client-side state.
/// Handles JSON Pointer path resolution (RFC 6901).
/// Mirrors the behavior of the TypeScript WebCore `DataModel`.
///
/// Provides two data access modes:
/// - `get(_:)` — reads the value directly without creating an observation dependency.
/// - `slot(for:)` — returns the PathSlot for a path; SwiftUI views read slot.value for fine-grained observation.
public final class DataModel {
    private var root: AnyCodable

    /// Equivalent to the TS `Map<string, Signal>`, created lazily.
    private var slots: [String: PathSlot] = [:]

    public init() {
        self.root = .dictionary([:])
    }

    public init(_ initialData: [String: AnyCodable]) {
        self.root = .dictionary(initialData)
    }

    // MARK: - PathSlot Access

    /// Returns the PathSlot for a path, creating it lazily.
    /// SwiftUI views should read data through this method to get fine-grained observation.
    /// Internal — consumers outside the module use DataContext.resolveDynamicValue().
    func slot(for path: String) -> PathSlot {
        let normalized = normalizePath(path)
        if let existing = slots[normalized] {
            return existing
        }
        let newSlot = PathSlot(get(normalized))
        slots[normalized] = newSlot
        return newSlot
    }

    /// Clears all PathSlots and disconnects all observations.
    public func dispose() {
        for slot in slots.values {
            slot.onChange.dispose()
        }
        slots.removeAll()
    }

    // MARK: - Get

    /// Retrieves data at a specific JSON Pointer path.
    /// Returns `nil` if the path does not exist.
    public func get(_ path: String) -> AnyCodable? {
        let normalized = normalizePath(path)
        if normalized == "/" || normalized.isEmpty {
            return root
        }
        let segments = parsePath(normalized)
        var current = root
        for segment in segments {
            switch current {
            case .dictionary(let dict):
                guard let next = dict[segment] else { return nil }
                current = next
            case .array(let arr):
                guard let index = Int(segment), index >= 0, index < arr.count else { return nil }
                current = arr[index]
            case .null:
                return nil
            default:
                return nil
            }
        }
        return current
    }

    // MARK: - Set

    /// Updates the model at the specific path.
    /// - If path is "/" or "", replaces the entire root.
    /// - If value is `nil`, removes the key from a dictionary (or sets array element to `.null`).
    /// - Auto-creates intermediate objects/arrays based on the next segment (numeric → array, otherwise → object).
    @discardableResult
    public func set(_ path: String, value: AnyCodable?) throws -> DataModel {
        let normalized = normalizePath(path)

        if normalized == "/" || normalized.isEmpty {
            root = value ?? .dictionary([:])
            notifyAllSlots()
            return self
        }

        let segments = parsePath(normalized)
        root = try setRecursive(
            in: root,
            segments: segments[...],
            value: value,
            fullPath: path
        )
        notifySlots(for: normalized)
        return self
    }

    // MARK: - Private Helpers

    private func normalizePath(_ path: String) -> String {
        if path == "/" || path.isEmpty { return path.isEmpty ? "/" : path }
        var result = path
        while result.count > 1 && result.hasSuffix("/") {
            result = String(result.dropLast())
        }
        return result
    }

    private func parsePath(_ path: String) -> [String] {
        path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    private func isNumeric(_ s: String) -> Bool {
        s.allSatisfy(\.isNumber)
    }

    // MARK: - Slot Notification

    /// After set(), updates the path's slot, all ancestor slots, and all descendant slots.
    /// Sibling paths, such as /user/age, are not affected.
    private func notifySlots(for path: String) {
        // 1. Self
        updateSlot(at: path)

        // 2. Ancestors: /user/name → /user → /
        var parent = path
        while parent != "/" {
            if let lastSlash = parent.lastIndex(of: "/") {
                parent = lastSlash == parent.startIndex ? "/" : String(parent[..<lastSlash])
            } else {
                parent = "/"
            }
            updateSlot(at: parent)
        }

        // 3. Descendants: iterate existing slots and match by prefix
        for slotPath in slots.keys where isDescendant(slotPath, of: path) {
            updateSlot(at: slotPath)
        }
    }

    /// When replacing the root, all slots must be updated.
    private func notifyAllSlots() {
        for path in slots.keys {
            updateSlot(at: path)
        }
    }

    /// Recomputes a slot's value from the current root.
    private func updateSlot(at path: String) {
        guard let slot = slots[path] else { return }
        slot.update(get(path))
    }

    private func isDescendant(_ child: String, of parent: String) -> Bool {
        if parent == "/" { return child != "/" }
        return child.hasPrefix(parent + "/")
    }

    /// Recursively descend into the container, replacing/creating nodes along the way.
    private func setRecursive(
        in container: AnyCodable,
        segments: ArraySlice<String>,
        value: AnyCodable?,
        fullPath: String
    ) throws -> AnyCodable {
        guard let segment = segments.first else {
            return value ?? .null
        }

        let rest = segments.dropFirst()

        if rest.isEmpty {
            // Last segment — apply the value
            return try setLeaf(in: container, segment: segment, value: value, fullPath: fullPath)
        }

        // Intermediate segment — recurse deeper
        let nextSegment = rest.first!
        return try setIntermediate(
            in: container, segment: segment, nextSegment: nextSegment,
            rest: rest, value: value, fullPath: fullPath
        )
    }

    /// Set the final leaf value in the container.
    private func setLeaf(
        in container: AnyCodable,
        segment: String,
        value: AnyCodable?,
        fullPath: String
    ) throws -> AnyCodable {
        switch container {
        case .dictionary(var dict):
            if let value = value {
                dict[segment] = value
            } else {
                dict.removeValue(forKey: segment)
            }
            return .dictionary(dict)

        case .array(var arr):
            guard let index = Int(segment) else {
                throw A2uiDataError("Cannot use non-numeric segment '\(segment)' on an array in path '\(fullPath)'.", path: fullPath)
            }
            while arr.count <= index {
                arr.append(.null)
            }
            arr[index] = value ?? .null
            return .array(arr)

        default:
            throw A2uiDataError("Cannot set path '\(fullPath)': segment '\(segment)' is a primitive value.", path: fullPath)
        }
    }

    /// Navigate through an intermediate segment, creating containers as needed.
    private func setIntermediate(
        in container: AnyCodable,
        segment: String,
        nextSegment: String,
        rest: ArraySlice<String>,
        value: AnyCodable?,
        fullPath: String
    ) throws -> AnyCodable {
        switch container {
        case .dictionary(var dict):
            let child = dict[segment]
            if let child = child {
                switch child {
                case .string, .number, .bool:
                    throw A2uiDataError("Cannot set path '\(fullPath)': segment '\(segment)' is a primitive value.", path: fullPath)
                case .null:
                    let newChild: AnyCodable = isNumeric(nextSegment) ? .array([]) : .dictionary([:])
                    dict[segment] = try setRecursive(in: newChild, segments: rest, value: value, fullPath: fullPath)
                default:
                    dict[segment] = try setRecursive(in: child, segments: rest, value: value, fullPath: fullPath)
                }
            } else {
                let newChild: AnyCodable = isNumeric(nextSegment) ? .array([]) : .dictionary([:])
                dict[segment] = try setRecursive(in: newChild, segments: rest, value: value, fullPath: fullPath)
            }
            return .dictionary(dict)

        case .array(var arr):
            guard let index = Int(segment) else {
                throw A2uiDataError("Cannot use non-numeric segment '\(segment)' on an array in path '\(fullPath)'.", path: fullPath)
            }
            while arr.count <= index {
                arr.append(.null)
            }
            let child = arr[index]
            switch child {
            case .string, .number, .bool:
                throw A2uiDataError("Cannot set path '\(fullPath)': segment '\(segment)' is a primitive value.", path: fullPath)
            case .null:
                let newChild: AnyCodable = isNumeric(nextSegment) ? .array([]) : .dictionary([:])
                arr[index] = try setRecursive(in: newChild, segments: rest, value: value, fullPath: fullPath)
            default:
                arr[index] = try setRecursive(in: child, segments: rest, value: value, fullPath: fullPath)
            }
            return .array(arr)

        default:
            throw A2uiDataError("Cannot set path '\(fullPath)': segment '\(segment)' is a primitive value.", path: fullPath)
        }
    }
}
