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

import A2UISwiftCore
import Foundation
import Testing

@testable import A2UISwiftUI

// Spec coverage: basic_catalog.json:548-553
//   variant ∈ ["longText", "number", "shortText", "obscured"]  (default "shortText")
//
// Note: v0.9 spec **dropped** the v0.8 `date` variant — use the dedicated
// `DateTimeInput` component for date/time input. Reference renderers confirm:
//   - React TextField.tsx:29-31 — only handles longText / number / obscured
//   - Lit TextField.ts:86-88, 94-105 — only handles longText / number / obscured
//   - Angular text-field.component.ts:106-115 — only handles obscured / number
//   - Flutter text_field.dart:148-153 — only handles obscured / number / longText
// None of them handles `date`.

// MARK: - T1: TextFieldVariant decoding

@Suite("TextFieldVariant decoding")
struct TextFieldVariantDecodingTests {

    private func decode(_ json: String) throws -> TextFieldProperties {
        try JSONDecoder().decode(
            TextFieldProperties.self,
            from: json.data(using: .utf8)!
        )
    }

    @Test("decodes 'shortText'")
    func decodesShortText() throws {
        let props = try decode(#"{"value": "x", "variant": "shortText"}"#)
        #expect(props.variant == .shortText)
    }

    @Test("decodes 'longText'")
    func decodesLongText() throws {
        let props = try decode(#"{"value": "x", "variant": "longText"}"#)
        #expect(props.variant == .longText)
    }

    @Test("decodes 'number'")
    func decodesNumber() throws {
        let props = try decode(#"{"value": "x", "variant": "number"}"#)
        #expect(props.variant == .number)
    }

    @Test("decodes 'obscured'")
    func decodesObscured() throws {
        let props = try decode(#"{"value": "x", "variant": "obscured"}"#)
        #expect(props.variant == .obscured)
    }

    @Test("variant is nil when absent (renderer applies spec default behavior)")
    func variantNilWhenAbsent() throws {
        let props = try decode(#"{"value": "x"}"#)
        #expect(props.variant == nil)
    }

    @Test("'date' (v0.8 leftover) decodes to .unknown for forward-compat")
    func dateDecodesToUnknown() throws {
        // v0.9 spec dropped 'date' from TextField. Non-spec servers sending it
        // should not crash decode — the value lands in .unknown(_) and the View
        // falls through to the default plain-TextField branch (matching what all
        // 4 v0.9 reference renderers do for unrecognized variants).
        let props = try decode(#"{"value": "x", "variant": "date"}"#)
        #expect(props.variant == .unknown("date"))
    }

    @Test("future variants decode to .unknown for forward-compat")
    func futureVariantDecodesToUnknown() throws {
        let props = try decode(#"{"value": "x", "variant": "futureMode"}"#)
        #expect(props.variant == .unknown("futureMode"))
    }
}
