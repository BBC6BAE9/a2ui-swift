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

// MARK: - A2AHandler

/// A handler for intercepting and processing A2A requests and responses.
///
/// Conform to this protocol to create middleware that can modify JSON-RPC
/// requests before they are sent and responses before they are returned
/// to the caller.
///
/// Mirrors Flutter `abstract class A2AHandler` in `genui_a2a/client/a2a_handler.dart`.
///
/// ## Typical Use Cases
///
/// - **Logging**: Inspect request/response payloads for debugging.
/// - **Authentication**: Inject auth tokens into request headers or body.
/// - **Error transformation**: Map raw error responses to domain-specific errors.
///
/// ## Example
///
/// ```swift
/// struct LoggingHandler: A2AHandler {
///     func handleRequest(_ request: [String: Any]) async throws -> [String: Any] {
///         print("→ Request: \(request)")
///         return request
///     }
///
///     func handleResponse(_ response: [String: Any]) async throws -> [String: Any] {
///         print("← Response: \(response)")
///         return response
///     }
/// }
/// ```
public protocol A2AHandler: Sendable {

    /// Handles the request and can modify it before it is sent.
    ///
    /// - Parameter request: The JSON-RPC request dictionary.
    /// - Returns: The (possibly modified) request dictionary.
    func handleRequest(_ request: [String: Any]) async throws -> [String: Any]

    /// Handles the response and can modify it before it is returned to the caller.
    ///
    /// - Parameter response: The JSON-RPC response dictionary.
    /// - Returns: The (possibly modified) response dictionary.
    func handleResponse(_ response: [String: Any]) async throws -> [String: Any]
}

// MARK: - A2AHandlerPipeline

/// A pipeline for executing a series of ``A2AHandler``s.
///
/// Requests are processed **in order** (first handler → last handler),
/// while responses are processed **in reverse order** (last handler → first handler).
/// This creates a symmetric middleware stack similar to "onion" architectures.
///
/// Mirrors Flutter `class A2AHandlerPipeline` in `genui_a2a/client/a2a_handler.dart`.
///
/// ```
///  Request flow:   Handler₁ → Handler₂ → Handler₃ → [Network]
///  Response flow:  Handler₃ → Handler₂ → Handler₁ → [Caller]
/// ```
public struct A2AHandlerPipeline: Sendable {

    /// The list of handlers to execute.
    public let handlers: [any A2AHandler]

    /// Creates an ``A2AHandlerPipeline``.
    ///
    /// - Parameter handlers: The ordered list of handlers. Requests traverse
    ///   this list front-to-back; responses traverse it back-to-front.
    public init(handlers: [any A2AHandler]) {
        self.handlers = handlers
    }

    /// Executes the request handlers in order.
    ///
    /// Each handler receives the output of the previous one, forming a
    /// chain of transformations.
    ///
    /// - Parameter request: The original JSON-RPC request dictionary.
    /// - Returns: The request dictionary after all handlers have processed it.
    public func handleRequest(_ request: [String: Any]) async throws -> [String: Any] {
        var currentRequest = request
        for handler in handlers {
            currentRequest = try await handler.handleRequest(currentRequest)
        }
        return currentRequest
    }

    /// Executes the response handlers in reverse order.
    ///
    /// The last handler that processed the request is the first to process
    /// the response, maintaining a symmetric middleware stack.
    ///
    /// - Parameter response: The original JSON-RPC response dictionary.
    /// - Returns: The response dictionary after all handlers have processed it.
    public func handleResponse(_ response: [String: Any]) async throws -> [String: Any] {
        var currentResponse = response
        for handler in handlers.reversed() {
            currentResponse = try await handler.handleResponse(currentResponse)
        }
        return currentResponse
    }
}
