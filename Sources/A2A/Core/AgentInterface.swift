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

// MARK: - TransportProtocol

/// Supported A2A transport protocols.
///
/// Mirrors Dart `TransportProtocol` enum in `a2a/core/agent_interface.dart`.
public enum TransportProtocol: String, Codable, Sendable, Equatable {
    /// JSON-RPC 2.0 over HTTP.
    case jsonrpc = "JSONRPC"

    /// gRPC over HTTP/2.
    case grpc = "GRPC"

    /// REST-style HTTP with JSON.
    case httpJson = "HTTP+JSON"
}

// MARK: - AgentInterface

/// Declares a combination of a target URL and a transport protocol for
/// interacting with an agent.
///
/// Part of the ``AgentCard``, this allows an agent to expose the same
/// functionality over multiple transport mechanisms.
///
/// Mirrors Dart `AgentInterface` in `a2a/core/agent_interface.dart`.
public struct AgentInterface: Codable, Sendable, Equatable {

    /// The URL where this interface is available.
    public let url: String

    /// The transport protocol supported at this URL.
    public let transport: TransportProtocol

    public init(url: String, transport: TransportProtocol) {
        self.url = url
        self.transport = transport
    }
}
