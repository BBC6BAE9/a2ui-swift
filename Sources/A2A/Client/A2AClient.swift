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

// MARK: - JSON-RPC Error → A2ATransportError mapping

/// Maps a JSON-RPC error dictionary to a typed ``A2ATransportError``.
///
/// Mirrors the top-level Dart `_exceptionFrom` function in
/// `genui_a2a/client/a2a_client.dart`.
///
/// A2A-specific error codes:
/// - `-32001` → task not found
/// - `-32002` → task not cancelable
/// - `-32006` → push notifications not supported
/// - `-32007` → push notification config not found
private func transportError(from error: [String: Any]) -> A2ATransportError {
    let code = error["code"] as? Int ?? 0
    let message = error["message"] as? String ?? "Unknown error"

    switch code {
    case -32001:
        return .taskNotFound(message: message)
    case -32002:
        return .taskNotCancelable(message: message)
    case -32006:
        return .pushNotificationNotSupported(message: message)
    case -32007:
        return .pushNotificationConfigNotFound(message: message)
    default:
        return .jsonRpc(code: code, message: message)
    }
}

// MARK: - A2AClient

/// A client for interacting with an A2A (Agent-to-Agent) server.
///
/// Provides methods for all the JSON-RPC calls defined in the A2A
/// specification, including message sending (single-shot and streaming),
/// task management, and push notification configuration.
///
/// Uses an ``A2ATransport`` instance to communicate with the server,
/// defaulting to ``SseTransport`` when no transport is provided.
///
/// Mirrors Dart `class A2AClient` in `genui_a2a/client/a2a_client.dart`.
///
/// ## Example
///
/// ```swift
/// let client = A2AClient(url: "http://localhost:8000")
/// let card = try await client.getAgentCard()
/// print(card.name)
/// ```
public final class A2AClient: @unchecked Sendable {

    // MARK: - Properties

    /// The base URL of the A2A server.
    public let url: String

    /// The underlying transport used for communication.
    private let transport: any A2ATransport

    /// An optional handler pipeline for intercepting requests/responses.
    private let handlerPipeline: A2AHandlerPipeline?

    /// Auto-incrementing request ID for JSON-RPC 2.0.
    private var requestId: Int = 0

    /// Lock for thread-safe `requestId` increments.
    private let lock = NSLock()

    #if canImport(os)
    private let logger = Logger(subsystem: "A2UIV09_A2A", category: "A2AClient")
    #endif

    // MARK: - Well-Known Path

    /// The well-known path for the agent card endpoint.
    public static let agentCardPath = "/.well-known/agent-card.json"

    // MARK: - Initialisation

    /// Creates an ``A2AClient`` instance.
    ///
    /// - Parameters:
    ///   - url: The base URL of the A2A server (e.g. `http://localhost:8000`).
    ///   - transport: An optional ``A2ATransport``. If omitted, an ``SseTransport``
    ///     is created using the provided `url`.
    ///   - handlers: An optional list of ``A2AHandler``s to form a pipeline for
    ///     intercepting requests and responses.
    public init(
        url: String,
        transport: (any A2ATransport)? = nil,
        handlers: [any A2AHandler] = []
    ) {
        self.url = url
        self.transport = transport ?? SseTransport(url: url)
        self.handlerPipeline = handlers.isEmpty ? nil : A2AHandlerPipeline(handlers: handlers)
    }

    // MARK: - Factory

    /// Creates an ``A2AClient`` by fetching an ``AgentCard`` from a URL and
    /// selecting the best transport.
    ///
    /// Fetches the agent card from `agentCardUrl`, determines the best transport
    /// based on the card's capabilities (preferring streaming if available),
    /// and returns a new ``A2AClient`` instance.
    ///
    /// - Parameters:
    ///   - agentCardUrl: The full URL from which to fetch the agent card.
    ///   - handlers: An optional list of ``A2AHandler``s.
    /// - Returns: A configured ``A2AClient``.
    public static func fromAgentCardUrl(
        _ agentCardUrl: String,
        handlers: [any A2AHandler] = []
    ) async throws -> A2AClient {
        let tempTransport = HttpTransport(url: agentCardUrl)
        let responseDict = try await tempTransport.get(path: "")
        let agentCard = try decodeFromDict(AgentCard.self, dict: responseDict)

        let transport: any A2ATransport
        if agentCard.capabilities.streaming == true {
            transport = SseTransport(url: agentCard.url)
        } else {
            transport = HttpTransport(url: agentCard.url)
        }

        return A2AClient(url: agentCard.url, transport: transport, handlers: handlers)
    }

    // MARK: - Agent Card

    /// Fetches the public agent card from the server.
    ///
    /// The agent card contains metadata about the agent, such as its capabilities
    /// and security schemes. Requests the card from ``agentCardPath``.
    ///
    /// - Returns: An ``AgentCard`` object.
    /// - Throws: ``A2ATransportError`` if the request fails or the response is invalid.
    public func getAgentCard() async throws -> AgentCard {
        log("Fetching agent card...")
        let response = try await transport.get(path: Self.agentCardPath)
        logFine("Received agent card")
        return try decodeFromDict(AgentCard.self, dict: response)
    }

    /// Fetches the authenticated extended agent card from the server.
    ///
    /// Retrieves a potentially more detailed ``AgentCard`` available only to
    /// authenticated users, including an `Authorization` header with the
    /// provided Bearer `token`.
    ///
    /// - Parameter token: The Bearer token for authentication.
    /// - Returns: An ``AgentCard`` object.
    /// - Throws: ``A2ATransportError`` if the request fails or the response is invalid.
    public func getAuthenticatedExtendedCard(_ token: String) async throws -> AgentCard {
        log("Fetching authenticated agent card...")
        let response = try await transport.get(
            path: Self.agentCardPath,
            headers: ["Authorization": "Bearer \(token)"]
        )
        logFine("Received authenticated agent card")
        return try decodeFromDict(AgentCard.self, dict: response)
    }

    // MARK: - message/send

    /// Sends a message to the agent for a single-shot interaction via
    /// `message/send`.
    ///
    /// The server processes the message and returns a result. The returned
    /// ``A2ATask`` contains the initial state of the task.
    ///
    /// For long-running operations, consider ``messageStream(_:)`` or polling
    /// with ``getTask(_:)``.
    ///
    /// - Parameter message: The ``A2AMessage`` to send.
    /// - Returns: The initial ``A2ATask`` state.
    /// - Throws: ``A2ATransportError`` if the server returns a JSON-RPC error.
    public func messageSend(_ message: A2AMessage) async throws -> A2ATask {
        log("Sending message: \(message.messageId)")

        var params: [String: Any] = ["message": try encodeToDict(message)]
        if let extensions = message.extensions {
            params["extensions"] = extensions
        }

        var headers: [String: String] = [:]
        if let extensions = message.extensions {
            headers["X-A2A-Extensions"] = extensions.joined(separator: ",")
        }

        let request = buildRequest(method: "message/send", params: params)
        let processed = try await applyRequestHandlers(request)
        let response = try await transport.send(processed, headers: headers)
        let handled = try await applyResponseHandlers(response)

        logFine("Received response from message/send")
        try throwIfError(handled)

        guard let result = handled["result"] as? [String: Any] else {
            throw A2ATransportError.parsing(message: "Missing 'result' in message/send response")
        }
        return try decodeFromDict(A2ATask.self, dict: result)
    }

    // MARK: - message/stream

    /// Sends a message to the agent and subscribes to real-time updates via
    /// `message/stream`.
    ///
    /// The agent can send multiple updates over time. The returned stream
    /// emits ``A2AEvent`` objects as they are received, typically via SSE.
    ///
    /// - Parameter message: The ``A2AMessage`` to send.
    /// - Returns: An `AsyncThrowingStream` of ``A2AEvent`` objects.
    public func messageStream(_ message: A2AMessage) -> AsyncThrowingStream<A2AEvent, Error> {
        log("Sending message for stream: \(message.messageId)")

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var params: [String: Any] = [
                        "configuration": NSNull(),
                        "metadata": NSNull(),
                        "message": try encodeToDict(message),
                    ]
                    if let extensions = message.extensions {
                        params["extensions"] = extensions
                    }

                    var headers: [String: String] = [:]
                    if let extensions = message.extensions {
                        headers["X-A2A-Extensions"] = extensions.joined(separator: ",")
                    }

                    let request = self.buildRequest(method: "message/stream", params: params)
                    let processed = try await self.applyRequestHandlers(request)
                    let stream = self.transport.sendStream(processed, headers: headers)

                    for try await data in stream {
                        let handled = try await self.applyResponseHandlers(data)
                        self.logFine("Received event from stream")

                        if handled["error"] != nil {
                            guard let errorDict = handled["error"] as? [String: Any] else {
                                continuation.finish(throwing: A2ATransportError.parsing(
                                    message: "Malformed 'error' in stream event"
                                ))
                                return
                            }
                            continuation.finish(throwing: transportError(from: errorDict))
                            return
                        }

                        if let kind = handled["kind"] as? String {
                            if kind == "task" {
                                // Server sent a full task object — convert to status update event
                                let task = try decodeFromDict(A2ATask.self, dict: handled)
                                let event = A2AEvent.statusUpdate(
                                    taskId: task.id,
                                    contextId: task.contextId,
                                    status: task.status,
                                    isFinal: false
                                )
                                continuation.yield(event)
                            } else {
                                let event = try decodeFromDict(A2AEvent.self, dict: handled)
                                continuation.yield(event)
                            }
                        }
                        // Events without "kind" are silently skipped (matches Dart behavior)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - tasks/get

    /// Retrieves the current state of a task from the server using `tasks/get`.
    ///
    /// - Parameter taskId: The unique identifier of the task.
    /// - Returns: The current ``A2ATask`` state.
    /// - Throws: ``A2ATransportError`` if the server returns a JSON-RPC error.
    public func getTask(_ taskId: String) async throws -> A2ATask {
        log("Getting task: \(taskId)")

        let request = buildRequest(method: "tasks/get", params: ["id": taskId])
        let processed = try await applyRequestHandlers(request)
        let response = try await transport.send(processed)
        let handled = try await applyResponseHandlers(response)

        logFine("Received response from tasks/get")
        try throwIfError(handled)

        guard let result = handled["result"] as? [String: Any] else {
            throw A2ATransportError.parsing(message: "Missing 'result' in tasks/get response")
        }
        return try decodeFromDict(A2ATask.self, dict: result)
    }

    // MARK: - tasks/list

    /// Retrieves a list of tasks from the server using `tasks/list`.
    ///
    /// - Parameter params: Optional ``ListTasksParams`` to filter, sort, and paginate.
    /// - Returns: A ``ListTasksResult`` containing the task list and pagination info.
    /// - Throws: ``A2ATransportError`` if the server returns a JSON-RPC error.
    public func listTasks(_ params: ListTasksParams? = nil) async throws -> ListTasksResult {
        log("Listing tasks...")

        let rpcParams: [String: Any] = params.map { try! encodeToDict($0) } ?? [:]
        let request = buildRequest(method: "tasks/list", params: rpcParams)
        let processed = try await applyRequestHandlers(request)
        let response = try await transport.send(processed)
        let handled = try await applyResponseHandlers(response)

        logFine("Received response from tasks/list")
        try throwIfError(handled)

        guard let result = handled["result"] as? [String: Any] else {
            throw A2ATransportError.parsing(message: "Missing 'result' in tasks/list response")
        }
        return try decodeFromDict(ListTasksResult.self, dict: result)
    }

    // MARK: - tasks/cancel

    /// Requests cancellation of an ongoing task using `tasks/cancel`.
    ///
    /// Success is not guaranteed — the task may have already completed or
    /// may not support cancellation.
    ///
    /// - Parameter taskId: The unique identifier of the task to cancel.
    /// - Returns: The updated ``A2ATask`` state after the cancellation request.
    /// - Throws: ``A2ATransportError`` if the server returns a JSON-RPC error.
    public func cancelTask(_ taskId: String) async throws -> A2ATask {
        log("Canceling task: \(taskId)")

        let request = buildRequest(method: "tasks/cancel", params: ["id": taskId])
        let processed = try await applyRequestHandlers(request)
        let response = try await transport.send(processed)
        let handled = try await applyResponseHandlers(response)

        logFine("Received response from tasks/cancel")
        try throwIfError(handled)

        guard let result = handled["result"] as? [String: Any] else {
            throw A2ATransportError.parsing(message: "Missing 'result' in tasks/cancel response")
        }
        return try decodeFromDict(A2ATask.self, dict: result)
    }

    // MARK: - tasks/resubscribe

    /// Resubscribes to an SSE stream for an ongoing task using
    /// `tasks/resubscribe`.
    ///
    /// Allows a client to reconnect to the event stream after a network
    /// interruption. Subsequent ``A2AEvent``s for the task will be emitted.
    ///
    /// - Parameter taskId: The unique identifier of the task to resubscribe to.
    /// - Returns: An `AsyncThrowingStream` of ``A2AEvent`` objects.
    public func resubscribeToTask(_ taskId: String) -> AsyncThrowingStream<A2AEvent, Error> {
        log("Resubscribing to task: \(taskId)")

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = self.buildRequest(
                        method: "tasks/resubscribe",
                        params: ["id": taskId]
                    )
                    let processed = try await self.applyRequestHandlers(request)
                    let stream = self.transport.sendStream(processed)

                    for try await data in stream {
                        let handled = try await self.applyResponseHandlers(data)
                        self.logFine("Received event from resubscribe stream")

                        if handled["error"] != nil {
                            guard let errorDict = handled["error"] as? [String: Any] else {
                                continuation.finish(throwing: A2ATransportError.parsing(
                                    message: "Malformed 'error' in resubscribe event"
                                ))
                                return
                            }
                            throw transportError(from: errorDict)
                        }
                        let event = try decodeFromDict(A2AEvent.self, dict: handled)
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - tasks/pushNotificationConfig/set

    /// Sets or updates the push notification configuration for a task.
    ///
    /// - Parameter config: The ``TaskPushNotificationConfig`` to set.
    /// - Returns: The updated ``TaskPushNotificationConfig``.
    /// - Throws: ``A2ATransportError`` if the server returns a JSON-RPC error.
    public func setPushNotificationConfig(
        _ config: TaskPushNotificationConfig
    ) async throws -> TaskPushNotificationConfig {
        log("Setting push notification config for task: \(config.taskId)")

        let params = try encodeToDict(config)
        let request = buildRequest(method: "tasks/pushNotificationConfig/set", params: params)
        let processed = try await applyRequestHandlers(request)
        let response = try await transport.send(processed)
        let handled = try await applyResponseHandlers(response)

        logFine("Received response from tasks/pushNotificationConfig/set")
        try throwIfError(handled)

        guard let result = handled["result"] as? [String: Any] else {
            throw A2ATransportError.parsing(
                message: "Missing 'result' in pushNotificationConfig/set response"
            )
        }
        return try decodeFromDict(TaskPushNotificationConfig.self, dict: result)
    }

    // MARK: - tasks/pushNotificationConfig/get

    /// Retrieves a specific push notification configuration for a task.
    ///
    /// - Parameters:
    ///   - taskId: The unique identifier of the task.
    ///   - configId: The unique identifier of the push notification config.
    /// - Returns: The requested ``TaskPushNotificationConfig``.
    /// - Throws: ``A2ATransportError`` if the server returns a JSON-RPC error.
    public func getPushNotificationConfig(
        taskId: String,
        configId: String
    ) async throws -> TaskPushNotificationConfig {
        log("Getting push notification config \(configId) for task: \(taskId)")

        let params: [String: Any] = ["id": taskId, "pushNotificationConfigId": configId]
        let request = buildRequest(method: "tasks/pushNotificationConfig/get", params: params)
        let processed = try await applyRequestHandlers(request)
        let response = try await transport.send(processed)
        let handled = try await applyResponseHandlers(response)

        logFine("Received response from tasks/pushNotificationConfig/get")
        try throwIfError(handled)

        guard let result = handled["result"] as? [String: Any] else {
            throw A2ATransportError.parsing(
                message: "Missing 'result' in pushNotificationConfig/get response"
            )
        }
        return try decodeFromDict(TaskPushNotificationConfig.self, dict: result)
    }

    // MARK: - tasks/pushNotificationConfig/list

    /// Lists all push notification configurations for a given task.
    ///
    /// - Parameter taskId: The unique identifier of the task.
    /// - Returns: A list of ``PushNotificationConfig`` objects.
    /// - Throws: ``A2ATransportError`` if the server returns a JSON-RPC error.
    public func listPushNotificationConfigs(
        taskId: String
    ) async throws -> [PushNotificationConfig] {
        log("Listing push notification configs for task: \(taskId)")

        let params: [String: Any] = ["id": taskId]
        let request = buildRequest(method: "tasks/pushNotificationConfig/list", params: params)
        let processed = try await applyRequestHandlers(request)
        let response = try await transport.send(processed)
        let handled = try await applyResponseHandlers(response)

        logFine("Received response from tasks/pushNotificationConfig/list")
        try throwIfError(handled)

        guard let result = handled["result"] as? [String: Any],
              let configs = result["configs"] as? [[String: Any]]
        else {
            throw A2ATransportError.parsing(
                message: "Missing 'result.configs' in pushNotificationConfig/list response"
            )
        }

        return try configs.map { try decodeFromDict(PushNotificationConfig.self, dict: $0) }
    }

    // MARK: - tasks/pushNotificationConfig/delete

    /// Deletes a specific push notification configuration for a task.
    ///
    /// - Parameters:
    ///   - taskId: The unique identifier of the task.
    ///   - configId: The unique identifier of the push notification config to delete.
    /// - Throws: ``A2ATransportError`` if the server returns a JSON-RPC error.
    public func deletePushNotificationConfig(
        taskId: String,
        configId: String
    ) async throws {
        log("Deleting push notification config \(configId) for task: \(taskId)")

        let params: [String: Any] = ["id": taskId, "pushNotificationConfigId": configId]
        let request = buildRequest(method: "tasks/pushNotificationConfig/delete", params: params)
        let processed = try await applyRequestHandlers(request)
        let response = try await transport.send(processed)
        let handled = try await applyResponseHandlers(response)

        logFine("Received response from tasks/pushNotificationConfig/delete")
        try throwIfError(handled)
    }

    // MARK: - close

    /// Closes the underlying transport connection.
    ///
    /// Should be called when the client is no longer needed to release resources.
    public func close() {
        transport.close()
    }

    // MARK: - Private Helpers

    /// Generates the next auto-incrementing JSON-RPC request ID (thread-safe).
    private func nextRequestId() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let id = requestId
        requestId += 1
        return id
    }

    /// Builds a JSON-RPC 2.0 request dictionary.
    private func buildRequest(method: String, params: [String: Any]) -> [String: Any] {
        return [
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": nextRequestId(),
        ]
    }

    /// Applies the handler pipeline to a request, if configured.
    private func applyRequestHandlers(_ request: [String: Any]) async throws -> [String: Any] {
        guard let pipeline = handlerPipeline else { return request }
        return try await pipeline.handleRequest(request)
    }

    /// Applies the handler pipeline to a response, if configured.
    private func applyResponseHandlers(_ response: [String: Any]) async throws -> [String: Any] {
        guard let pipeline = handlerPipeline else { return response }
        return try await pipeline.handleResponse(response)
    }

    /// Throws an ``A2ATransportError`` if the response contains an `error` key.
    private func throwIfError(_ response: [String: Any]) throws {
        guard let errorDict = response["error"] as? [String: Any] else { return }
        throw transportError(from: errorDict)
    }

    // MARK: - Logging

    private func log(_ message: String) {
        #if canImport(os)
        logger.info("\(message, privacy: .public)")
        #endif
    }

    private func logFine(_ message: String) {
        #if canImport(os)
        logger.debug("\(message, privacy: .public)")
        #endif
    }
}

// MARK: - Codable ↔ [String: Any] bridging

/// Encodes a `Codable` value into a `[String: Any]` dictionary.
///
/// Uses `JSONEncoder` → `JSONSerialization` round-trip since there is no
/// direct Codable → Dictionary API in Foundation.
private func encodeToDict<T: Encodable>(_ value: T) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw A2ATransportError.parsing(message: "Failed to encode \(T.self) to dictionary")
    }
    return dict
}

/// Decodes a `[String: Any]` dictionary into a `Codable` value.
///
/// Uses `JSONSerialization` → `JSONDecoder` round-trip.
private func decodeFromDict<T: Decodable>(_ type: T.Type, dict: [String: Any]) throws -> T {
    let data = try JSONSerialization.data(withJSONObject: dict)
    return try JSONDecoder().decode(T.self, from: data)
}
