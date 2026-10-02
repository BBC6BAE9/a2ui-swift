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
import Foundation

// `null` and plain objects are valid on the wire (e.g. `{"args":{"value":null}}`),
// so decoding them must fall back to `.string("")` without trapping in Debug builds.
struct DynamicValueDecodingTests {

    private func decode(_ json: String) throws -> DynamicValue {
        try JSONDecoder().decode(DynamicValue.self, from: Data(json.utf8))
    }

    @Test func nullFallsBackToEmptyString() throws {
        guard case .string(let s) = try decode("null") else {
            Issue.record("Expected .string")
            return
        }
        #expect(s == "")
    }

    @Test func plainObjectFallsBackToEmptyString() throws {
        guard case .string(let s) = try decode(#"{"foo":1}"#) else {
            Issue.record("Expected .string")
            return
        }
        #expect(s == "")
    }

    @Test func buttonWithNullEventContextValueDecodes() throws {
        let json = #"""
        {"version":"v0.9","updateComponents":{"surfaceId":"s1","components":[
          {"id":"btn","component":"Button","child":"label",
           "action":{"event":{"name":"x","context":{"k":null}}}}
        ]}}
        """#
        let message = try JSONDecoder().decode(A2uiMessage.self, from: Data(json.utf8))
        guard case .updateComponents(let payload) = message, let button = payload.components.first else {
            Issue.record("Expected updateComponents with one component")
            return
        }
        let props = try button.typedProperties(ButtonProperties.self)
        guard case .event(let name, let context) = props.action else {
            Issue.record("Expected .event action")
            return
        }
        #expect(name == "x")
        guard case .string(let value)? = context?["k"] else {
            Issue.record("Expected context[\"k\"] to be .string")
            return
        }
        #expect(value == "")
    }
}
