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

import Foundation
#if canImport(os)
import os
#endif

// MARK: - SseTransport

/// An ``A2ATransport`` implementation using Server-Sent Events (SSE) for streaming.
///
/// Extends ``HttpTransport`` to add support for streaming responses from the server
/// via an SSE connection. Use this transport for methods like `message/stream`
/// where the server pushes multiple events over time.
///
/// Mirrors Flutter `SseTransport extends HttpTransport`
/// in `genui_a2a/client/sse_transport.dart`.
///
/// ### Inheritance
///
/// - `get(path:headers:)` → inherited from ``HttpTransport``
/// - `send(_:path:headers:)` → inherited from ``HttpTransport``
/// - `sendStream(_:headers:)` → overridden here to use SSE via `URLSession.bytes`
/// - `close()` → inherited from ``HttpTransport``
public final class SseTransport: HttpTransport, @unchecked Sendable {

    private let sseParser = SseParser()

    /// Creates an ``SseTransport`` instance.
    ///
    /// - Parameters:
    ///   - url: The base URL of the A2A server.
    ///   - authHeaders: Optional additional headers for every request.
    ///   - session: Optional `URLSession` for custom configurations or testing.
    public override init(
        url: String,
        authHeaders: [String: String] = [:],
        session: URLSession = .shared
    ) {
        super.init(url: url, authHeaders: authHeaders, session: session)
    }

    // MARK: - sendStream override

    /// Sends a JSON-RPC request and returns a streaming sequence of SSE events.
    ///
    /// Issues a POST request with `Accept: text/event-stream`, then parses the
    /// response body as SSE using ``SseParser``.
    ///
    /// - Parameters:
    ///   - request: The JSON-RPC request body.
    ///   - headers: Optional additional headers for this request.
    /// - Returns: An `AsyncThrowingStream` of JSON objects, one per SSE event.
    public override func sendStream(
        _ request: [String: Any],
        headers: [String: String] = [:]
    ) -> AsyncThrowingStream<[String: Any], Error> {
        // Use makeStream() to avoid sending-closure data race diagnostics.
        let (stream, continuation) = AsyncThrowingStream<[String: Any], Error>.makeStream()

        // Capture all values we need so the Task closure only touches Sendable locals.
        let capturedURL = url
        let capturedAuthHeaders = authHeaders
        let capturedSession = session
        let parser = sseParser

        // Serialize request body eagerly before spawning the Task.
        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: request)
        } catch {
            continuation.finish(throwing: A2ATransportError.parsing(
                message: "Failed to encode request: \(error.localizedDescription)"
            ))
            return stream
        }

        // Merge headers eagerly.
        var allHeaders = [
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
        ]
        allHeaders.merge(capturedAuthHeaders) { _, new in new }
        allHeaders.merge(headers) { _, new in new }
        let finalHeaders = allHeaders

        #if canImport(os)
        let log = logger
        #endif

        let task = Task {
            guard let requestURL = URL(string: capturedURL) else {
                continuation.finish(throwing: A2ATransportError.network(
                    message: "Invalid URL: \(capturedURL)"
                ))
                return
            }

            var urlRequest = URLRequest(url: requestURL)
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = bodyData
            for (key, value) in finalHeaders {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }

            #if canImport(os)
            log.debug("Sending SSE request to \(requestURL)")
            #endif

            do {
                let (bytes, response) = try await capturedSession.bytes(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.finish(throwing: A2ATransportError.network(
                        message: "Non-HTTP response received."
                    ))
                    return
                }

                if httpResponse.statusCode >= 400 {
                    var body = ""
                    for try await line in bytes.lines {
                        body += line
                    }
                    #if canImport(os)
                    log.error("SSE error response: \(httpResponse.statusCode) \(body)")
                    #endif
                    continuation.finish(throwing: A2ATransportError.http(
                        statusCode: httpResponse.statusCode,
                        reason: "\(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)) \(body)"
                    ))
                    return
                }

                let lineStream = bytes.lines
                let events = parser.parse(lineStream)

                for try await event in events {
                    nonisolated(unsafe) let sendable = event
                    continuation.yield(sendable)
                }
                continuation.finish()
            } catch {
                if let transportError = error as? A2ATransportError {
                    continuation.finish(throwing: transportError)
                } else {
                    continuation.finish(throwing: A2ATransportError.network(
                        message: "SSE stream error: \(error.localizedDescription)"
                    ))
                }
            }
        }

        continuation.onTermination = { _ in
            task.cancel()
        }

        return stream
    }
}
