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
import XCTest
@testable import A2UIPlatform

/// Validation logic gate (regexp whole-match, mirrors SwiftUI).
final class A2UIValidationTests: XCTestCase {

    func testRegexpWholeMatch() {
        XCTAssertNil(a2ui_regexpMessage(value: "12345", pattern: "[0-9]+"))
        XCTAssertEqual(a2ui_regexpMessage(value: "12a45", pattern: "[0-9]+"), "Invalid format")
    }

    func testEmptyValueOrPatternSkipsValidation() {
        XCTAssertNil(a2ui_regexpMessage(value: "", pattern: "[0-9]+"))
        XCTAssertNil(a2ui_regexpMessage(value: "abc", pattern: nil))
        XCTAssertNil(a2ui_regexpMessage(value: "abc", pattern: ""))
    }
}

#endif
