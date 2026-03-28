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

import Testing
import Foundation
@testable import A2A
// MARK: - HttpTransport Tests
// Mirrors Dart `test/a2a/client/http_transport_test.dart`

@Suite("HttpTransport")
struct HttpTransportTests {

    @Test("send returns a dictionary on success")
    func sendReturnsDict() async throws {
        let expected: [String: Any] = ["result": ["message": "success"]]
        let transport = MockHttpTransport(response: expected, statusCode: 200)

        let result = try await transport.send([:])

        let resultValue = result["result"] as? [String: Any]
        #expect(resultValue?["message"] as? String == "success")
    }

    @Test("get returns a dictionary on success")
    func getReturnsDict() async throws {
        let expected: [String: Any] = ["message": "success"]
        let transport = MockHttpTransport(response: expected, statusCode: 200)

        let result = try await transport.get(path: "/test")

        #expect(result["message"] as? String == "success")
    }

    @Test("send throws A2ATransportError.http on 4xx status")
    func sendThrowsOnError() async throws {
        let transport = MockHttpTransport(response: [:], statusCode: 400)

        do {
            _ = try await transport.send([:])
            Issue.record("Expected an error to be thrown")
        } catch let error as A2ATransportError {
            if case .http(let statusCode, _) = error {
                #expect(statusCode == 400)
            } else {
                Issue.record("Expected .http error, got \(error)")
            }
        }
    }

    @Test("sendStream throws A2ATransportError.unsupportedOperation")
    func sendStreamThrowsUnsupported() async throws {
        let transport = MockHttpTransport(response: [:], statusCode: 200)
        let stream = transport.sendStream([:])

        do {
            for try await _ in stream {
                Issue.record("Should not receive any elements")
            }
            Issue.record("Expected an error to be thrown")
        } catch let error as A2ATransportError {
            if case .unsupportedOperation(_) = error {
                // expected
            } else {
                Issue.record("Expected .unsupportedOperation, got \(error)")
            }
        }
    }
}

// MARK: - Mock HTTP transport for unit tests
// Bypasses URLSession with a configurable in-memory response.

private final class MockHttpTransport: HttpTransport, @unchecked Sendable {
    private let mockResponse: [String: Any]
    private let mockStatusCode: Int

    init(response: [String: Any], statusCode: Int) {
        self.mockResponse = response
        self.mockStatusCode = statusCode
        super.init(url: "http://localhost:8080")
    }

    override func get(
        path: String,
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        if mockStatusCode >= 400 {
            throw A2ATransportError.http(statusCode: mockStatusCode, reason: nil)
        }
        return mockResponse
    }

    override func send(
        _ request: [String: Any],
        path: String = "",
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        if mockStatusCode >= 400 {
            throw A2ATransportError.http(statusCode: mockStatusCode, reason: nil)
        }
        return mockResponse
    }
}
