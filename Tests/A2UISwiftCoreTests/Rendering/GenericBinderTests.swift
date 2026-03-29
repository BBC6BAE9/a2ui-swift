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

// Mirrors WebCore rendering/generic-binder.test.ts
//
// WebCore's GenericBinder is a class that bridges DataContext to component
// properties by subscribing to Preact Signals and reactively updating DOM
// attributes. Its tests verify:
//
//   1. "should resolve checkable validation state reactively" —
//      Uses Zod schema (z.object with CommonSchemas.Checkable), Preact Signals
//      computed values, and async Promise-based reactive updates. Verifies that
//      `binder.snapshot.isValid` and `binder.snapshot.validationErrors` update
//      when the underlying data changes.
//
//   2. "should aggregate multiple validation rules correctly" —
//      Same mechanism with multiple `checks` entries, verifying partial and full
//      rule satisfaction.
//
//   3. "should provide a default message if rule.message is missing" —
//      Verifies that a check without a `message` property falls back to
//      "Validation failed".
//
//   4. "should default to valid if checks array is empty or undefined" —
//      Verifies that an empty `checks` array results in isValid=true.
//
// None of these tests are applicable to Swift for two reasons:
//
// 1. No GenericBinder implementation in Swift:
//    GenericBinder.swift is an empty structural mirror. In SwiftUI, the
//    @Observable macro and automatic dependency tracking replace all explicit
//    binder/subscription management — no binder class exists to test.
//
// 2. Checkable validation is UI-framework-level:
//    The `checks` / `isValid` / `validationErrors` logic is tied to Preact
//    Signals computed values and the Zod-based CommonSchemas.Checkable schema.
//    In Swift, field validation is handled by SwiftUI Form / .validator
//    modifiers or native binding patterns, not by a generic binder.
//
// This file exists solely to maintain file-level parity with WebCore.

@testable import A2UISwiftCore