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
import A2UISwiftCore

/// HTTP client that speaks the A2A JSON-RPC protocol to an A2UI-capable agent,
/// decoding v0.9 `A2uiMessage` payloads.
///
/// ```swift
/// let client = try await A2AClient.fromBaseURL(URL(string: "http://localhost:10003")!)
/// let result = try await client.sendText("Find me restaurants")
/// ```
public final class A2AClient: Sendable {

    public let endpointURL: URL
    public let agentCard: AgentCardInfo?

    private let session: URLSession

    private static let extensionHeader = "https://a2ui.org/a2a-extension/a2ui/v0.9"
    private static let a2uiMimeType = "application/json+a2ui"
    private static let standardCatalogId = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"

    public init(endpointURL: URL, timeoutInterval: TimeInterval = 120) {
        self.endpointURL = endpointURL
        self.agentCard = nil
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        self.session = URLSession(configuration: config)
    }

    private init(endpointURL: URL, agentCard: AgentCardInfo, timeoutInterval: TimeInterval) {
        self.endpointURL = endpointURL
        self.agentCard = agentCard
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        self.session = URLSession(configuration: config)
    }

    // MARK: - Factory

    public static func fromAgentCardURL(
        _ cardURL: URL,
        timeoutInterval: TimeInterval = 120
    ) async throws -> A2AClient {
        var request = URLRequest(url: cardURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(extensionHeader, forHTTPHeaderField: "X-A2A-Extensions")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw A2AError.agentCardFetchFailed(url: cardURL)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlString = json["url"] as? String,
              let endpointURL = URL(string: urlString) else {
            throw A2AError.agentCardInvalid
        }

        let card = AgentCardInfo(
            name: json["name"] as? String ?? "Unknown",
            url: urlString,
            streaming: (json["capabilities"] as? [String: Any])?["streaming"] as? Bool ?? false,
            iconUrl: json["iconUrl"] as? String,
            supportedCatalogIds: Self.extractCatalogIds(from: json)
        )

        return A2AClient(endpointURL: endpointURL, agentCard: card, timeoutInterval: timeoutInterval)
    }

    public static func fromBaseURL(
        _ baseURL: URL,
        timeoutInterval: TimeInterval = 120
    ) async throws -> A2AClient {
        let cardURL = baseURL.appendingPathComponent(".well-known/agent-card.json")
        return try await fromAgentCardURL(cardURL, timeoutInterval: timeoutInterval)
    }

    // MARK: - Public API

    private var supportedCatalogIds: [String] {
        if let card = agentCard, !card.supportedCatalogIds.isEmpty {
            var custom: [String] = []
            var standard: [String] = []
            for id in card.supportedCatalogIds {
                if id == Self.standardCatalogId { standard.append(id) } else { custom.append(id) }
            }
            return custom + standard
        }
        return [Self.standardCatalogId]
    }

    private static func extractCatalogIds(from json: [String: Any]) -> [String] {
        guard let capabilities = json["capabilities"] as? [String: Any],
              let extensions = capabilities["extensions"] as? [[String: Any]] else {
            return []
        }
        var ids: [String] = []
        for ext in extensions {
            if let params = ext["params"] as? [String: Any],
               let catalogIds = params["supportedCatalogIds"] as? [String] {
                ids.append(contentsOf: catalogIds)
            }
        }
        return ids
    }

    public func sendText(_ text: String, contextId: String? = nil) async throws -> SendResult {
        let parts: [[String: Any]] = [["kind": "text", "text": text]]
        return try await sendMessage(parts: parts, contextId: contextId)
    }

    public func sendAction(
        _ action: ResolvedAction,
        surfaceId: String,
        contextId: String? = nil
    ) async throws -> SendResult {
        return try await sendMessage(parts: makeActionParts(action, surfaceId: surfaceId), contextId: contextId)
    }

    // MARK: - Shared Helpers

    private func makeActionParts(_ action: ResolvedAction, surfaceId: String) -> [[String: Any]] {
        let userAction: [String: Any] = [
            "userAction": [
                "name": action.name,
                "actionName": action.name,
                "surfaceId": surfaceId,
                "sourceComponentId": action.sourceComponentId,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "context": action.context.mapValues { $0.toJSONValue() }
            ] as [String: Any]
        ]
        return [
            [
                "kind": "data",
                "data": userAction,
                "metadata": ["mimeType": Self.a2uiMimeType]
            ]
        ]
    }

    private func buildJSONRPCBody(
        method: String,
        parts: [[String: Any]],
        contextId: String?
    ) throws -> Data {
        var messageDict: [String: Any] = [
            "messageId": UUID().uuidString,
            "role": "user",
            "parts": parts,
            "kind": "message",
            "metadata": [
                "a2uiClientCapabilities": [
                    "supportedCatalogIds": supportedCatalogIds
                ] as [String: Any]
            ] as [String: Any]
        ]
        if let contextId { messageDict["contextId"] = contextId }

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "id": UUID().uuidString,
            "params": ["message": messageDict] as [String: Any]
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    // MARK: - Streaming API (message/stream via SSE)

    public func sendTextStream(_ text: String, contextId: String? = nil) -> AsyncThrowingStream<StreamEvent, Error> {
        let parts: [[String: Any]] = [["kind": "text", "text": text]]
        return sendMessageStream(parts: parts, contextId: contextId)
    }

    public func sendActionStream(
        _ action: ResolvedAction,
        surfaceId: String,
        contextId: String? = nil
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        return sendMessageStream(parts: makeActionParts(action, surfaceId: surfaceId), contextId: contextId)
    }

    private func sendMessageStream(
        parts: [[String: Any]],
        contextId: String?
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let jsonData = try self.buildJSONRPCBody(method: "message/stream", parts: parts, contextId: contextId)

                    var request = URLRequest(url: self.endpointURL)
                    request.httpMethod = "POST"
                    request.httpBody = jsonData
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.setValue(Self.extensionHeader, forHTTPHeaderField: "X-A2A-Extensions")
                    request.timeoutInterval = 120

                    let (bytes, response) = try await self.session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                        throw A2AError.httpError(statusCode: code, body: "SSE stream failed")
                    }

                    try await self.parseSSEStream(bytes: bytes, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func parseSSEStream<S: AsyncSequence>(
        bytes: S,
        continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    ) async throws where S.Element == UInt8 {
        var pendingDataLines: [String] = []

        for try await line in bytes.lines {
            if line.hasPrefix("data:") {
                let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if !payload.isEmpty {
                    if payload.hasPrefix("{"), let event = parseSSEEvent(payload) {
                        flushPending(&pendingDataLines, to: continuation)
                        continuation.yield(event)
                    } else {
                        pendingDataLines.append(payload)
                    }
                }
            } else if line.isEmpty {
                flushPending(&pendingDataLines, to: continuation)
            }
        }
        flushPending(&pendingDataLines, to: continuation)
    }

    private func flushPending(
        _ lines: inout [String],
        to continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    ) {
        guard !lines.isEmpty else { return }
        let dataContent = lines.joined(separator: "\n")
        lines.removeAll()
        if let event = parseSSEEvent(dataContent) {
            continuation.yield(event)
        }
    }

    private func parseSSEEvent(_ dataContent: String) -> StreamEvent? {
        guard let data = dataContent.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let event = (json["result"] as? [String: Any]) ?? json

        let taskId = event["taskId"] as? String ?? event["id"] as? String
        let contextId = event["contextId"] as? String
        let isFinal = event["final"] as? Bool ?? false

        let taskState: A2ATaskState
        var statusText: String?

        if let status = event["status"] as? [String: Any],
           let stateStr = status["state"] as? String {
            taskState = A2ATaskState(rawValue: stateStr) ?? .unknown

            if let message = status["message"] as? [String: Any],
               let parts = message["parts"] as? [[String: Any]] {
                for part in parts {
                    if let kind = part["kind"] as? String, kind == "text",
                       let text = part["text"] as? String {
                        statusText = text
                    }
                }
            }
        } else {
            taskState = .unknown
        }

        let allParts = extractParts(from: event)
        if let messages = try? decodeA2UIMessages(from: allParts), !messages.isEmpty {
            return .result(SendResult(
                messages: messages,
                taskState: taskState,
                taskId: taskId,
                contextId: contextId
            ))
        }

        if taskState != .unknown {
            return .status(state: taskState, text: statusText, taskId: taskId, contextId: contextId, isFinal: isFinal)
        }

        return nil
    }

    // MARK: - JSON-RPC Transport (message/send, non-streaming)

    private func sendMessage(parts: [[String: Any]], contextId: String?) async throws -> SendResult {
        let jsonData = try buildJSONRPCBody(method: "message/send", parts: parts, contextId: contextId)

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.extensionHeader, forHTTPHeaderField: "X-A2A-Extensions")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw A2AError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw A2AError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        return try parseResponse(from: data)
    }

    // MARK: - Response Parsing

    private func parseResponse(from data: Data) throws -> SendResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw A2AError.invalidResponse
        }

        if let error = json["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown agent error"
            throw A2AError.agentError(message: message)
        }

        guard let result = json["result"] as? [String: Any] else {
            throw A2AError.invalidResponse
        }

        let taskId = result["id"] as? String
        let contextId = result["contextId"] as? String
        let taskState: A2ATaskState
        if let status = result["status"] as? [String: Any],
           let stateStr = status["state"] as? String {
            taskState = A2ATaskState(rawValue: stateStr) ?? .unknown
        } else {
            taskState = .unknown
        }

        let parts = extractParts(from: result)
        let messages = try decodeA2UIMessages(from: parts)

        return SendResult(
            messages: messages,
            taskState: taskState,
            taskId: taskId,
            contextId: contextId
        )
    }

    /// Decode v0.9 `A2uiMessage` objects from response parts.
    private func decodeA2UIMessages(from parts: [[String: Any]]) throws -> [A2uiMessage] {
        let decoder = JSONDecoder()
        var messages: [A2uiMessage] = []

        for part in parts {
            guard let kind = part["kind"] as? String, kind == "data",
                  let metadata = part["metadata"] as? [String: Any],
                  let mimeType = metadata["mimeType"] as? String,
                  mimeType == Self.a2uiMimeType,
                  let payload = part["data"] else {
                continue
            }

            let payloadData = try JSONSerialization.data(withJSONObject: payload)

            if let arr = payload as? [[String: Any]] {
                for item in arr {
                    let itemData = try JSONSerialization.data(withJSONObject: item)
                    messages.append(try decoder.decode(A2uiMessage.self, from: itemData))
                }
            } else {
                messages.append(try decoder.decode(A2uiMessage.self, from: payloadData))
            }
        }

        return messages
    }

    private func extractParts(from result: [String: Any]) -> [[String: Any]] {
        if let status = result["status"] as? [String: Any],
           let message = status["message"] as? [String: Any],
           let parts = message["parts"] as? [[String: Any]] {
            return parts
        }
        if let artifact = result["artifact"] as? [String: Any],
           let parts = artifact["parts"] as? [[String: Any]] {
            return parts
        }
        if let message = result["message"] as? [String: Any],
           let parts = message["parts"] as? [[String: Any]] {
            return parts
        }
        if let parts = result["parts"] as? [[String: Any]] {
            return parts
        }
        return []
    }
}

// MARK: - Supporting Types

public struct SendResult: Sendable {
    public let messages: [A2uiMessage]
    public let taskState: A2ATaskState
    public let taskId: String?
    public let contextId: String?
}

public enum A2ATaskState: String, Sendable {
    case submitted
    case working
    case inputRequired = "input-required"
    case completed
    case canceled
    case failed
    case rejected
    case authRequired = "auth-required"
    case unknown
}

public enum StreamEvent: Sendable {
    case status(state: A2ATaskState, text: String?, taskId: String?, contextId: String?, isFinal: Bool)
    case result(SendResult)
}

public struct AgentCardInfo: Sendable {
    public let name: String
    public let url: String
    public let streaming: Bool
    public let iconUrl: String?
    public let supportedCatalogIds: [String]
}

// MARK: - Errors

public enum A2AError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case agentError(message: String)
    case agentCardFetchFailed(url: URL)
    case agentCardInvalid

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from A2A agent"
        case .httpError(let code, let body):
            return "HTTP \(code): \(body.prefix(200))"
        case .agentError(let message):
            return "Agent error: \(message)"
        case .agentCardFetchFailed(let url):
            return "Failed to fetch agent card from \(url)"
        case .agentCardInvalid:
            return "Agent card is missing required 'url' field"
        }
    }
}

// MARK: - AnyCodable JSON helpers

extension AnyCodable {
    func toJSONValue() -> Any {
        switch self {
        case .string(let s): return s
        case .number(let n): return n
        case .bool(let b): return b
        case .null: return NSNull()
        case .array(let arr): return arr.map { $0.toJSONValue() }
        case .dictionary(let dict): return dict.mapValues { $0.toJSONValue() }
        }
    }
}
