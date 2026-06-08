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

/// Theme / hex-color gate.
final class A2UIThemeTests: XCTestCase {

    override func tearDown() {
        A2UIPlatformStyle.tintOverride = nil
        super.tearDown()
    }

    func testParsesHexForms() {
        XCTAssertNotNil(PlatformColor(a2uiHex: "#FF0000"))
        XCTAssertNotNil(PlatformColor(a2uiHex: "00FF00"))
        XCTAssertNotNil(PlatformColor(a2uiHex: "#FFF"))
        XCTAssertNotNil(PlatformColor(a2uiHex: "#11223344"))
        XCTAssertNil(PlatformColor(a2uiHex: "nothex"))
    }

    func testApplyThemeSetsTintOverride() {
        A2UIPlatformStyle.applyTheme(["primaryColor": "#FF0000"])
        XCTAssertNotNil(A2UIPlatformStyle.tintOverride)
        A2UIPlatformStyle.applyTheme(nil)
        XCTAssertNil(A2UIPlatformStyle.tintOverride)
    }
}

#endif
