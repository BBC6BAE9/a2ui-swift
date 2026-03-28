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

// MARK: - AgentCapabilities

/// Describes the optional features and extensions an A2A agent supports.
///
/// This struct is part of the ``AgentCard`` and allows an agent to advertise
/// its capabilities to clients, such as support for streaming, push
/// notifications, and custom protocol extensions.
///
/// Mirrors Dart `AgentCapabilities` in `a2a/core/agent_capabilities.dart`.
public struct AgentCapabilities: Codable, Sendable, Equatable {

    /// Indicates if the agent supports streaming responses, typically via
    /// Server-Sent Events (SSE).
    public let streaming: Bool?

    /// Indicates if the agent supports sending push notifications for
    /// asynchronous task updates to a client-specified endpoint.
    public let pushNotifications: Bool?

    /// Indicates if the agent maintains and can provide a history of state
    /// transitions for tasks.
    public let stateTransitionHistory: Bool?

    /// A list of non-standard protocol extensions supported by the agent.
    public let extensions: [AgentExtension]?

    public init(
        streaming: Bool? = nil,
        pushNotifications: Bool? = nil,
        stateTransitionHistory: Bool? = nil,
        extensions: [AgentExtension]? = nil
    ) {
        self.streaming = streaming
        self.pushNotifications = pushNotifications
        self.stateTransitionHistory = stateTransitionHistory
        self.extensions = extensions
    }
}
