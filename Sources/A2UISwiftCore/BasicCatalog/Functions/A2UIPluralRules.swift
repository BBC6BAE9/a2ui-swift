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

/// Cardinal plural selection using the operating system's ICU/CLDR rules.
/// Rule versions and numeric boundaries follow Foundation, not a pinned Intl release.
struct A2UIPluralRules {
    private static let categoryTemplate = Bundle.module.localizedString(
        forKey: "category", value: nil, table: "PluralCategories")
    private let locale: Locale

    init(localeIdentifier: String) {
        locale = Locale(identifier: localeIdentifier)
    }

    func select(_ number: Double) -> String {
        guard number.isFinite else { return "other" }
        return String(
            format: Self.categoryTemplate, locale: locale, arguments: [abs(number)])
    }
}
