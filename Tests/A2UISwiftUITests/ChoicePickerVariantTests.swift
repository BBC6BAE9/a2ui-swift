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

// Spec coverage: basic_catalog.json:619-624
//   variant: "multipleSelection" | "mutuallyExclusive"  (default "mutuallyExclusive")
//
// Cross-renderer behavior consensus (Lit ChoicePicker.ts:113-127,
// React ChoicePicker.tsx:33-44, Angular choice-picker.component.ts:157-172,
// Flutter choice_picker.dart:340-360):
//   - mutuallyExclusive → setValue([val]) always; tapping the same selected
//     option re-emits [val] (radio semantics, no toggle-off).
//   - multipleSelection → standard add/remove toggle.
//   - Default (variant absent) → mutuallyExclusive (Zod default in WebCore-derived
//     renderers; explicitly applied in Swift renderer because schema validation
//     was removed from the SDK).

// MARK: - T1: ChoicePickerProperties.variant decoding

@Suite("ChoicePickerProperties.variant decoding")
struct ChoicePickerVariantDecodingTests {

    private func decode(_ json: String) throws -> ChoicePickerProperties {
        try JSONDecoder().decode(
            ChoicePickerProperties.self,
            from: json.data(using: .utf8)!
        )
    }

    @Test("decodes 'mutuallyExclusive'")
    func decodesMutuallyExclusive() throws {
        let props = try decode(#"""
        {
          "options": [{"label": "A", "value": "a"}],
          "variant": "mutuallyExclusive"
        }
        """#)
        #expect(props.variant == .mutuallyExclusive)
    }

    @Test("decodes 'multipleSelection'")
    func decodesMultipleSelection() throws {
        let props = try decode(#"""
        {
          "options": [{"label": "A", "value": "a"}],
          "variant": "multipleSelection"
        }
        """#)
        #expect(props.variant == .multipleSelection)
    }

    @Test("variant is nil when absent (renderer applies spec default)")
    func variantNilWhenAbsent() throws {
        let props = try decode(#"""
        {"options": [{"label": "A", "value": "a"}]}
        """#)
        #expect(props.variant == nil)
    }

    @Test("unknown values decode to .unknown for forward-compat")
    func unknownDecodes() throws {
        let props = try decode(#"""
        {
          "options": [{"label": "A", "value": "a"}],
          "variant": "futureMode"
        }
        """#)
        #expect(props.variant == .unknown("futureMode"))
    }
}

// MARK: - T2: selectionAfterTap — variant-aware selection logic

@Suite("MultipleChoiceLogic.selectionAfterTap")
struct ChoicePickerSelectionLogicTests {

    // MARK: mutuallyExclusive (radio semantics)

    @Test("mutuallyExclusive: empty → tapping yields [val]")
    func mexFromEmpty() {
        let result = MultipleChoiceLogic.selectionAfterTap(
            value: "a", in: [], isMutuallyExclusive: true
        )
        #expect(result == ["a"])
    }

    @Test("mutuallyExclusive: tapping different option REPLACES selection")
    func mexReplaces() {
        let result = MultipleChoiceLogic.selectionAfterTap(
            value: "b", in: ["a"], isMutuallyExclusive: true
        )
        #expect(result == ["b"])
    }

    @Test("mutuallyExclusive: tapping the same selected option is idempotent (no toggle-off)")
    func mexNoToggleOff() {
        // Spec/reference behavior: radio semantics — tapping the already-selected
        // option must NOT clear the selection. Output stays [val].
        let result = MultipleChoiceLogic.selectionAfterTap(
            value: "a", in: ["a"], isMutuallyExclusive: true
        )
        #expect(result == ["a"])
    }

    @Test("mutuallyExclusive: even with stale multi-selection, tapping collapses to [val]")
    func mexCollapsesMulti() {
        // If a server toggles variant from multipleSelection to mutuallyExclusive
        // mid-session, the next tap should collapse the selection to a single value.
        let result = MultipleChoiceLogic.selectionAfterTap(
            value: "c", in: ["a", "b"], isMutuallyExclusive: true
        )
        #expect(result == ["c"])
    }

    // MARK: multipleSelection (toggle in/out)

    @Test("multipleSelection: empty → adds value")
    func multiAddsToEmpty() {
        let result = MultipleChoiceLogic.selectionAfterTap(
            value: "a", in: [], isMutuallyExclusive: false
        )
        #expect(result == ["a"])
    }

    @Test("multipleSelection: tapping unselected APPENDS to existing selection")
    func multiAppends() {
        let result = MultipleChoiceLogic.selectionAfterTap(
            value: "b", in: ["a"], isMutuallyExclusive: false
        )
        #expect(result == ["a", "b"])
    }

    @Test("multipleSelection: tapping selected REMOVES from selection (toggle-off)")
    func multiRemoves() {
        let result = MultipleChoiceLogic.selectionAfterTap(
            value: "a", in: ["a", "b"], isMutuallyExclusive: false
        )
        #expect(result == ["b"])
    }

    @Test("multipleSelection: removing the only selection yields empty")
    func multiRemovesLast() {
        let result = MultipleChoiceLogic.selectionAfterTap(
            value: "a", in: ["a"], isMutuallyExclusive: false
        )
        #expect(result == [])
    }
}
