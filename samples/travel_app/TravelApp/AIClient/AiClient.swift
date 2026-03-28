//
//  AiClient.swift
//  GenUI
//
//  Created by huanghong on 3/28/26.
//

import Foundation
import v_09
import Primitives

/// An abstract protocol for AI clients.
///
/// Defines the contract for communicating with an AI service, regardless of
/// the implementation (e.g., Google Generative AI, fake client).
///
/// Mirrors Flutter's `AiClient` from `ai_client/ai_client.dart`.
protocol AiClient: AnyObject {
    /// An `AsyncStream` of `A2uiMessage`s received from the AI.
    var a2uiMessageStream: AsyncStream<A2uiMessage> { get }

    /// An `AsyncStream` of text chunks received from the AI.
    var textResponseStream: AsyncStream<String> { get }

    /// Sends a message to the AI service.
    ///
    /// - Parameters:
    ///   - message: The new message to send.
    ///   - history: The history of the conversation so far.
    ///   - clientDataModel: Key-value data model to include in context.
    func sendRequest(
        _ message: Primitives.ChatMessage,
        history: [Primitives.ChatMessage]?,
        clientDataModel: [String: Any]?
    ) async throws

    /// Dispose of resources.
    func dispose()
}
