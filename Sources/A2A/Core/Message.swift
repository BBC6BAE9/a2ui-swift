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

// MARK: - Role

/// Identifies the sender of an ``A2AMessage``.
///
/// Mirrors Dart `Role` enum in `a2a/core/message.dart`.
public enum Role: String, Codable, Sendable, Equatable {
    /// The message originated from the user (i.e., the A2A client).
    case user

    /// The message originated from the agent (i.e., the A2A server).
    case agent
}

// MARK: - A2AMessage

/// Represents a single communication exchange within an A2A interaction.
///
/// Messages are the fundamental unit of communication, used for sending
/// instructions, prompts, data, and replies between a client and an agent.
///
/// Named `A2AMessage` to avoid conflict with SwiftUI `Message`.
///
/// Mirrors Dart `Message` in `a2a/core/message.dart`.
public struct A2AMessage: Codable, Sendable, Equatable {

    /// Specifies the sender of the message.
    public let role: Role

    /// A list of content ``Part``s that make up the message body.
    public let parts: [Part]

    /// Optional metadata for extensions.
    public let metadata: JSONObject?

    /// Optional list of URIs for extensions that are relevant to this message.
    public let extensions: [String]?

    /// Optional list of other task IDs that this message references.
    public let referenceTaskIds: [String]?

    /// A unique identifier for this message, typically a UUID.
    public let messageId: String

    /// The ID of the task this message belongs to.
    public let taskId: String?

    /// An identifier used to group related messages and tasks.
    public let contextId: String?

    /// The type discriminator for this object, always "message".
    public let kind: String

    public init(
        role: Role,
        parts: [Part],
        metadata: JSONObject? = nil,
        extensions: [String]? = nil,
        referenceTaskIds: [String]? = nil,
        messageId: String,
        taskId: String? = nil,
        contextId: String? = nil,
        kind: String = "message"
    ) {
        self.role = role
        self.parts = parts
        self.metadata = metadata
        self.extensions = extensions
        self.referenceTaskIds = referenceTaskIds
        self.messageId = messageId
        self.taskId = taskId
        self.contextId = contextId
        self.kind = kind
    }
}
