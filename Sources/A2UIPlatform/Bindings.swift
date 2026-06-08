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

#if (canImport(UIKit) && !os(watchOS)) || canImport(AppKit)
import A2UISwiftCore

// MARK: - Two-way binding helpers
//
// Input components write the user's edits back to the bound data path. Only
// `.dataBinding` values are writable (literals have nowhere to write); this
// extracts the path so the component can call `DataContext.set`.

func a2ui_bindingPath<T>(_ value: Dynamic<T>?) -> String? {
    guard let value, case .dataBinding(let path) = value else { return nil }
    return path
}

extension DataContext {
    /// Writes a value back to a bound path, ignoring literals (nothing to write).
    func writeBack<T>(_ value: Dynamic<T>?, _ codable: AnyCodable) {
        guard let path = a2ui_bindingPath(value) else { return }
        try? set(path, value: codable)
    }
}

#endif
