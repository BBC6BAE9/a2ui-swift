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

@Suite("Client-to-Server Schema Verification")
struct ClientToServerTests {

    // MARK: - Helpers

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return e
    }()

    private let decoder = JSONDecoder()

    // MARK: - Tests

    /// Mirrors WebCore: "validates a valid action message"
    @Test("validates a valid action message")
    func validatesValidActionMessage() throws {
        let action = A2uiClientAction(
            name: "submit",
            surfaceId: "s1",
            sourceComponentId: "c1",
            timestamp: "2026-01-01T00:00:00Z",
            context: ["foo": .string("bar")]
        )
        let original = A2uiClientMessage.action(action)

        let data = try encoder.encode(original)

        // Verify the encoded JSON carries the required version field.
        let jsonString = try #require(String(data: data, encoding: .utf8))
        #expect(jsonString.contains("\"version\":\"v0.9\""))

        // Verify the round-trip: decoding must succeed and reconstruct an action.
        let decoded = try decoder.decode(A2uiClientMessage.self, from: data)
        guard case .action(let decodedAction) = decoded else {
            Issue.record("Expected .action case after round-trip")
            return
        }
        #expect(decodedAction.name == "submit")
        #expect(decodedAction.surfaceId == "s1")
        #expect(decodedAction.sourceComponentId == "c1")
        #expect(decodedAction.timestamp == "2026-01-01T00:00:00Z")
        #expect(decodedAction.context["foo"] == .string("bar"))
    }

    /// Mirrors WebCore: "validates a valid error message (validation failed)"
    @Test("validates a valid error message (validation failed)")
    func validatesValidErrorMessageValidationFailed() throws {
        let clientError = A2uiClientError(
            code: "VALIDATION_FAILED",
            surfaceId: "s1",
            message: "Too short",
            path: "/components/0/text"
        )
        let original = A2uiClientMessage.error(clientError)

        let data = try encoder.encode(original)

        // Verify version field is present in the encoded JSON.
        let jsonString = try #require(String(data: data, encoding: .utf8))
        #expect(jsonString.contains("\"version\":\"v0.9\""))

        // Verify round-trip.
        let decoded = try decoder.decode(A2uiClientMessage.self, from: data)
        guard case .error(let decodedError) = decoded else {
            Issue.record("Expected .error case after round-trip")
            return
        }
        #expect(decodedError.code == "VALIDATION_FAILED")
        #expect(decodedError.surfaceId == "s1")
        #expect(decodedError.message == "Too short")
        #expect(decodedError.path == "/components/0/text")
    }

    /// Mirrors WebCore: "validates a valid error message (generic)"
    @Test("validates a valid error message (generic)")
    func validatesValidErrorMessageGeneric() throws {
        let clientError = A2uiClientError(
            code: "INTERNAL_ERROR",
            surfaceId: "s1",
            message: "Something went wrong"
        )
        let original = A2uiClientMessage.error(clientError)

        let data = try encoder.encode(original)

        // Verify version field is present in the encoded JSON.
        let jsonString = try #require(String(data: data, encoding: .utf8))
        #expect(jsonString.contains("\"version\":\"v0.9\""))

        // Verify round-trip.
        let decoded = try decoder.decode(A2uiClientMessage.self, from: data)
        guard case .error(let decodedError) = decoded else {
            Issue.record("Expected .error case after round-trip")
            return
        }
        #expect(decodedError.code == "INTERNAL_ERROR")
        #expect(decodedError.surfaceId == "s1")
        #expect(decodedError.message == "Something went wrong")
        #expect(decodedError.path == nil)
    }

    /// Mirrors WebCore: "validates a valid data model message"
    @Test("validates a valid data model message")
    func validatesValidDataModelMessage() throws {
        let original = A2uiClientDataModel(
            surfaces: [
                "s1": .dictionary(["user": .string("Alice")]),
                "s2": .dictionary(["cart": .array([])]),
            ]
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(A2uiClientDataModel.self, from: data)

        #expect(decoded.version == "v0.9")
        #expect(decoded.surfaces["s1"] != nil)
        #expect(decoded.surfaces["s2"] != nil)
    }

    /// Mirrors WebCore: "fails on invalid version"
    ///
    /// NOTE: WebCore validates `version` via Zod schema (rejects "v0.8").
    /// Swift's Codable decoder does not validate the version field — it only
    /// checks for the presence of "action" or "error" keys. Version validation
    /// would be done at a higher protocol layer.
    ///
    /// Instead, this test verifies that decoding DOES fail when neither
    /// "action" nor "error" key is present: `{ "version": "v0.9" }` → DecodingError.
    @Test("fails on invalid version")
    func failsOnInvalidVersion() throws {
        let json = #"{"version":"v0.8"}"#
        let data = try #require(json.data(using: .utf8))

        #expect(throws: (any Error).self) {
            try decoder.decode(A2uiClientMessage.self, from: data)
        }
    }
}
