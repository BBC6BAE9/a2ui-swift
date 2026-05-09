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

import _FoundationICU

/// ICU-backed plural selection; mirrors `Intl.PluralRules(locale).select(n)`.
struct A2UIPluralRules {
    private var localeIdentifier: String

    init(localeIdentifier: String) {
        self.localeIdentifier = localeIdentifier
    }

    func select(_ number: Double) -> String {
        localeIdentifier.withCString { cLocale in
            var status = U_ZERO_ERROR
            guard let rules = uplrules_openForType(cLocale, UPLURAL_TYPE_CARDINAL, &status),
                  status == U_ZERO_ERROR
            else {
                return nil
            }
            defer { uplrules_close(rules) }

            var buffer = [UInt16](repeating: 0, count: 32)
            status = U_ZERO_ERROR
            let length = uplrules_select(rules, number, &buffer, Int32(buffer.count), &status)
            guard status == U_ZERO_ERROR, length > 0, Int(length) < buffer.count else {
                return nil
            }
            return String(utf16CodeUnits: buffer, count: Int(length))
        } ?? "other"
    }
}
