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
import Foundation
import A2UISwiftCore

// MARK: - Validation
//
// Mirrors SwiftUI's input validation: `checks` errors take precedence over the
// regexp format check (whole-string match). Returns the message to display, or
// nil if valid.

func a2ui_validationMessage(
    checks: [CheckRule]?,
    value: String,
    regexp: String?,
    dataContext: DataContext
) -> String? {
    if let checksMessage = dataContext.firstFailingCheckMessage(checks) {
        return checksMessage
    }
    return a2ui_regexpMessage(value: value, pattern: regexp)
}

func a2ui_regexpMessage(value: String, pattern: String?) -> String? {
    guard let pattern, !pattern.isEmpty, !value.isEmpty else { return nil }
    let matched = (try? Regex(pattern).wholeMatch(in: value)) != nil
    return matched ? nil : "Invalid format"
}

#endif
