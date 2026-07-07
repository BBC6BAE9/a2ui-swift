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

import XCTest
@testable import A2UISwiftCore

/// Direct unit coverage for `A2uiPayloadValidator`, complementing the YAML-driven
/// `ValidatorConformanceTests`. These lock in behaviors the conformance suite exercises
/// only on the throwing side, so a future refactor can't silently change them.
///
/// Every expectation here mirrors the Python reference validator
/// (`a2ui_core/core/validating/*`); the reference is the source of truth.
final class A2uiPayloadValidatorTests: XCTestCase {

    // MARK: - Helpers

    /// Parses a JSON string into the `[Any]` message-array shape the validator consumes.
    private func payload(_ json: String) throws -> Any {
        let data = json.data(using: .utf8)!
        return try JSONSerialization.jsonObject(with: data)
    }

    /// A catalog exposing Card (single `child` ref), List (`children` child-list ref),
    /// Text (leaf), and Button (opaque `action`) — enough for the graph/recursion rules.
    private var catalogSchema: [String: Any] {
        [
            "catalogId": "std",
            "components": [
                "Card": [
                    "type": "object",
                    "properties": [
                        "component": ["const": "Card"],
                        "child": ["$ref": "…/common_types.json#/$defs/ComponentId"],
                    ],
                ],
                "List": [
                    "type": "object",
                    "properties": [
                        "component": ["const": "List"],
                        "children": ["$ref": "…/common_types.json#/$defs/ChildList"],
                    ],
                ],
                "Text": [
                    "type": "object",
                    "properties": [
                        "component": ["const": "Text"],
                        "text": ["type": "string"],
                    ],
                ],
                "Button": [
                    "type": "object",
                    "properties": [
                        "component": ["const": "Button"],
                        "text": ["type": "string"],
                        "action": ["type": "object"],
                        "disabled": ["type": "boolean"],
                    ],
                ],
                // A component whose `content` accepts a dynamic object, so a `{path: …}`
                // binding reaches the path-syntax check rather than tripping a type check.
                "Box": [
                    "type": "object",
                    "properties": [
                        "component": ["const": "Box"],
                        "content": ["type": "object"],
                    ],
                ],
            ],
        ]
    }

    private func makeValidator() -> A2uiPayloadValidator {
        A2uiPayloadValidator(catalogSchema: catalogSchema)
    }

    private func assertMessage(_ error: Error, contains needle: String) {
        let message = (error as? any A2uiError)?.message ?? "\(error)"
        XCTAssertTrue(message.contains(needle),
                      "Expected error message to contain '\(needle)', got '\(message)'")
    }

    // MARK: - functionCall recursion depth (reference-matching, incl. double-nesting)

    /// The v0.9 wire form nests a `functionCall` *wrapper* dict around each `{call, args}`
    /// dict, so the reference algorithm increments `funcDepth` twice per logical call. This
    /// is deliberate and must match the Python reference — a chain that trips the `>= 5`
    /// limit throws. (Python throws on this exact fixture at the third nested call.)
    func test_functionCall_deeplyNested_throwsRecursionError() throws {
        let json = #"[{"version": "v0.9", "updateComponents": {"surfaceId": "s1", "components": [{"id": "root", "component": "Button", "text": "btn", "action": {"functionCall": {"call": "f0", "args": {"functionCall": {"call": "f1", "args": {"functionCall": {"call": "f2", "args": {"functionCall": {"call": "f3", "args": {"functionCall": {"call": "f4", "args": {"functionCall": {"call": "f5", "args": {}}}}}}}}}}}}}}]}}]"#
        XCTAssertThrowsError(try makeValidator().validate(payload(json))) { error in
            self.assertMessage(error, contains: "Recursion limit exceeded: functionCall depth > 5")
        }
    }

    /// A single, shallow `functionCall` must NOT trip the recursion limit. This guards the
    /// "valid payload incorrectly throws" regression: a lone action call is always allowed.
    func test_functionCall_shallow_isValid() throws {
        let json = """
        [{"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
          {"id":"root","component":"Button","text":"btn","action":
            {"functionCall":{"call":"submit","args":{"value":"x"}}}}
        ]}}]
        """
        XCTAssertNoThrow(try makeValidator().validate(payload(json)))
    }

    // MARK: - Duplicate ids / missing root / dangling references

    func test_duplicateIds_throw() throws {
        let json = """
        [{"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"std"}},
         {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
           {"id":"root","component":"Text","text":"a"},
           {"id":"dup","component":"Text","text":"b"},
           {"id":"dup","component":"Text","text":"c"}
         ]}}]
        """
        XCTAssertThrowsError(try makeValidator().validate(payload(json))) { error in
            self.assertMessage(error, contains: "Duplicate component ID: dup")
        }
    }

    func test_missingRoot_throwsForFullRender() throws {
        let json = """
        [{"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"std"}},
         {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
           {"id":"c1","component":"Text","text":"hi"}
         ]}}]
        """
        XCTAssertThrowsError(try makeValidator().validate(payload(json))) { error in
            self.assertMessage(error, contains: "Missing root component")
        }
    }

    func test_danglingReference_throws() throws {
        let json = """
        [{"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"std"}},
         {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
           {"id":"root","component":"Card","child":"nope"}
         ]}}]
        """
        XCTAssertThrowsError(try makeValidator().validate(payload(json))) { error in
            self.assertMessage(error, contains: "references non-existent component")
        }
    }

    // MARK: - Self-reference / cycles / orphans

    func test_selfReference_throws() throws {
        let json = """
        [{"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"std"}},
         {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
           {"id":"root","component":"Card","child":"root"}
         ]}}]
        """
        XCTAssertThrowsError(try makeValidator().validate(payload(json))) { error in
            self.assertMessage(error, contains: "Self-reference detected")
        }
    }

    func test_circularReference_throws() throws {
        let json = """
        [{"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"std"}},
         {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
           {"id":"root","component":"Card","child":"a"},
           {"id":"a","component":"Card","child":"root"}
         ]}}]
        """
        XCTAssertThrowsError(try makeValidator().validate(payload(json))) { error in
            self.assertMessage(error, contains: "Circular reference detected")
        }
    }

    func test_orphanComponent_throwsForFullRender() throws {
        let json = """
        [{"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"std"}},
         {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
           {"id":"root","component":"Text","text":"root"},
           {"id":"orphan","component":"Text","text":"lonely"}
         ]}}]
        """
        XCTAssertThrowsError(try makeValidator().validate(payload(json))) { error in
            self.assertMessage(error, contains: "Component 'orphan' is not reachable from 'root'")
        }
    }

    // MARK: - Logical (component-chain) depth boundary

    /// A chain of Cards whose logical depth is within the limit must pass. Root at depth 0,
    /// so 51 nodes (depths 0…50) is the maximum valid chain.
    func test_logicalDepth_atLimit_isValid() throws {
        var components = "{\"id\":\"root\",\"component\":\"Card\",\"child\":\"c0\"}"
        for i in 0..<49 {
            components += ",{\"id\":\"c\(i)\",\"component\":\"Card\",\"child\":\"c\(i + 1)\"}"
        }
        components += ",{\"id\":\"c49\",\"component\":\"Text\",\"text\":\"end\"}"
        let json = """
        [{"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"std"}},
         {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[\(components)]}}]
        """
        XCTAssertNoThrow(try makeValidator().validate(payload(json)))
    }

    /// One node past the limit must throw a logical-depth recursion error.
    func test_logicalDepth_overLimit_throws() throws {
        var components = "{\"id\":\"root\",\"component\":\"Card\",\"child\":\"c0\"}"
        for i in 0..<55 {
            components += ",{\"id\":\"c\(i)\",\"component\":\"Card\",\"child\":\"c\(i + 1)\"}"
        }
        components += ",{\"id\":\"c55\",\"component\":\"Text\",\"text\":\"end\"}"
        let json = """
        [{"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"std"}},
         {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[\(components)]}}]
        """
        XCTAssertThrowsError(try makeValidator().validate(payload(json))) { error in
            self.assertMessage(error, contains: "Global recursion limit exceeded: logical depth")
        }
    }

    // MARK: - Data-model depth / path syntax

    func test_invalidPathSyntax_throws() throws {
        let json = """
        [{"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
          {"id":"root","component":"Box","content":{"path":"/invalid/escape/~2"}}
        ]}}]
        """
        XCTAssertThrowsError(try makeValidator().validate(payload(json))) { error in
            self.assertMessage(error, contains: "Invalid path syntax")
        }
    }

    func test_validPathSyntax_isValid() throws {
        // A well-formed JSON Pointer with a legal ~1 escape must pass.
        let json = """
        [{"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
          {"id":"root","component":"Box","content":{"path":"/a~1b/c"}}
        ]}}]
        """
        XCTAssertNoThrow(try makeValidator().validate(payload(json)))
    }

    // MARK: - Incremental updates

    /// An update-only payload (no createSurface) is incremental: no root and references to
    /// ids delivered earlier are allowed — but self-references, cycles and duplicates aren't.
    func test_incrementalUpdate_allowsMissingRootAndOrphans() throws {
        let json = """
        [{"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
          {"id":"a","component":"Card","child":"b"},
          {"id":"b","component":"Text","text":"hi"}
        ]}}]
        """
        XCTAssertNoThrow(try makeValidator().validate(payload(json)))
    }

    func test_incrementalUpdate_stillCatchesSelfReference() throws {
        let json = """
        [{"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
          {"id":"a","component":"Card","child":"a"}
        ]}}]
        """
        XCTAssertThrowsError(try makeValidator().validate(payload(json))) { error in
            self.assertMessage(error, contains: "Self-reference detected")
        }
    }

    // MARK: - Catalog property schema

    func test_propertyTypeMismatch_throws() throws {
        let json = """
        [{"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
          {"id":"root","component":"Text","text":123}
        ]}}]
        """
        XCTAssertThrowsError(try makeValidator().validate(payload(json))) { error in
            self.assertMessage(error, contains: "is not of type 'string'")
        }
    }

    /// On Darwin, `NSNumber(value: 0)` / `NSNumber(value: 1)` bridge to `is Bool == true`
    /// (ObjC `BOOL`/`char` aliasing), so a naive `value is Bool` type check misclassifies
    /// the integers 0/1 from `JSONSerialization` as booleans. `disabled: 1` must still be
    /// rejected as not-a-boolean.
    func test_booleanProperty_rejectsIntegerZeroOrOne() throws {
        let json = """
        [{"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
          {"id":"root","component":"Button","text":"btn","disabled":1}
        ]}}]
        """
        XCTAssertThrowsError(try makeValidator().validate(payload(json))) { error in
            self.assertMessage(error, contains: "is not of type 'boolean'")
        }
    }

    func test_booleanProperty_acceptsTrueFalse() throws {
        let json = """
        [{"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
          {"id":"root","component":"Button","text":"btn","disabled":false}
        ]}}]
        """
        XCTAssertNoThrow(try makeValidator().validate(payload(json)))
    }

    func test_validPayload_isValid() throws {
        let json = """
        [{"version":"v0.9","createSurface":{"surfaceId":"s1","catalogId":"std"}},
         {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
           {"id":"root","component":"Card","child":"c1"},
           {"id":"c1","component":"Text","text":"hello"}
         ]}}]
        """
        XCTAssertNoThrow(try makeValidator().validate(payload(json)))
    }
}
