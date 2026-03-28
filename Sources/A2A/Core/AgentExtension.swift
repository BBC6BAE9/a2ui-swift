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

// MARK: - AgentExtension

/// Specifies an extension to the A2A protocol supported by an agent.
///
/// Used in ``AgentCapabilities`` to list supported protocol extensions, allowing
/// agents to advertise custom features beyond the core A2A specification.
///
/// Mirrors Dart `AgentExtension` in `a2a/core/agent_extension.dart`.
public struct AgentExtension: Codable, Sendable, Equatable {

    /// The unique URI identifying the extension.
    public let uri: String

    /// A human-readable description of the extension.
    public let description: String?

    /// If true, the client must understand and comply with the extension's
    /// requirements to interact with the agent.
    public let required: Bool?

    /// Optional, extension-specific configuration parameters.
    ///
    /// Mirrors Dart `Map<String, Object?>? params`.
    public let params: JSONObject?

    public init(
        uri: String,
        description: String? = nil,
        required: Bool? = nil,
        params: JSONObject? = nil
    ) {
        self.uri = uri
        self.description = description
        self.required = required
        self.params = params
    }

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case uri
        case description
        case `required`
        case params
    }
}
