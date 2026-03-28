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

// MARK: - SecurityScheme

/// Defines a security scheme used to protect an agent's API endpoints.
///
/// This is a discriminated union based on the `type` field, following the
/// OpenAPI 3.0 Security Scheme Object structure.
///
/// Mirrors Dart `SecurityScheme` in `a2a/core/security_scheme.dart`.
public enum SecurityScheme: Codable, Sendable, Equatable {

    /// API key-based security scheme.
    case apiKey(description: String? = nil, name: String, in: String)

    /// HTTP authentication scheme (e.g., Basic, Bearer).
    case http(description: String? = nil, scheme: String, bearerFormat: String? = nil)

    /// OAuth 2.0 security scheme.
    case oauth2(description: String? = nil, flows: OAuthFlows)

    /// OpenID Connect security scheme.
    case openIdConnect(description: String? = nil, openIdConnectUrl: String)

    /// Mutual TLS authentication scheme.
    case mutualTls(description: String? = nil)

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case type
        case description
        case name
        case `in`
        case scheme
        case bearerFormat
        case flows
        case openIdConnectUrl
    }

    // MARK: - Decodable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "apiKey":
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            let name = try container.decode(String.self, forKey: .name)
            let inValue = try container.decode(String.self, forKey: .in)
            self = .apiKey(description: description, name: name, in: inValue)

        case "http":
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            let scheme = try container.decode(String.self, forKey: .scheme)
            let bearerFormat = try container.decodeIfPresent(String.self, forKey: .bearerFormat)
            self = .http(description: description, scheme: scheme, bearerFormat: bearerFormat)

        case "oauth2":
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            let flows = try container.decode(OAuthFlows.self, forKey: .flows)
            self = .oauth2(description: description, flows: flows)

        case "openIdConnect":
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            let url = try container.decode(String.self, forKey: .openIdConnectUrl)
            self = .openIdConnect(description: description, openIdConnectUrl: url)

        case "mutualTls":
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            self = .mutualTls(description: description)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown SecurityScheme type: \(type)"
            )
        }
    }

    // MARK: - Encodable

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .apiKey(let description, let name, let inValue):
            try container.encode("apiKey", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encode(name, forKey: .name)
            try container.encode(inValue, forKey: .in)

        case .http(let description, let scheme, let bearerFormat):
            try container.encode("http", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encode(scheme, forKey: .scheme)
            try container.encodeIfPresent(bearerFormat, forKey: .bearerFormat)

        case .oauth2(let description, let flows):
            try container.encode("oauth2", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encode(flows, forKey: .flows)

        case .openIdConnect(let description, let url):
            try container.encode("openIdConnect", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encode(url, forKey: .openIdConnectUrl)

        case .mutualTls(let description):
            try container.encode("mutualTls", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
        }
    }
}

// MARK: - OAuthFlows

/// Container for the OAuth 2.0 flows supported by a ``SecurityScheme/oauth2``.
///
/// Each property represents a different OAuth 2.0 grant type.
///
/// Mirrors Dart `OAuthFlows` in `a2a/core/security_scheme.dart`.
public struct OAuthFlows: Codable, Sendable, Equatable {

    /// Configuration for the Implicit Grant flow.
    public let implicit: OAuthFlow?

    /// Configuration for the Resource Owner Password Credentials Grant flow.
    public let password: OAuthFlow?

    /// Configuration for the Client Credentials Grant flow.
    public let clientCredentials: OAuthFlow?

    /// Configuration for the Authorization Code Grant flow.
    public let authorizationCode: OAuthFlow?

    public init(
        implicit: OAuthFlow? = nil,
        password: OAuthFlow? = nil,
        clientCredentials: OAuthFlow? = nil,
        authorizationCode: OAuthFlow? = nil
    ) {
        self.implicit = implicit
        self.password = password
        self.clientCredentials = clientCredentials
        self.authorizationCode = authorizationCode
    }
}

// MARK: - OAuthFlow

/// Configuration details for a single OAuth 2.0 flow.
///
/// Mirrors Dart `OAuthFlow` in `a2a/core/security_scheme.dart`.
public struct OAuthFlow: Codable, Sendable, Equatable {

    /// The Authorization URL for this flow.
    public let authorizationUrl: String?

    /// The Token URL for this flow.
    public let tokenUrl: String?

    /// The Refresh URL to obtain a new access token.
    public let refreshUrl: String?

    /// A map of available scopes for this flow.
    /// Keys are scope names, values are human-readable descriptions.
    public let scopes: [String: String]

    public init(
        authorizationUrl: String? = nil,
        tokenUrl: String? = nil,
        refreshUrl: String? = nil,
        scopes: [String: String]
    ) {
        self.authorizationUrl = authorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
    }
}
