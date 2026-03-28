// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import v_09

/// Abstraction over agent communication.
protocol TravelTransport: AnyObject {
    var supportsStreaming: Bool { get set }
    func sendText(_ text: String, contextId: String?) async throws -> TransportResponse
    func sendAction(_ action: ResolvedAction, surfaceId: String, contextId: String?) async throws -> TransportResponse
    func sendTextStream(_ text: String, contextId: String?) -> AsyncThrowingStream<StreamEvent, Error>?
    func sendActionStream(_ action: ResolvedAction, surfaceId: String, contextId: String?) -> AsyncThrowingStream<StreamEvent, Error>?
}

/// Response from a non-streaming transport call.
struct TransportResponse {
    let messages: [A2uiMessage]
    let contextId: String?
    /// Optional plain text from the model when no A2UI messages were generated.
    var textResponse: String?
}

/// Events emitted by the streaming transport API.
enum StreamEvent: Sendable {
    /// A real-time text chunk from the model (mirrors Flutter's textResponseStream chunks).
    case textChunk(String)
    /// Intermediate status update (tool calls in progress, etc.).
    case status(state: String, text: String?, taskId: String?, contextId: String?, isFinal: Bool)
    /// Final result containing A2UI messages and optional full text.
    case result(TransportResponse)
}
