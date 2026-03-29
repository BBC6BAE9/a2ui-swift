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

// MARK: - A2UITransport

/// The **UI-layer** transport abstraction for A2UI message exchange.
///
/// Unifies the concept of incoming streams (text chunks and A2UI messages)
/// and outgoing requests. This is the interface consumed by the rendering
/// layer (e.g. ``MessageProcessor``, ``SurfaceViewModel``).
///
/// Mirrors Flutter `abstract interface class Transport`
/// in `genui/interfaces/transport.dart`.
///
/// ## Two-Layer Architecture
///
/// ```
/// ┌─────────────────────────────────────────────┐
/// │  UI Layer (GenUI)                           │
/// │  protocol A2UITransport                     │
/// │    ├─ incomingText: AsyncStream<String>      │
/// │    ├─ incomingMessages: AsyncStream<…>       │
/// │    ├─ sendRequest(_:)                        │
/// │    └─ dispose()                              │
/// ├─────────────────────────────────────────────┤
/// │  Network Layer (A2A)                        │
/// │  protocol A2ATransport                      │
/// │    ├─ get(path:headers:)                     │
/// │    ├─ send(_:path:headers:)                  │
/// │    ├─ sendStream(_:headers:)                 │
/// │    └─ close()                                │
/// └─────────────────────────────────────────────┘
/// ```
///
/// - ``A2ATransport``: Network-level. Handles raw JSON-RPC request/response.
/// - ``A2UITransport`` (this protocol): UI-level. Handles parsed A2UI
///   messages and text streams for the rendering layer.
///
/// ``A2UITransportAdapter`` is the primary concrete implementation.
public protocol A2UITransport: Sendable {

    /// A stream of sanitized text chunks from the AI service.
    ///
    /// Used for "streaming" responses where text is built up over time.
    /// Each emitted string is trimmed and non-empty.
    var incomingText: AsyncStream<String> { get }

    /// A stream of parsed ``A2uiMessage`` values from the AI service.
    var incomingMessages: AsyncStream<A2uiMessage> { get }

    /// Sends a user message to the AI backend.
    ///
    /// - Parameter message: The ``ChatMessage`` to send.
    /// - Throws: ``A2UITransportError/noSendCallback`` or a transport-specific error.
    func sendRequest(_ message: ChatMessage) async throws

    /// Releases any resources used by this transport.
    ///
    /// After calling `dispose()`, the transport should not be used again.
    func dispose()
}
