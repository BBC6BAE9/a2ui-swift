// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/// Events related to the AI generation process.
///
/// Mirrors Flutter's event classes from `ai_client/ai_generation_events.dart`.
enum AiGenerationEvent {
    /// Fired when a tool execution starts.
    case toolStart(toolName: String, args: [String: Any])

    /// Fired when a tool execution completes.
    case toolEnd(toolName: String, result: [String: Any], duration: TimeInterval)

    /// Fired to report token usage.
    case tokenUsage(inputTokens: Int, outputTokens: Int)
}
