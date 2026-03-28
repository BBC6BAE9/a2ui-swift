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

// MARK: - A2ATransport

/// Defines the contract for communication between an ``A2AClient`` and an A2A server.
///
/// Implementations of this protocol handle the low-level details of sending
/// requests and receiving responses, potentially supporting different protocols
/// like HTTP, SSE, WebSockets, etc.
///
/// Mirrors Flutter `abstract class Transport` in `genui_a2a/client/transport.dart`.
///
/// ## Two-Layer Architecture
///
/// This is the **network-layer** transport abstraction (A2A protocol level).
/// It handles raw JSON-RPC request/response exchange.
///
/// The **UI-layer** transport abstraction is ``A2UITransport`` (GenUI level),
/// which deals with parsed A2UI messages and text streams.
public protocol A2ATransport: Sendable {

    /// Optional additional headers to be added to every request.
    ///
    /// Typically used for authentication tokens or API keys.
    var authHeaders: [String: String] { get }

    /// Fetches a resource from the server using an HTTP GET request.
    ///
    /// This method is typically used for non-RPC interactions, such as retrieving
    /// the agent card from `/.well-known/agent-card.json`.
    ///
    /// - Parameters:
    ///   - path: The path appended to the base URL of the transport.
    ///   - headers: Optional additional headers for this request.
    /// - Returns: The JSON-decoded response body.
    /// - Throws: ``A2ATransportError`` if the request fails.
    func get(path: String, headers: [String: String]) async throws -> [String: Any]

    /// Sends a single JSON-RPC request to the server, expecting a single response.
    ///
    /// The `request` dictionary must conform to the JSON-RPC 2.0 specification.
    ///
    /// - Parameters:
    ///   - request: The JSON-RPC request body.
    ///   - path: The endpoint path (defaults to empty string, appended to base URL).
    ///   - headers: Optional additional headers for this request.
    /// - Returns: The JSON-decoded response body.
    /// - Throws: ``A2ATransportError`` if the request fails.
    func send(_ request: [String: Any], path: String, headers: [String: String]) async throws -> [String: Any]

    /// Sends a JSON-RPC request to the server and initiates a stream of responses.
    ///
    /// This method is used for long-lived connections where the server can push
    /// multiple messages to the client, such as Server-Sent Events (SSE).
    ///
    /// - Parameters:
    ///   - request: The JSON-RPC request body.
    ///   - headers: Optional additional headers for this request.
    /// - Returns: An `AsyncThrowingStream` of JSON objects received from the server.
    func sendStream(_ request: [String: Any], headers: [String: String]) -> AsyncThrowingStream<[String: Any], Error>

    /// Closes the transport and releases any underlying resources.
    ///
    /// Implementations should handle graceful shutdown of connections.
    func close()
}

// MARK: - Default parameter values via extension

extension A2ATransport {

    /// Convenience overload with default empty headers.
    public func get(path: String) async throws -> [String: Any] {
        try await get(path: path, headers: [:])
    }

    /// Convenience overload with default path and headers.
    public func send(_ request: [String: Any]) async throws -> [String: Any] {
        try await send(request, path: "", headers: [:])
    }

    /// Convenience overload with default path.
    public func send(_ request: [String: Any], path: String) async throws -> [String: Any] {
        try await send(request, path: path, headers: [:])
    }

    /// Convenience overload with default headers.
    public func send(_ request: [String: Any], headers: [String: String]) async throws -> [String: Any] {
        try await send(request, path: "", headers: headers)
    }

    /// Convenience overload with default headers.
    public func sendStream(_ request: [String: Any]) -> AsyncThrowingStream<[String: Any], Error> {
        sendStream(request, headers: [:])
    }
}
