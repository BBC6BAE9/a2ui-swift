// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
import Primitives@testable import TravelApp

/// Tests for `GoogleGenerativeAiClient`.
///
/// Mirrors Flutter's `google_generative_ai_client_test.dart`.
final class GoogleGenerativeAiClientTests: XCTestCase {

    /// Mirrors Flutter test: "sendRequest includes clientDataModel in prompt"
    ///
    /// When `clientDataModel` is provided, the system instruction should
    /// contain a "Client Data Model:" section with the serialized data.
    func testSendRequestIncludesClientDataModelInPrompt() async throws {
        let fakeService = FakeGoogleGenerativeService()
        let client = GoogleGenerativeAiClient(
            apiKey: "test-api-key",
            service: fakeService
        )

        let clientData: [String: Any] = ["theme": "dark", "userId": 123]
        let message = Primitives.ChatMessage(
            role: .user,
            parts: [.text("Hello")]
        )

        fakeService.responseToReturn = GenerateContentResponse(json: [
            "candidates": [
                [
                    "content": [
                        "role": "model",
                        "parts": [
                            ["text": "Response"],
                        ],
                    ] as [String: Any],
                ] as [String: Any],
            ] as [[String: Any]],
        ])

        try await client.sendRequest(
            message,
            clientDataModel: clientData
        )

        let capturedRequest = fakeService.capturedRequest
        XCTAssertNotNil(capturedRequest)

        // In Swift, clientDataModel lives in `systemInstruction`, not `contents`.
        // Flutter puts system instruction in contents; Swift separates them.
        let systemInstruction = capturedRequest?.systemInstruction
        XCTAssertNotNil(systemInstruction)

        let parts = systemInstruction?["parts"] as? [[String: Any]]
        XCTAssertNotNil(parts)

        var foundClientData = false
        for part in parts ?? [] {
            if let text = part["text"] as? String,
               text.contains("Client Data Model:") {
                XCTAssertTrue(
                    text.contains("\"theme\""),
                    "Expected 'theme' in client data model text"
                )
                XCTAssertTrue(
                    text.contains("dark"),
                    "Expected 'dark' in client data model text"
                )
                XCTAssertTrue(
                    text.contains("userId"),
                    "Expected 'userId' in client data model text"
                )
                XCTAssertTrue(
                    text.contains("123"),
                    "Expected '123' in client data model text"
                )
                foundClientData = true
            }
        }
        XCTAssertTrue(
            foundClientData,
            "Client Data Model not found in system instruction"
        )

        client.dispose()
    }
}

// MARK: - Fake Service

/// A fake implementation of `GoogleGenerativeServiceInterface` for testing.
///
/// Mirrors Flutter's `FakeGoogleGenerativeService`.
class FakeGoogleGenerativeService: GoogleGenerativeServiceInterface {
    var capturedRequest: GenerateContentRequest?
    var responseToReturn: GenerateContentResponse?

    func generateContent(
        _ request: GenerateContentRequest
    ) async throws -> GenerateContentResponse {
        capturedRequest = request
        return responseToReturn ?? GenerateContentResponse(json: [:])
    }

    func close() {}
}
