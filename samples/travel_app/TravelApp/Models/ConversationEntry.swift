// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import Primitives
/// A UI-layer conversation entry that wraps `Primitives.ChatMessage`.
///
/// Mirrors Flutter's pattern where the message list uses `ChatMessage` from
/// `genai_primitives`, with additional UI-specific state like loading indicators
/// and surface ID references managed at the presentation layer.
struct ConversationEntry: Identifiable {
    let id = UUID()

    /// The underlying `Primitives.ChatMessage`, if this entry represents
    /// a real message (user text, model text, or model surface).
    /// `nil` for pure UI states like loading indicators.
    let message: ChatMessage?

    /// Surface IDs to render from the shared SurfaceManager.
    /// Matches Flutter's `UiPart` pattern where surfaces are referenced by ID.
    var surfaceIds: [String]?

    /// Whether this entry represents a loading/thinking state.
    var isLoading: Bool

    /// Status text shown during loading (e.g. "Thinking...", "Working...").
    var statusText: String?

    // MARK: - Convenience accessors

    /// The role of this entry, derived from the underlying message.
    /// Defaults to `.model` for loading entries.
    var role: ChatMessageRole {
        message?.role ?? .model
    }

    /// The text content of the underlying message, if any.
    /// Trims leading/trailing whitespace so LLM responses that start with
    /// newlines don't produce blank space at the top of message bubbles.
    var text: String? {
        guard let message else { return nil }
        let t = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    // MARK: - Factory methods

    /// Creates a user text entry.
    static func user(_ text: String) -> ConversationEntry {
        ConversationEntry(
            message: .user(text),
            isLoading: false
        )
    }

    /// Creates a model text entry.
    static func agent(_ text: String) -> ConversationEntry {
        ConversationEntry(
            message: .model(text),
            isLoading: false
        )
    }

    /// Creates a model entry that renders surfaces by ID from the shared SurfaceManager.
    static func agentSurface(ids: [String]) -> ConversationEntry {
        ConversationEntry(
            message: ChatMessage(role: .model),
            surfaceIds: ids,
            isLoading: false
        )
    }

    /// Creates a loading indicator entry.
    static func loading(statusText: String? = "Thinking...") -> ConversationEntry {
        ConversationEntry(
            message: nil,
            isLoading: true,
            statusText: statusText
        )
    }
}
