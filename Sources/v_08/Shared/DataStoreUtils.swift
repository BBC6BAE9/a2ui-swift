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

/// Shared pure-algorithm helpers used by `DataStore_V08`.
/// These operate only on `AnyCodable` and have no version-specific dependencies.
enum DataStoreUtils {

    // MARK: - Recursive Nested Value Setter

    /// Recursively descend into `container` along `segments`, replacing the
    /// leaf with `value`. Creates intermediate dictionaries or arrays as needed.
    static func setValue(
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

    // MARK: - Path Traversal

    /// Walk a sequence of path segments through a nested `AnyCodable` value,
    /// descending into dictionaries by key and arrays by integer index.
    /// Returns `nil` if any segment cannot be resolved.
    static func traverseSegments(
        _ segments: some Collection<String>,
        in root: AnyCodable
    ) -> AnyCodable? {
        var current = root
        for segment in segments {
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
}
