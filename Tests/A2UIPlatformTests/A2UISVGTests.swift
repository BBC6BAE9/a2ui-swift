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
import CoreGraphics
@testable import A2UIPlatform

/// SVG-path parser gate.
final class A2UISVGTests: XCTestCase {

    func testParsesTriangleBoundingBox() throws {
        let path = try XCTUnwrap(a2ui_parseSVGPath("M0 0 L10 0 L10 10 Z"))
        let box = path.boundingBoxOfPath
        XCTAssertEqual(box.minX, 0, accuracy: 0.01)
        XCTAssertEqual(box.minY, 0, accuracy: 0.01)
        XCTAssertEqual(box.width, 10, accuracy: 0.01)
        XCTAssertEqual(box.height, 10, accuracy: 0.01)
    }

    func testParsesRelativeAndCurves() throws {
        // Relative moves/lines + a cubic curve should parse without nil.
        XCTAssertNotNil(a2ui_parseSVGPath("m2 2 l4 0 c1 1 2 2 3 3 z"))
    }

    func testRejectsGarbage() {
        XCTAssertNil(a2ui_parseSVGPath("not a path"))
    }
}

#endif
