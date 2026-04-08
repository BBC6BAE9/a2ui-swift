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
import Foundation
import Testing

@Suite("Schema strictness")
struct VerifySchemaTests {

    private let decoder = JSONDecoder()

    @Test("server-to-client rejects invalid version")
    func serverToClientRejectsInvalidVersion() throws {
        let json = #"{"version":"v0.8","deleteSurface":{"surfaceId":"s1"}}"#
        let data = try #require(json.data(using: .utf8))

        #expect(throws: Error.self) {
            try decoder.decode(A2uiMessage.self, from: data)
        }
    }

    @Test("client-to-server rejects invalid version")
    func clientToServerRejectsInvalidVersion() throws {
        let json = #"{"version":"v0.8","action":{"name":"submit","surfaceId":"s1","sourceComponentId":"c1","timestamp":"2026-01-01T00:00:00Z","context":{}}}"#
        let data = try #require(json.data(using: .utf8))

        #expect(throws: Error.self) {
            try decoder.decode(A2uiClientMessage.self, from: data)
        }
    }

    @Test("dynamic string rejects object with extra properties")
    func dynamicStringRejectsExtraProperties() throws {
        let json = #"{"path":"/title","extra":true}"#
        let data = try #require(json.data(using: .utf8))

        #expect(throws: Error.self) {
            try decoder.decode(DynamicString.self, from: data)
        }
    }

    @Test("dynamic string rejects function call with wrong return type")
    func dynamicStringRejectsWrongReturnType() throws {
        let json = #"{"call":"formatNumber","args":{"value":1},"returnType":"number"}"#
        let data = try #require(json.data(using: .utf8))

        #expect(throws: Error.self) {
            try decoder.decode(DynamicString.self, from: data)
        }
    }

    @Test("child list rejects invalid object shape")
    func childListRejectsInvalidObjectShape() throws {
        let json = #"{"componentId":"row","path":"/items","extra":"nope"}"#
        let data = try #require(json.data(using: .utf8))

        #expect(throws: Error.self) {
            try decoder.decode(ChildList.self, from: data)
        }
    }

    @Test("action rejects extra properties")
    func actionRejectsExtraProperties() throws {
        let json = #"{"event":{"name":"submit"},"extra":true}"#
        let data = try #require(json.data(using: .utf8))

        #expect(throws: Error.self) {
            try decoder.decode(Action.self, from: data)
        }
    }

    @Test("action event rejects context values outside dynamic value schema")
    func actionRejectsInvalidContextValue() throws {
        let json = #"{"event":{"name":"submit","context":{"payload":{"nested":1}}}}"#
        let data = try #require(json.data(using: .utf8))

        #expect(throws: Error.self) {
            try decoder.decode(Action.self, from: data)
        }
    }

    @Test("check rule rejects legacy function-call shape")
    func checkRuleRejectsLegacyShape() throws {
        let json = #"{"call":"required","args":{"value":{"path":"/email"}},"message":"Email is required"}"#
        let data = try #require(json.data(using: .utf8))

        #expect(throws: Error.self) {
            try decoder.decode(CheckRule.self, from: data)
        }
    }

    @Test("text properties reject unsupported variant enum")
    func textPropertiesRejectUnsupportedVariant() throws {
        let json = #"{"text":"Hello","variant":"headline"}"#
        let data = try #require(json.data(using: .utf8))

        #expect(throws: Error.self) {
            try decoder.decode(TextProperties.self, from: data)
        }
    }

    @Test("button properties reject unsupported variant enum")
    func buttonPropertiesRejectUnsupportedVariant() throws {
        let json = #"{"child":"label","variant":"danger","action":{"event":{"name":"tap"}}}"#
        let data = try #require(json.data(using: .utf8))

        #expect(throws: Error.self) {
            try decoder.decode(ButtonProperties.self, from: data)
        }
    }

    @Test("raw component rejects non-object payload")
    func rawComponentRejectsNonObjectPayload() throws {
        let json = #"["not-an-object"]"#
        let data = try #require(json.data(using: .utf8))

        #expect(throws: Error.self) {
            try decoder.decode(RawComponent.self, from: data)
        }
    }
}
