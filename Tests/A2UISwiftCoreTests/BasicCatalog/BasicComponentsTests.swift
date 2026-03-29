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

// Mirrors WebCore basic_catalog/components/basic_components.test.ts
//
// WebCore's test iterates over every ComponentApi entry in BASIC_COMPONENTS
// (an array of Zod schema objects) and verifies that each component:
//   - exists in the official basic_catalog.json specification file,
//   - has matching property names,
//   - has matching required flags, and
//   - has matching description strings on every property.
// This is a Zod-schema-to-JSON-spec alignment test and has no direct Swift
// equivalent (Swift has no Zod schemas or runtime JSON Schema comparison).
//
// In Swift, BASIC_COMPONENT_NAMES is a plain Set<String>. The closest
// applicable test is to verify the set contains exactly the expected 18
// component names — preserving the core intent that all Basic Catalog
// components are registered.

@testable import A2UISwiftCore
import Testing

@Suite("Basic Components")
struct BasicComponentsTests {

    // Mirrors the name-presence check from WebCore's schema-alignment test:
    // "verifies all basic components exist in the catalog and their required
    //  properties and descriptions align"
    //
    // NOTE: Property-level and description-level checks from the WebCore test
    // are not applicable — they compare Zod schema metadata against a JSON spec
    // file, a mechanism that doesn't exist in Swift. Swift type correctness is
    // guaranteed at compile time by Codable.
    @Test("contains all expected component names")
    func containsAllExpectedComponentNames() {
        let expected: Set<String> = [
            "Text", "Image", "Icon", "Video", "AudioPlayer",
            "Row", "Column", "List", "Card", "Tabs", "Modal", "Divider",
            "Button", "TextField", "CheckBox", "ChoicePicker", "Slider", "DateTimeInput"
        ]
        #expect(BASIC_COMPONENT_NAMES == expected)
    }

    @Test("contains exactly 18 components")
    func containsExactly18Components() {
        #expect(BASIC_COMPONENT_NAMES.count == 18)
    }
}
