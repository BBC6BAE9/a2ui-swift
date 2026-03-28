// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/// Abstract protocol for defining tools that an AI agent can invoke.
///
/// An `AiTool` represents a capability that the AI can use to interact with
/// the external environment or perform specific actions. For example, a tool
/// could allow the AI to query a database or call an external API.
///
/// Mirrors Flutter's `AiTool` from `ai_client/tools.dart`.
protocol AiTool {
    /// The unique name of the tool.
    var name: String { get }

    /// Optional name prefix for namespacing (e.g., MCP server name).
    /// When set, the tool is registered under both `name` and `fullName`.
    var prefix: String? { get }

    /// The full name of the tool, including prefix if set.
    var fullName: String { get }

    /// A description of what the tool does, helping the AI decide when to use it.
    var description: String { get }

    /// Optional JSON Schema defining the parameters the tool accepts.
    var parameters: [String: Any]? { get }

    /// Executes the tool's logic with the given arguments.
    ///
    /// - Parameter args: Arguments provided by the AI, conforming to `parameters`.
    /// - Returns: A result dictionary sent back to the AI.
    func invoke(_ args: [String: Any]) async throws -> [String: Any]
}

extension AiTool {
    var prefix: String? { nil }

    var fullName: String {
        guard let prefix else { return name }
        return "\(prefix).\(name)"
    }
}

/// An `AiTool` that allows for dynamic invocation via a closure.
///
/// Useful for creating tools where the invocation logic is provided at runtime.
///
/// Mirrors Flutter's `DynamicAiTool` from `ai_client/tools.dart`.
struct DynamicAiTool: AiTool {
    let name: String
    let prefix: String?
    let description: String
    let parameters: [String: Any]?

    private let invokeFunction: ([String: Any]) async throws -> [String: Any]

    var fullName: String {
        guard let prefix else { return name }
        return "\(prefix).\(name)"
    }

    init(
        name: String,
        description: String,
        parameters: [String: Any]? = nil,
        prefix: String? = nil,
        invokeFunction: @escaping ([String: Any]) async throws -> [String: Any]
    ) {
        self.name = name
        self.prefix = prefix
        self.description = description
        self.parameters = parameters
        self.invokeFunction = invokeFunction
    }

    func invoke(_ args: [String: Any]) async throws -> [String: Any] {
        try await invokeFunction(args)
    }
}
