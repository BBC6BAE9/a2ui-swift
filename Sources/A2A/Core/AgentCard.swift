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

// MARK: - AgentCard

/// A self-describing manifest for an A2A agent.
///
/// The ``AgentCard`` provides essential metadata about an agent, including its
/// identity, capabilities, skills, supported communication methods, and
/// security requirements. It serves as a primary discovery mechanism for
/// clients to understand how to interact with the agent, typically served from
/// `/.well-known/agent-card.json`.
///
/// Mirrors Dart `AgentCard` in `a2a/core/agent_card.dart`.
public struct AgentCard: Codable, Sendable, Equatable {

    /// The version of the A2A protocol that this agent implements.
    public let protocolVersion: String

    /// A human-readable name for the agent.
    public let name: String

    /// A concise, human-readable description of the agent's purpose and
    /// functionality.
    public let description: String

    /// The primary endpoint URL for interacting with the agent.
    public let url: String

    /// The transport protocol used by the primary endpoint specified in ``url``.
    public let preferredTransport: TransportProtocol?

    /// A list of alternative interfaces the agent supports.
    public let additionalInterfaces: [AgentInterface]?

    /// An optional URL pointing to an icon representing the agent.
    public let iconUrl: String?

    /// Information about the entity providing the agent service.
    public let provider: AgentProvider?

    /// The version string of the agent implementation itself.
    public let version: String

    /// An optional URL pointing to human-readable documentation for the agent.
    public let documentationUrl: String?

    /// A declaration of optional A2A protocol features and extensions
    /// supported by the agent.
    public let capabilities: AgentCapabilities

    /// A map of security schemes supported by the agent for authorization.
    public let securitySchemes: [String: SecurityScheme]?

    /// A list of security requirements that apply globally to all interactions.
    public let security: [[String: [String]]]?

    /// Default set of supported input MIME types for all skills.
    public let defaultInputModes: [String]

    /// Default set of supported output MIME types for all skills.
    public let defaultOutputModes: [String]

    /// The set of skills (distinct functionalities) that the agent can perform.
    public let skills: [AgentSkill]

    /// Indicates whether the agent can provide an extended agent card with
    /// potentially more details to authenticated users.
    public let supportsAuthenticatedExtendedCard: Bool?

    public init(
        protocolVersion: String,
        name: String,
        description: String,
        url: String,
        preferredTransport: TransportProtocol? = nil,
        additionalInterfaces: [AgentInterface]? = nil,
        iconUrl: String? = nil,
        provider: AgentProvider? = nil,
        version: String,
        documentationUrl: String? = nil,
        capabilities: AgentCapabilities,
        securitySchemes: [String: SecurityScheme]? = nil,
        security: [[String: [String]]]? = nil,
        defaultInputModes: [String],
        defaultOutputModes: [String],
        skills: [AgentSkill],
        supportsAuthenticatedExtendedCard: Bool? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.name = name
        self.description = description
        self.url = url
        self.preferredTransport = preferredTransport
        self.additionalInterfaces = additionalInterfaces
        self.iconUrl = iconUrl
        self.provider = provider
        self.version = version
        self.documentationUrl = documentationUrl
        self.capabilities = capabilities
        self.securitySchemes = securitySchemes
        self.security = security
        self.defaultInputModes = defaultInputModes
        self.defaultOutputModes = defaultOutputModes
        self.skills = skills
        self.supportsAuthenticatedExtendedCard = supportsAuthenticatedExtendedCard
    }
}
