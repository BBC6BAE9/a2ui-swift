// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import Primitives

// MARK: - GoogleContentConverter

/// An exception thrown by this package.
///
/// Mirrors Flutter's `GoogleAiClientException` from
/// `ai_client/google_content_converter.dart`.
struct GoogleAiClientException: Error, CustomStringConvertible {
    let message: String

    var description: String {
        "GoogleAiClientException: \(message)"
    }
}

/// Converts between `Primitives.ChatMessage` and the Gemini REST API
/// JSON format.
///
/// Mirrors Flutter's `GoogleContentConverter` from
/// `ai_client/google_content_converter.dart`.
///
/// Gemini REST API reference:
/// https://ai.google.dev/api/generate-content
enum GoogleContentConverter {

    // MARK: - ChatMessage → Gemini contents

    /// Converts an array of `ChatMessage` to the Gemini `contents` array.
    ///
    /// - Note: System messages are not included here; they belong in
    ///   `system_instruction`. Gemini only accepts `user` and `model` roles
    ///   in `contents`.
    static func toGeminiContents(_ messages: [Primitives.ChatMessage]) -> [[String: Any]] {
        messages.compactMap { toGeminiContent($0) }
    }

    /// Converts a single `ChatMessage` to a Gemini content dictionary.
    ///
    /// Returns `nil` for system messages (they go in `system_instruction`).
    static func toGeminiContent(_ message: Primitives.ChatMessage) -> [String: Any]? {
        let role: String
        switch message.role {
        case .user:
            role = "user"
        case .model:
            role = "model"
        case .system:
            return nil
        }

        let parts = message.parts.compactMap { toGeminiPart($0) }
        guard !parts.isEmpty else { return nil }

        return [
            "role": role,
            "parts": parts,
        ]
    }

    /// Converts a `StandardPart` to a Gemini part dictionary.
    ///
    /// Supported mappings:
    /// - `.text` → `{"text": "..."}`
    /// - `.tool(.call)` → `{"functionCall": {"name": ..., "args": {...}}}`
    /// - `.tool(.result)` → `{"functionResponse": {"name": ..., "response": {...}}}`
    /// - `.data` → `{"inlineData": {"mimeType": ..., "data": "<base64>"}}`
    /// - `.link` → `{"fileData": {"mimeType": ..., "fileUri": ...}}`
    /// - `.thinking` → `{"thought": true, "text": "..."}`
    static func toGeminiPart(_ part: StandardPart) -> [String: Any]? {
        switch part {
        case .text(let text):
            return ["text": text]

        case .tool(let content):
            return toGeminiToolPart(content)

        case .data(let content):
            if content.mimeType == "application/vnd.genui.interaction+json" {
                let text = String(data: content.bytes, encoding: .utf8) ?? ""
                return ["text": text]
            }
            let base64 = content.bytes.base64EncodedString()
            return [
                "inlineData": [
                    "mimeType": content.mimeType,
                    "data": base64,
                ] as [String: Any],
            ]

        case .link(let content):
            var fileData: [String: Any] = ["fileUri": content.url.absoluteString]
            if let mimeType = content.mimeType {
                fileData["mimeType"] = mimeType
            }
            return ["fileData": fileData]

        case .thinking(let text):
            return ["thought": true, "text": text]
        }
    }

    /// Converts a `ToolPartContent` to the appropriate Gemini part dictionary.
    private static func toGeminiToolPart(_ content: ToolPartContent) -> [String: Any]? {
        switch content.kind {
        case .call:
            let args: [String: Any] = (content.arguments ?? [:]).compactMapValues { $0.anyValue }
            var part: [String: Any] = [
                "functionCall": [
                    "name": content.toolName,
                    "args": args,
                ] as [String: Any],
            ]
            if let sig = content.thoughtSignature {
                part["thoughtSignature"] = sig
            }
            return part

        case .result:
            let response: Any
            if let result = content.result, let anyVal = result.anyValue {
                response = anyVal
            } else {
                response = [String: Any]()
            }
            return [
                "functionResponse": [
                    "name": content.toolName,
                    "response": response,
                ] as [String: Any],
            ]
        }
    }

    // MARK: - Gemini response → ChatMessage

    /// Converts a Gemini part dictionary back to a `StandardPart`.
    ///
    /// Used when reading model responses to build `ChatMessage` history entries.
    static func fromGeminiPart(_ partJson: [String: Any]) -> StandardPart? {
        if let text = partJson["text"] as? String {
            let isThought = partJson["thought"] as? Bool ?? false
            if isThought {
                return .thinking(text)
            }
            return .text(text)
        }

        if let functionCall = partJson["functionCall"] as? [String: Any] {
            let name = functionCall["name"] as? String ?? ""
            let argsAny = functionCall["args"] as? [String: Any?] ?? [:]
            var args: [String: JSONValue] = [:]
            for (k, v) in argsAny {
                if let jv = JSONValue(v) {
                    args[k] = jv
                }
            }
            let thoughtSig = partJson["thoughtSignature"] as? String
            return ToolPart.call(
                callId: name, toolName: name,
                arguments: args, thoughtSignature: thoughtSig
            )
        }

        if let functionResponse = partJson["functionResponse"] as? [String: Any] {
            let name = functionResponse["name"] as? String ?? ""
            let resultValue = functionResponse["response"].flatMap { JSONValue($0) }
            return ToolPart.result(callId: name, toolName: name, result: resultValue)
        }

        if let inlineData = partJson["inlineData"] as? [String: Any],
           let mimeType = inlineData["mimeType"] as? String,
           let base64 = inlineData["data"] as? String,
           let bytes = Data(base64Encoded: base64) {
            return DataPart.create(bytes, mimeType: mimeType)
        }

        if let fileData = partJson["fileData"] as? [String: Any],
           let fileUri = fileData["fileUri"] as? String,
           let url = URL(string: fileUri) {
            let mimeType = fileData["mimeType"] as? String
            return LinkPart.create(url, mimeType: mimeType)
        }

        return nil
    }

    // MARK: - ToolDefinition → Gemini functionDeclarations

    /// Converts an array of `ToolDefinition` to the Gemini `tools` array format.
    ///
    /// Gemini expects: `[{"functionDeclarations": [...]}]`.
    /// Schema adaptation is delegated to ``GoogleSchemaAdapter``.
    static func toGeminiTools(_ tools: [ToolDefinition]) -> [[String: Any]] {
        guard !tools.isEmpty else { return [] }
        let declarations = tools.map { toGeminiFunctionDeclaration($0) }
        return [["functionDeclarations": declarations]]
    }

    /// Converts a `ToolDefinition` to a Gemini function declaration dictionary.
    static func toGeminiFunctionDeclaration(_ tool: ToolDefinition) -> [String: Any] {
        var declaration: [String: Any] = [
            "name": tool.name,
            "description": tool.description,
        ]
        let adapter = GoogleSchemaAdapter()
        let result = adapter.adapt(tool.inputSchema)
        if let schema = result.schema {
            declaration["parameters"] = schema
        }
        return declaration
    }

    // MARK: - Response part extraction

    /// Extracts function calls, text parts, and finish reason from a Gemini response JSON.
    ///
    /// Returns a tuple of `(chatMessage, toolCalls, textParts, finishReason)`.
    /// The `chatMessage` is the fully-typed model turn suitable for appending to
    /// conversation history. `finishReason` is non-nil when the candidate includes
    /// one (e.g. `"STOP"`, `"MAX_TOKENS"`). Callers can use `"MAX_TOKENS"` to
    /// detect truncated output.
    static func extractResponseParts(
        from responseJson: [String: Any]
    ) -> (modelMessage: Primitives.ChatMessage?, toolCalls: [ToolPartContent], textParts: [String], finishReason: String?) {
        guard
            let candidates = responseJson["candidates"] as? [[String: Any]],
            let firstCandidate = candidates.first
        else {
            return (nil, [], [], nil)
        }

        let finishReason = firstCandidate["finishReason"] as? String

        guard
            let content = firstCandidate["content"] as? [String: Any],
            let partsJson = content["parts"] as? [[String: Any]]
        else {
            return (nil, [], [], finishReason)
        }

        let parts: [StandardPart] = partsJson.compactMap { fromGeminiPart($0) }

        var toolCalls: [ToolPartContent] = []
        var textParts: [String] = []
        for part in parts {
            switch part {
            case .text(let t): textParts.append(t)
            case .tool(let tc) where tc.kind == .call: toolCalls.append(tc)
            default: break
            }
        }

        let modelMessage: Primitives.ChatMessage? = parts.isEmpty
            ? nil
            : Primitives.ChatMessage(role: .model, parts: parts)

        return (modelMessage, toolCalls, textParts, finishReason)
    }
}
