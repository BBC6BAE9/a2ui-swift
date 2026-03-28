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

// MARK: - ChatMessage

/// A chat message exchanged between the user and the LLM backend.
///
/// Mirrors Flutter `ChatMessage`.
public struct ChatMessage: Sendable, Codable, Equatable {
    /// The role of the message author. Typically `"user"` or `"assistant"`.
    public let role: String
    /// The text content of the message.
    public let content: String

    public init(role: String, content: String) {
        self.role    = role
        self.content = content
    }
}

// MARK: - A2UITransportError

/// Errors thrown by ``A2UITransportAdapter``.
public enum A2UITransportError: Error, Equatable {
    /// ``A2UITransportAdapter/sendRequest(_:)`` was called but no `onSend` callback was provided.
    case noSendCallback
}

// MARK: - ManualSendCallback

/// A callback invoked by ``A2UITransportAdapter/sendRequest(_:)`` to deliver messages to the backend.
///
/// Mirrors Flutter `ManualSendCallback`.
public typealias ManualSendCallback = @Sendable (ChatMessage) async throws -> Void

// MARK: - A2UITransportAdapter

/// The primary high-level API for typical SwiftUI application development.
///
/// Wraps ``A2UIStreamParser`` to provide an imperative, push-based interface that is
/// easier to integrate into imperative loops.
///
/// Mirrors Flutter `A2uiTransportAdapter`.
///
/// - Use ``addChunk(_:)`` to feed text chunks from an LLM.
/// - Use ``addMessage(_:)`` to feed raw A2UI messages directly.
/// - Use ``finish()`` to signal end-of-stream and flush the internal buffer.
/// - Subscribe to ``incomingMessages`` for parsed A2UI messages.
/// - Subscribe to ``incomingText`` for plain LLM text (trimmed, non-empty).
/// - Call ``sendRequest(_:)`` to send a user message to the backend.
public final class A2UITransportAdapter: A2UITransport, Sendable {

    // MARK: - Properties

    private let _parser:              A2UIStreamParser
    private let _textContinuation:    AsyncStream<String>.Continuation
    private let _messageContinuation: AsyncStream<A2uiMessage>.Continuation
    private let _onSend:              ManualSendCallback?

    public nonisolated(unsafe) var clientCapabilities: A2uiClientCapabilities?
    public nonisolated(unsafe) var dataModelProvider: (() -> A2uiClientDataModel?)?

    /// A stream of sanitized text for the chat UI.
    ///
    /// Each emitted string is trimmed and non-empty.
    /// Mirrors Flutter `A2uiTransportAdapter.incomingText`.
    public let incomingText: AsyncStream<String>

    /// A stream of A2UI messages parsed from the input.
    ///
    /// Includes both messages parsed from text chunks and messages injected via ``addMessage(_:)``.
    /// Mirrors Flutter `A2uiTransportAdapter.incomingMessages`.
    public let incomingMessages: AsyncStream<A2uiMessage>

    // MARK: - Initialisation

    /// Creates an ``A2UITransportAdapter``.
    ///
    /// - Parameters:
    ///   - onSend: The callback to invoke when ``sendRequest(_:)`` is called.
    ///   - clientCapabilities: Optional capabilities to attach to every outgoing message.
    public init(onSend: ManualSendCallback? = nil, clientCapabilities: A2uiClientCapabilities? = nil) {
        self._onSend            = onSend
        self.clientCapabilities = clientCapabilities

        let parser = A2UIStreamParser()
        self._parser = parser

        let (textStream,    textCont) = AsyncStream<String>.makeStream()
        let (messageStream, msgCont)  = AsyncStream<A2uiMessage>.makeStream()

        self.incomingText         = textStream
        self.incomingMessages     = messageStream
        self._textContinuation    = textCont
        self._messageContinuation = msgCont

        // Route parser events to the appropriate stream.
        // Mirrors Flutter's _pipeline.listen + incomingText filter chain.
        Task {
            for await event in parser.events {
                switch event {
                case .message(let msg):
                    msgCont.yield(msg)
                case .text(let raw):
                    // Mirrors Flutter: .map((e) => e.text.trim()).where((text) => text.isNotEmpty)
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { textCont.yield(trimmed) }
                case .error:
                    // Validation errors don't surface through the adapter's public streams —
                    // same behaviour as Flutter where addError isn't forwarded to either
                    // incomingText or incomingMessages.
                    break
                }
            }
            textCont.finish()
            msgCont.finish()
        }
    }

    // MARK: - Public API

    /// Feeds a chunk of text from the LLM to the adapter.
    ///
    /// Mirrors Flutter `A2uiTransportAdapter.addChunk`.
    public func addChunk(_ text: String) async {
        await _parser.add(text)
    }

    /// Feeds a raw A2UI message directly into ``incomingMessages``, bypassing the text parser.
    ///
    /// Mirrors Flutter `A2uiTransportAdapter.addMessage`.
    public func addMessage(_ message: A2uiMessage) {
        _messageContinuation.yield(message)
    }

    /// Signals end-of-stream. Flushes the parser buffer and closes both output streams.
    ///
    /// Mirrors Flutter `A2uiTransportAdapter.flush`.
    public func finish() async {
        await _parser.finish()
        // textCont and msgCont are finished by the monitoring Task once parser.events drains.
    }

    /// Sends a ``ChatMessage`` to the backend by invoking the `onSend` callback.
    ///
    /// - Throws: ``A2UITransportError/noSendCallback`` if no callback was provided at initialisation.
    ///
    /// Mirrors Flutter `A2uiTransportAdapter.sendRequest`.
    public func sendRequest(_ message: ChatMessage) async throws {
        guard let callback = _onSend else {
            throw A2UITransportError.noSendCallback
        }
        try await callback(message)
    }

    /// Returns the current client data model from the registered `dataModelProvider`.
    public func getClientDataModel() -> A2uiClientDataModel? {
        dataModelProvider?()
    }

    /// Releases resources and closes all output streams.
    ///
    /// After calling `dispose()`, the adapter should not be used again.
    /// Mirrors Flutter `Transport.dispose()`.
    public func dispose() {
        _textContinuation.finish()
        _messageContinuation.finish()
    }
}
