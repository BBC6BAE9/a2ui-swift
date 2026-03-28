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

// MARK: - HttpTransport

/// An implementation of ``A2ATransport`` using standard HTTP requests via `URLSession`.
///
/// Suitable for single-shot GET requests and POST requests for non-streaming
/// JSON-RPC calls. Does **not** support ``sendStream(_:headers:)`` — use
/// ``SseTransport`` for streaming.
///
/// Mirrors Flutter `HttpTransport` in `genui_a2a/client/http_transport.dart`.
open class HttpTransport: A2ATransport, @unchecked Sendable {

    // MARK: - Properties

    /// The base URL of the A2A server.
    public let url: String

    /// Additional headers added to every request (e.g. auth tokens).
    public let authHeaders: [String: String]

    /// The `URLSession` used for HTTP requests. Replaceable for testing.
    public let session: URLSession

    #if canImport(os)
    let logger = Logger(subsystem: "A2UIV09_A2A", category: "HttpTransport")
    #endif

    // MARK: - Initialisation

    /// Creates an ``HttpTransport`` instance.
    ///
    /// - Parameters:
    ///   - url: The base URL of the A2A server.
    ///   - authHeaders: Optional additional headers for every request.
    ///   - session: Optional `URLSession` for custom configurations or testing.
    public init(
        url: String,
        authHeaders: [String: String] = [:],
        session: URLSession = .shared
    ) {
        self.url = url
        self.authHeaders = authHeaders
        self.session = session
    }

    // MARK: - A2ATransport conformance

    public func get(path: String, headers: [String: String] = [:]) async throws -> [String: Any] {
        guard let requestURL = URL(string: "\(url)\(path)") else {
            throw A2ATransportError.network(message: "Invalid URL: \(url)\(path)")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"

        // Merge headers: authHeaders first, then per-request headers (override).
        let allHeaders = authHeaders.merging(headers) { _, new in new }
        for (key, value) in allHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if canImport(os)
        logger.debug("Sending GET request to \(requestURL)")
        #endif

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw A2ATransportError.network(message: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw A2ATransportError.network(message: "Non-HTTP response received.")
        }

        if httpResponse.statusCode >= 400 {
            throw A2ATransportError.http(
                statusCode: httpResponse.statusCode,
                reason: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }

        return try parseJSON(data)
    }

    public func send(
        _ request: [String: Any],
        path: String = "",
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        guard let requestURL = URL(string: "\(url)\(path)") else {
            throw A2ATransportError.network(message: "Invalid URL: \(url)\(path)")
        }

        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "POST"

        // Merge headers: Content-Type + authHeaders + per-request headers.
        var allHeaders = ["Content-Type": "application/json"]
        allHeaders.merge(authHeaders) { _, new in new }
        allHeaders.merge(headers) { _, new in new }
        for (key, value) in allHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: request)
        } catch {
            throw A2ATransportError.parsing(message: "Failed to encode request: \(error.localizedDescription)")
        }

        #if canImport(os)
        logger.debug("Sending POST request to \(requestURL)")
        #endif

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw A2ATransportError.network(message: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw A2ATransportError.network(message: "Non-HTTP response received.")
        }

        if httpResponse.statusCode >= 400 {
            throw A2ATransportError.http(
                statusCode: httpResponse.statusCode,
                reason: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }

        return try parseJSON(data)
    }

    /// Not supported by ``HttpTransport``. Use ``SseTransport`` for streaming.
    ///
    /// - Throws: ``A2ATransportError/unsupportedOperation(message:)``
    public func sendStream(
        _ request: [String: Any],
        headers: [String: String] = [:]
    ) -> AsyncThrowingStream<[String: Any], Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: A2ATransportError.unsupportedOperation(
                message: "Streaming is not supported by HttpTransport. Use SseTransport instead."
            ))
        }
    }

    public func close() {
        // URLSession.shared should not be invalidated.
        // If a custom session was provided, the caller is responsible for its lifecycle.
    }

    // MARK: - Helpers

    /// Parses JSON data into a dictionary.
    func parseJSON(_ data: Data) throws -> [String: Any] {
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw A2ATransportError.parsing(message: error.localizedDescription)
        }
        guard let dict = parsed as? [String: Any] else {
            throw A2ATransportError.parsing(message: "Response is not a JSON object.")
        }
        return dict
    }
}
