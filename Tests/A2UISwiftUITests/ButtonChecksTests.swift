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

// Spec coverage: a2ui_protocol.md §617
//   "Buttons can also define `checks`. If any check fails, the button is
//    automatically disabled."
// Reference behavior: WebCore Lit Button.ts:102-113 reads `props.isValid === false`;
// Flutter button.dart:104-112 gates `onPressed` on `isValid`.
//
// These tests exercise the same decision predicate the SwiftUI view applies:
//   `dc.firstFailingCheckMessage(props.checks) != nil` → disabled.

// MARK: - Local helpers (avoid cross-target dependency on TestUtils.swift)

private func makeSurface(data: [String: AnyCodable] = [:]) -> SurfaceModel {
    let surface = SurfaceModel(id: "test", catalog: Catalog(id: "test-catalog"))
    if !data.isEmpty {
        try! surface.dataModel.set("/", value: AnyCodable.dictionary(data))
    }
    return surface
}

// MARK: - T1: ButtonProperties decoding

@Suite("ButtonProperties.checks decoding")
struct ButtonPropertiesChecksDecodingTests {

    @Test("decodes checks when present")
    func decodesChecks() throws {
        let json = #"""
        {
          "child": "label",
          "action": {"event": {"name": "submit"}},
          "checks": [
            {"condition": {"path": "/formData/valid"}, "message": "invalid"}
          ]
        }
        """#.data(using: .utf8)!
        let props = try JSONDecoder().decode(ButtonProperties.self, from: json)
        #expect(props.checks?.count == 1)
        #expect(props.checks?.first?.message == "invalid")
    }

    @Test("checks is nil when absent (back-compat)")
    func checksNilWhenAbsent() throws {
        let json = #"""
        {"child": "label", "action": {"event": {"name": "submit"}}}
        """#.data(using: .utf8)!
        let props = try JSONDecoder().decode(ButtonProperties.self, from: json)
        #expect(props.checks == nil)
    }
}

// MARK: - T2: disable predicate behavior

@Suite("Button disable predicate (firstFailingCheckMessage)")
struct ButtonDisablePredicateTests {

    private let validChecks: [CheckRule] = [
        CheckRule(
            condition: .dataBinding(path: "/formData/valid"),
            message: "Form is invalid"
        )
    ]

    @Test("nil checks → not disabled")
    func nilChecksNotDisabled() {
        let dc = DataContext(surface: makeSurface(), path: "/")
        #expect(dc.firstFailingCheckMessage(nil) == nil)
    }

    @Test("empty checks → not disabled")
    func emptyChecksNotDisabled() {
        let dc = DataContext(surface: makeSurface(), path: "/")
        #expect(dc.firstFailingCheckMessage([]) == nil)
    }

    @Test("all checks pass → not disabled")
    func allChecksPassNotDisabled() {
        let inner: [String: AnyCodable] = ["valid": .bool(true)]
        let surface = makeSurface(data: ["formData": .dictionary(inner)])
        let dc = DataContext(surface: surface, path: "/")
        #expect(dc.firstFailingCheckMessage(validChecks) == nil)
    }

    @Test("any check fails → disabled (returns first failing message)")
    func anyCheckFailsDisabled() {
        let inner: [String: AnyCodable] = ["valid": .bool(false)]
        let surface = makeSurface(data: ["formData": .dictionary(inner)])
        let dc = DataContext(surface: surface, path: "/")
        #expect(dc.firstFailingCheckMessage(validChecks) == "Form is invalid")
    }

    @Test("reactive: predicate flips when DataModel changes")
    func reactiveOnDataModelChange() throws {
        let inner: [String: AnyCodable] = ["valid": .bool(false)]
        let surface = makeSurface(data: ["formData": .dictionary(inner)])
        let dc = DataContext(surface: surface, path: "/")

        // Initially invalid → disabled
        #expect(dc.firstFailingCheckMessage(validChecks) == "Form is invalid")

        // Flip data → button becomes enabled
        try surface.dataModel.set("/formData/valid", value: AnyCodable.bool(true))
        #expect(dc.firstFailingCheckMessage(validChecks) == nil)

        // Flip back → disabled again
        try surface.dataModel.set("/formData/valid", value: AnyCodable.bool(false))
        #expect(dc.firstFailingCheckMessage(validChecks) == "Form is invalid")
    }

    @Test("multiple checks: first failing message wins")
    func multipleChecksFirstWins() {
        let inner: [String: AnyCodable] = [
            "a": .bool(true),
            "b": .bool(false),
            "c": .bool(false),
        ]
        let surface = makeSurface(data: ["formData": .dictionary(inner)])
        let dc = DataContext(surface: surface, path: "/")

        let checks: [CheckRule] = [
            CheckRule(condition: .dataBinding(path: "/formData/a"), message: "a failed"),
            CheckRule(condition: .dataBinding(path: "/formData/b"), message: "b failed"),
            CheckRule(condition: .dataBinding(path: "/formData/c"), message: "c failed"),
        ]
        #expect(dc.firstFailingCheckMessage(checks) == "b failed")
    }
}
