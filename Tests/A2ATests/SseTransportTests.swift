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
// MARK: - SseTransport Tests
// Mirrors Dart `test/a2a/client/sse_transport_test.dart`
//
// All SSE-parsing tests drive SseParser directly with an
// AsyncThrowingStream<String, Error>, bypassing URLSession entirely.
// This is the reliable approach because URLSession.bytes() with a custom
// URLProtocol does not reliably deliver streamed body chunks in unit tests
// — the internal AsyncBytes buffer may not be ready before didLoad is called.
//
// The HTTP-error test is the only one that exercises SseTransport + URLProtocol,
// because it only needs the response headers (no body is consumed).

@Suite("SseTransport")
struct SseTransportTests {

    // MARK: - Helpers

    /// Builds a stream of parsed SSE events from raw SSE line strings.
    /// Lines are fed synchronously so the stream is finite and self-contained.
    private func makeSseStream(
        _ lines: [String]
    ) -> AsyncThrowingStream<[String: Any], Error> {
        let (lineStream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        for line in lines { continuation.yield(line) }
        continuation.finish()
        return SseParser().parse(lineStream)
    }

    /// Creates an SseTransport backed by a StreamingMockProtocol URLSession.
    /// Used only for the HTTP-error test, which checks status-code handling.
    private func makeTransport(statusCode: Int) -> SseTransport {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StreamingMockProtocol.self]
        StreamingMockProtocol.statusCode = statusCode
        StreamingMockProtocol.lines = []
        return SseTransport(url: "http://localhost:8080", session: URLSession(configuration: config))
    }

    // MARK: - Tests

    @Test("handles multi-line data")
    func multiLineData() async throws {
        let sseStream = makeSseStream([
            "data: { \"result\": { \"line1\": \"hello\",",
            "data: \"line2\": \"world\" } }",
            "",
        ])

        var results: [[String: Any]] = []
        for try await item in sseStream {
            results.append(item)
        }

        #expect(results.count == 1)
        #expect(results[0]["line1"] as? String == "hello")
        #expect(results[0]["line2"] as? String == "world")
    }

    @Test("handles SSE comments (keepalive lines)")
    func handlesComments() async throws {
        let sseStream = makeSseStream([
            ": this is a comment",
            "data: { \"result\": { \"key\": \"value\" } }",
            "",
        ])

        var results: [[String: Any]] = []
        for try await item in sseStream {
            results.append(item)
        }

        #expect(results.count == 1)
        #expect(results[0]["key"] as? String == "value")
    }

    @Test("handles JSON-RPC error in SSE stream")
    func handlesJsonRpcError() async throws {
        let sseStream = makeSseStream([
            "data: { \"result\": { \"key\": \"value\" } }",
            "",
            "data: { \"error\": { \"code\": -32000, \"message\": \"Server error\" } }",
            "",
        ])

        var results: [[String: Any]] = []
        var caughtError: Error?
        do {
            for try await item in sseStream {
                results.append(item)
            }
        } catch {
            caughtError = error
        }

        #expect(results.count == 1)
        #expect(results[0]["key"] as? String == "value")
        #expect(caughtError is A2ATransportError)
    }

    @Test("handles HTTP error response")
    func handlesHttpError() async throws {
        let transport = makeTransport(statusCode: 400)

        var caughtError: Error?
        do {
            for try await _ in transport.sendStream([:]) {}
        } catch {
            caughtError = error
        }

        #expect(caughtError is A2ATransportError)
        if case .http(let code, _) = caughtError as? A2ATransportError {
            #expect(code == 400)
        } else {
            Issue.record("Expected .http error, got \(String(describing: caughtError))")
        }
    }

    @Test("handles malformed JSON in SSE stream")
    func handlesMalformedJson() async throws {
        let sseStream = makeSseStream([
            "data: { \"result\": { \"key\": \"value\" } }",
            "",
            "data: not json",
            "",
        ])

        var results: [[String: Any]] = []
        var caughtError: Error?
        do {
            for try await item in sseStream {
                results.append(item)
            }
        } catch {
            caughtError = error
        }

        #expect(results.count == 1)
        #expect(results[0]["key"] as? String == "value")
        #expect(caughtError is A2ATransportError)
    }
}

// MARK: - StreamingMockProtocol
// Used only by handlesHttpError — delivers response headers asynchronously
// so URLSession.bytes() can receive the status code and throw .http.

final class StreamingMockProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var lines: [String] = []
    nonisolated(unsafe) static var statusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let code = StreamingMockProtocol.statusCode

        // Deliver asynchronously: startLoading() must return before any
        // client callbacks are made so URLSession's async machinery is ready.
        DispatchQueue.global().async { [self] in
            let response = HTTPURLResponse(
                url: self.request.url!,
                statusCode: code,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
