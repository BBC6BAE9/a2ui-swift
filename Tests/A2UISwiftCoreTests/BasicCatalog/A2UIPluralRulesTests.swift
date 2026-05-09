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

@testable import A2UISwiftCore
import Testing

/// Golden values from Node: `new Intl.PluralRules(locale).select(n)` (V8 `Intl`).
/// Regenerate when intentionally upgrading ICU/CLDR expectations.

@Suite("A2UIPluralRules")
struct A2UIPluralRulesTests {

    @Test(
        "cardinal keyword matches Intl.PluralRules(locale).select",
        arguments: [
            // MARK: en-US (WebCore `pluralize` default)

            ("en-US", 0.0, "other"),
            ("en-US", 1.0, "one"),
            ("en-US", 2.0, "other"),
            ("en-US", -1.0, "one"),
            ("en-US", -2.0, "other"),
            ("en-US", 1.5, "other"),
            ("en-US", -1.5, "other"),
            ("en-US", 1.0000000000000002, "one"),
            ("en-US", 42.0, "other"),
            ("en-US", 0.5, "other"),

            // MARK: pl — few / many

            ("pl", 0.0, "many"),
            ("pl", 1.0, "one"),
            ("pl", 2.0, "few"),
            ("pl", 3.0, "few"),
            ("pl", 4.0, "few"),
            ("pl", 5.0, "many"),
            ("pl", 10.0, "many"),
            ("pl", 11.0, "many"),
            ("pl", 12.0, "many"),
            ("pl", 21.0, "many"),
            ("pl", 22.0, "few"),
            ("pl", 23.0, "few"),
            ("pl", 24.0, "few"),
            ("pl", 25.0, "many"),
            ("pl", 27.0, "many"),
            ("pl", 29.0, "many"),
            ("pl", 30.0, "many"),
            ("pl", 31.0, "many"),
            ("pl", 32.0, "few"),
            ("pl", 33.0, "few"),
            ("pl", 34.0, "few"),
            ("pl", 35.0, "many"),
            ("pl", 100.0, "many"),
            ("pl", 101.0, "many"),
            ("pl", 102.0, "few"),
            ("pl", 103.0, "few"),
            ("pl", 104.0, "few"),
            ("pl", 105.0, "many"),
            ("pl", 112.0, "many"),
            ("pl", 122.0, "few"),
            ("pl", 0.5, "other"),
            ("pl", 1.5, "other"),

            // MARK: ar — zero / two / few / many

            ("ar", 0.0, "zero"),
            ("ar", 1.0, "one"),
            ("ar", 2.0, "two"),
            ("ar", 3.0, "few"),
            ("ar", 4.0, "few"),
            ("ar", 5.0, "few"),
            ("ar", 10.0, "few"),
            ("ar", 11.0, "many"),
            ("ar", 102.0, "other"),
            ("ar", 103.0, "few"),
            ("ar", 104.0, "few"),
            ("ar", 105.0, "few"),
            ("ar", 106.0, "few"),
            ("ar", 107.0, "few"),
            ("ar", 108.0, "few"),
            ("ar", 109.0, "few"),
            ("ar", 110.0, "few"),
            ("ar", 111.0, "many"),
            ("ar", 112.0, "many"),
            ("ar", 0.5, "other"),

            // MARK: lv — zero vs one vs other

            ("lv", 0.0, "zero"),
            ("lv", 1.0, "one"),
            ("lv", 21.0, "one"),
            ("lv", 22.0, "other"),
            ("lv", 29.0, "other"),
            ("lv", 30.0, "zero"),
            ("lv", 31.0, "one"),
            ("lv", 40.0, "zero"),
            ("lv", 41.0, "one"),
            ("lv", 0.5, "other"),

            // MARK: de

            ("de", 0.0, "other"),
            ("de", 1.0, "one"),
            ("de", 2.0, "other"),
            ("de", 1.5, "other"),
            ("de", 0.5, "other"),

            // MARK: zh-CN — no separate one-form

            ("zh-CN", 0.0, "other"),
            ("zh-CN", 1.0, "other"),
            ("zh-CN", 2.0, "other"),
            ("zh-CN", 100.0, "other"),
            ("zh-CN", 0.5, "other"),

            // MARK: ru — one / few / many

            ("ru", 0.0, "many"),
            ("ru", 1.0, "one"),
            ("ru", 2.0, "few"),
            ("ru", 3.0, "few"),
            ("ru", 4.0, "few"),
            ("ru", 5.0, "many"),
            ("ru", 11.0, "many"),
            ("ru", 12.0, "many"),
            ("ru", 13.0, "many"),
            ("ru", 14.0, "many"),
            ("ru", 15.0, "many"),
            ("ru", 19.0, "many"),
            ("ru", 20.0, "many"),
            ("ru", 21.0, "one"),
            ("ru", 22.0, "few"),
            ("ru", 23.0, "few"),
            ("ru", 24.0, "few"),
            ("ru", 25.0, "many"),
            ("ru", 26.0, "many"),
            ("ru", 27.0, "many"),
            ("ru", 28.0, "many"),
            ("ru", 29.0, "many"),
            ("ru", 30.0, "many"),
            ("ru", 31.0, "one"),
            ("ru", 32.0, "few"),
            ("ru", 33.0, "few"),
            ("ru", 34.0, "few"),
            ("ru", 35.0, "many"),
            ("ru", 36.0, "many"),
            ("ru", 37.0, "many"),
            ("ru", 38.0, "many"),
            ("ru", 39.0, "many"),
            ("ru", 40.0, "many"),
            ("ru", 41.0, "one"),
            ("ru", 42.0, "few"),
        ]
    )
    func intlParity(locale: String, number: Double, want: String) {
        let got = A2UIPluralRules(localeIdentifier: locale).select(number)
        #expect(got == want)
    }

    @Test(
        "NaN and non-finite → other (Intl), multiple locales",
        arguments: ["en-US", "pl", "ar", "lv", "de", "zh-CN", "ru"]
    )
    func nonFiniteIsOther(locale: String) {
        let rules = A2UIPluralRules(localeIdentifier: locale)
        #expect(rules.select(Double.nan) == "other")
        #expect(rules.select(Double.infinity) == "other")
        #expect(rules.select(-Double.infinity) == "other")
    }
}
