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

// MARK: - AgentProvider

/// Information about the agent's service provider.
///
/// Part of the ``AgentCard``, this provides information about the entity that
/// created and maintains the agent.
///
/// Mirrors Dart `AgentProvider` in `a2a/core/agent_provider.dart`.
public struct AgentProvider: Codable, Sendable, Equatable {

    /// The name of the agent provider's organization.
    public let organization: String

    /// A URL for the agent provider's website or relevant documentation.
    public let url: String

    public init(organization: String, url: String) {
        self.organization = organization
        self.url = url
    }
}
