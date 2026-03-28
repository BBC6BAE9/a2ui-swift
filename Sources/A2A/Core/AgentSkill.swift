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

// MARK: - AgentSkill

/// Represents a distinct capability or function that an agent can perform.
///
/// Part of the ``AgentCard``, this struct allows an agent to advertise its
/// specific skills, making them discoverable to clients.
///
/// Mirrors Dart `AgentSkill` in `a2a/core/agent_skill.dart`.
public struct AgentSkill: Codable, Sendable, Equatable {

    /// A unique identifier for the agent's skill (e.g., "weather-forecast").
    public let id: String

    /// A human-readable name for the skill (e.g., "Weather Forecast").
    public let name: String

    /// A detailed description of the skill, intended to help clients or users
    /// understand its purpose and functionality.
    public let description: String

    /// A set of keywords describing the skill's capabilities.
    public let tags: [String]

    /// Example prompts or scenarios that this skill can handle.
    public let examples: [String]?

    /// The set of supported input MIME types for this skill, overriding the
    /// agent's defaults.
    public let inputModes: [String]?

    /// The set of supported output MIME types for this skill, overriding the
    /// agent's defaults.
    public let outputModes: [String]?

    /// Security schemes necessary for the agent to leverage this skill.
    public let security: [[String: [String]]]?

    public init(
        id: String,
        name: String,
        description: String,
        tags: [String],
        examples: [String]? = nil,
        inputModes: [String]? = nil,
        outputModes: [String]? = nil,
        security: [[String: [String]]]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.tags = tags
        self.examples = examples
        self.inputModes = inputModes
        self.outputModes = outputModes
        self.security = security
    }
}
