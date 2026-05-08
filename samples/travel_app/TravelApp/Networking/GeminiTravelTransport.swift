// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import A2UISwiftCore
import Primitives
/// Transport that calls the Google Gemini REST API directly,
/// aligning with the Flutter `GoogleGenerativeAiClient` implementation.
///
/// By default uses non-streaming `generateContent` to match Flutter's approach.
/// Streaming can be enabled via `useStreaming` for a more interactive UX,
/// but may be less reliable for large JSON responses.
final class GeminiTravelTransport: TravelTransport {
    var supportsStreaming: Bool

    private let apiKey: String
    private let model: String

    /// The system prompt fragments passed from the view layer.
    /// Mirrors Flutter's pattern where `prompt` is defined in
    /// `travel_planner_page.dart` and passed to `GoogleGenerativeAiClient`
    /// as `systemInstruction`.
    private let systemInstructionFragments: [String]

    /// Typed conversation history using `Primitives.ChatMessage`.
    ///
    /// Replaces the previous `[[String: Any]]` representation. Serialization to
    /// Gemini REST JSON format is handled by `GoogleContentConverter`.
    private var conversationHistory: [Primitives.ChatMessage] = []

    /// Client data model set by the ViewModel before actions, matching Flutter's
    /// pattern of including the data model in the system instruction.
    var clientDataModel: A2uiClientDataModel?

    /// Stores the last plain text response from the model when no A2UI messages
    /// were generated. Read by the ViewModel to show as a text bubble.
    private(set) var lastTextResponse: String?

    /// Generation config shared by streaming and non-streaming requests.
    /// An explicit `maxOutputTokens` prevents the model from truncating large
    /// JSON responses (e.g. TravelCarousel with multiple Image components).
    /// Flutter uses non-streaming `generateContent` which is less susceptible
    /// to truncation; streaming needs this safeguard.
    private static let generationConfig: [String: Any] = [
        "maxOutputTokens": 65536,
    ]

    init(
        apiKey: String,
        model: String = "gemini-3-flash-preview",
        systemInstruction: [String] = [],
        useStreaming: Bool = false
    ) {
        self.apiKey = apiKey
        self.model = model
        self.systemInstructionFragments = systemInstruction
        self.supportsStreaming = useStreaming
    }

    // MARK: - TravelTransport

    func sendText(_ text: String, contextId: String?) async throws -> TransportResponse {
        print("[GeminiTransport] sendText: \"\(text.prefix(100))\" self=\(ObjectIdentifier(self))")
        conversationHistory.append(Primitives.ChatMessage.user(text))

        let messages = try await generateContent()
        print("[GeminiTransport] sendText returning \(messages.count) messages")
        return TransportResponse(messages: messages, contextId: contextId, textResponse: lastTextResponse)
    }

    func sendAction(_ action: ResolvedAction, surfaceId: String, contextId: String?) async throws -> TransportResponse {
        let interactionText = buildInteractionText(action: action, surfaceId: surfaceId)
        print("[GeminiTransport] sendAction: \(interactionText)")
        conversationHistory.append(Primitives.ChatMessage.user(interactionText))

        let messages = try await generateContent()
        print("[GeminiTransport] sendAction returning \(messages.count) messages")
        return TransportResponse(messages: messages, contextId: contextId, textResponse: lastTextResponse)
    }

    func sendTextStream(_ text: String, contextId: String?) -> AsyncThrowingStream<StreamEvent, Error>? {
        guard supportsStreaming else { return nil }
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    conversationHistory.append(Primitives.ChatMessage.user(text))
                    try streamContent(continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func sendActionStream(_ action: ResolvedAction, surfaceId: String, contextId: String?) -> AsyncThrowingStream<StreamEvent, Error>? {
        guard supportsStreaming else { return nil }
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let interactionText = buildInteractionText(action: action, surfaceId: surfaceId)
                    conversationHistory.append(Primitives.ChatMessage.user(interactionText))
                    try streamContent(continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Serialises a `ResolvedAction` to the A2UI interaction JSON string that is
    /// sent as the user turn, matching Flutter's format.
    ///
    /// Both the non-streaming (`sendAction`) and streaming (`sendActionStream`)
    /// paths use this shared helper to avoid duplicating the encoding logic.
    private func buildInteractionText(action: ResolvedAction, surfaceId: String) -> String {
        var actionContext: [String: Any] = [:]
        for (key, value) in action.context {
            switch value {
            case .string(let s): actionContext[key] = s
            case .number(let n): actionContext[key] = n
            case .bool(let b): actionContext[key] = b
            default: actionContext[key] = "\(value)"
            }
        }
        let interactionJson: [String: Any] = [
            "interaction": [
                "version": "v0.9",
                "action": [
                    "surfaceId": surfaceId,
                    "name": action.name,
                    "sourceComponentId": action.sourceComponentId,
                    "context": actionContext,
                ] as [String: Any],
            ] as [String: Any],
        ]
        if let data = try? JSONSerialization.data(withJSONObject: interactionJson, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return "User action: \(action.name) on surface: \(surfaceId)"
    }

    @discardableResult
    private func streamContent(continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation) throws -> Bool {
        Task {
            do {
                let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?key=\(apiKey)&alt=sse")!
                let requestBody: [String: Any] = [
                    "contents": GoogleContentConverter.toGeminiContents(conversationHistory),
                    "system_instruction": systemInstruction(),
                    "tools": GoogleContentConverter.toGeminiTools(toolDefinitions),
                    "toolConfig": ["functionCallingConfig": ["mode": "AUTO"]],
                    "generationConfig": Self.generationConfig
                ]

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 300
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GeminiError.invalidResponse
                }
                guard httpResponse.statusCode == 200 else {
                    var errorData = Data()
                    for try await byte in bytes { errorData.append(byte) }
                    let responseBody = String(data: errorData, encoding: .utf8) ?? "unknown error"
                    print("[GeminiTransport] Streaming API error \(httpResponse.statusCode): \(responseBody.prefix(500))")
                    throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: responseBody)
                }

                var textChunks: [String] = []
                var accumulatedToolCalls: [ToolPartContent] = []
                var streamedModelParts: [StandardPart] = []

                for try await line in bytes.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let jsonStr = String(line.dropFirst(6))
                    guard jsonStr != "[DONE]",
                          let data = jsonStr.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                    let (_, calls, textParts, finishReason) = GoogleContentConverter.extractResponseParts(from: json)
                    accumulatedToolCalls.append(contentsOf: calls)

                    if finishReason == "MAX_TOKENS" {
                        print("[GeminiTransport] ⚠️ Response truncated (MAX_TOKENS) — output may be incomplete")
                    }

                    for chunk in textParts {
                        textChunks.append(chunk)
                        streamedModelParts.append(.text(chunk))
                        continuation.yield(.textChunk(chunk))
                    }
                    for call in calls {
                        streamedModelParts.append(.tool(call))
                    }
                }

                let accumulatedText = textChunks.joined()

                // Save model turn to history as a typed ChatMessage
                if !streamedModelParts.isEmpty {
                    conversationHistory.append(Primitives.ChatMessage(role: .model, parts: streamedModelParts))
                }

                if !accumulatedToolCalls.isEmpty {
                    // Handle tool calls: execute and make another (non-streaming) call
                    continuation.yield(.status(state: "tool_use", text: "Looking up options...", taskId: nil, contextId: nil, isFinal: false))
                    var toolResultParts: [StandardPart] = []
                    for call in accumulatedToolCalls {
                        let args: [String: Any] = (call.arguments ?? [:]).compactMapValues { $0.anyValue }
                        let result = await executeTool(name: call.toolName, args: args)
                        let resultValue = JSONValue(result as Any) ?? .object([:])
                        toolResultParts.append(
                            ToolPart.result(
                                callId: call.callId,
                                toolName: call.toolName,
                                result: resultValue
                            )
                        )
                    }
                    conversationHistory.append(Primitives.ChatMessage(role: .user, parts: toolResultParts))

                    // Non-streaming follow-up after tool use
                    let finalMessages = try await generateContent()
                    let cleanText = stripJSONBlocks(from: lastTextResponse ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.yield(.result(TransportResponse(messages: finalMessages, contextId: nil, textResponse: cleanText.isEmpty ? nil : cleanText)))
                } else {
                    // Don't re-parse A2UI messages here — they were already processed
                    // inline by the collectStream's A2UIStreamParser during streaming.
                    // Only pass along any remaining plain text.
                    let cleanText = stripJSONBlocks(from: accumulatedText).trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.yield(.result(TransportResponse(messages: [], contextId: nil, textResponse: cleanText.isEmpty ? nil : cleanText)))
                }

                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return true
    }

    // MARK: - Gemini API

    private func generateContent() async throws -> [A2uiMessage] {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!

        let requestBody: [String: Any] = [
            "contents": GoogleContentConverter.toGeminiContents(conversationHistory),
            "system_instruction": systemInstruction(),
            "tools": GoogleContentConverter.toGeminiTools(toolDefinitions),
            "toolConfig": ["functionCallingConfig": ["mode": "AUTO"]],
            "generationConfig": Self.generationConfig
        ]

        let currentJson = try await callGemini(url: url, body: requestBody)
        return try await handleResponse(currentJson, url: url)
    }

    /// Send a request to the Gemini API and return the parsed JSON response.
    private func callGemini(url: URL, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[GeminiTransport] Calling Gemini API...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("[GeminiTransport] Gemini API responded, \(data.count) bytes")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "unknown error"
            print("[GeminiTransport] API error \(httpResponse.statusCode): \(responseBody.prefix(500))")
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: responseBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let preview = String(data: data, encoding: .utf8)?.prefix(500) ?? "nil"
            print("[GeminiTransport] Response is not a JSON dictionary: \(preview)")
            throw GeminiError.invalidResponse
        }

        return json
    }

    /// Process a Gemini response, handling tool call loops.
    private func handleResponse(_ initialJson: [String: Any], url: URL) async throws -> [A2uiMessage] {
        lastTextResponse = nil
        var currentJson = initialJson
        var toolCycles = 0
        let maxToolCycles = 40

        while toolCycles < maxToolCycles {
            let (modelMessage, toolCalls, textParts, finishReason) = GoogleContentConverter.extractResponseParts(from: currentJson)

            if finishReason == "MAX_TOKENS" {
                print("[GeminiTransport] ⚠️ Response truncated (MAX_TOKENS) — output may be incomplete")
            }

            if toolCalls.isEmpty {
                let fullText = textParts.joined()
                print("[GeminiTransport] Model text response (\(fullText.count) chars): \(fullText.prefix(300))...")

                // Add model response to conversation history as a typed ChatMessage
                if let modelMessage {
                    conversationHistory.append(modelMessage)
                }

                let messages = await parseA2uiMessages(from: fullText)
                print("[GeminiTransport] Parsed \(messages.count) A2UI messages")

                // If no A2UI messages were parsed but there's text, save it
                // so the ViewModel can show it as a text bubble.
                if messages.isEmpty {
                    let cleanText = stripJSONBlocks(from: fullText).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanText.isEmpty {
                        lastTextResponse = cleanText
                    }
                }

                return messages
            }

            toolCycles += 1
            print("[GeminiTransport] Tool cycle \(toolCycles): \(toolCalls.count) function call(s)")

            // Add model response (with function calls) to history as a typed ChatMessage
            if let modelMessage {
                conversationHistory.append(modelMessage)
            }

            // Process function calls and build typed tool-result ChatMessage
            var toolResultParts: [StandardPart] = []
            for call in toolCalls {
                let args: [String: Any] = (call.arguments ?? [:]).compactMapValues { $0.anyValue }
                print("[GeminiTransport] Executing tool: \(call.toolName) args: \(args)")
                let result = await executeTool(name: call.toolName, args: args)
                let resultValue = JSONValue(result as Any) ?? .object([:])
                toolResultParts.append(
                    ToolPart.result(
                        callId: call.callId,
                        toolName: call.toolName,
                        result: resultValue
                    )
                )
            }

            // Add tool responses to history as a typed ChatMessage
            conversationHistory.append(Primitives.ChatMessage(role: .user, parts: toolResultParts))

            let nextRequestBody: [String: Any] = [
                "contents": GoogleContentConverter.toGeminiContents(conversationHistory),
                "system_instruction": systemInstruction(),
                "tools": GoogleContentConverter.toGeminiTools(toolDefinitions),
                "toolConfig": ["functionCallingConfig": ["mode": "AUTO"]],
                "generationConfig": Self.generationConfig
            ]

            currentJson = try await callGemini(url: url, body: nextRequestBody)
        }

        print("[GeminiTransport] Exceeded max tool cycles (\(maxToolCycles))")
        return []
    }

    /// Tool instances matching Flutter's pattern of `ListHotelsTool` etc.
    /// Each tool conforms to `AiTool` and is looked up by name in `executeTool`.
    private let tools: [any AiTool] = [
        ListHotelsTool(onListHotels: { search in
            await BookingService.instance.listHotels(search)
        }),
    ]

    /// Tool definitions derived from `tools`, for Gemini `functionDeclarations`.
    private var toolDefinitions: [ToolDefinition] {
        tools.map { tool in
            ToolDefinition(
                name: tool.name,
                description: tool.description,
                inputSchema: tool.parameters ?? [:]
            )
        }
    }

    /// Execute a tool call by dispatching to the matching `AiTool`.
    /// Mirrors Flutter's `GoogleGenerativeAiClient` tool dispatch pattern.
    private func executeTool(name: String, args: [String: Any]) async -> [String: Any] {
        if let tool = tools.first(where: { $0.name == name }) {
            do {
                return try await tool.invoke(args)
            } catch {
                return ["error": "Tool \(name) failed: \(error.localizedDescription)"]
            }
        }
        return ["error": "Unknown tool: \(name)"]
    }

    // MARK: - System Instruction

    /// Returns the system instruction in Gemini REST API `system_instruction` format.
    ///
    /// Matches Flutter's `_BasicPromptBuilder.systemPrompt()` assembly order:
    /// 1. systemPromptFragments (= `prompt` list from TravelPlannerView: currentDate,
    ///    systemPrompt, uiGenerationRestriction)
    /// 2. "Use the provided tools..."
    /// 3. technicalPossibilities (3 IMPORTANT statements)
    /// 4. catalog.systemPromptFragments (empty for travelAppCatalog)
    /// 5. allowedOperations.systemPromptFragments (controllingTheUI, outputFormat)
    /// 6. A2UI JSON Schema
    /// 7. Client Data Model (if available)
    private func systemInstruction() -> [String: Any] {
        // --- systemPromptFragments (= Flutter's `prompt` list, passed from view) ---
        var parts: [[String: Any]] = systemInstructionFragments.map { ["text": $0] }
        // --- PromptBuilder.custom() injected fragments ---
        parts.append(["text": "Use the provided tools to respond to user using rich UI elements."])
        // --- TechnicalPossibilities (all false → 3 IMPORTANT statements) ---
        parts.append(["text": "IMPORTANT: You do not have the ability to execute code. If you need to perform calculations, do them yourself."])
        parts.append(["text": "IMPORTANT: You do not have the ability to use tools for UI generation."])
        parts.append(["text": "IMPORTANT: You do not have the ability to use function calls for UI generation."])
        // --- catalog.systemPromptFragments (empty for travelAppCatalog) ---
        // --- allowedOperations.systemPromptFragments ---
        parts.append(["text": Self.controllingTheUI])
        parts.append(["text": Self.outputFormat])
        // A2UI JSON Schema
        parts.append(["text": Self.catalogSchema])
        // Client Data Model (matches Flutter's pattern)
        if let clientDataModel {
            var dataDict: [String: Any] = [:]
            for (surfaceId, surfaceData) in clientDataModel.surfaces {
                dataDict[surfaceId] = anyCodableToAny(surfaceData)
            }
            if let data = try? JSONSerialization.data(withJSONObject: dataDict, options: [.prettyPrinted, .sortedKeys]),
               let dataString = String(data: data, encoding: .utf8) {
                parts.append(["text": "Client Data Model:\n\(dataString)"])
            }
        }
        return ["parts": parts]
    }

    /// Convert AnyCodable to Any for JSONSerialization.
    private func anyCodableToAny(_ value: AnyCodable) -> Any {
        switch value {
        case .string(let s): return s
        case .number(let n): return n
        case .bool(let b): return b
        case .null: return NSNull()
        case .array(let arr): return arr.map { anyCodableToAny($0) }
        case .dictionary(let dict):
            var result: [String: Any] = [:]
            for (k, v) in dict { result[k] = anyCodableToAny(v) }
            return result
        }
    }

    // MARK: - JSON Block Parsing

    /// Parse A2UI messages from the response text.
    /// Mirrors Flutter's `GoogleGenerativeAiClient` which uses `JsonBlockParser.parseJsonBlocks`.
    private func parseA2uiMessages(from text: String) async -> [A2uiMessage] {
        // Use A2UIStreamParser (from SPM) — feed full text then collect via events stream.
        let parser = A2UIStreamParser()
        var messages: [A2uiMessage] = []

        await parser.add(text)
        await parser.finish()

        for await event in parser.events {
            switch event {
            case .message(let msg):
                messages.append(msg)
            case .text, .error:
                break
            }
        }

        // Fallback: `JsonBlockParser` for markdown blocks where stream parsing yielded no `.message`s.
        // Per v0.9 spec / JSON Schema, messages must carry `"version":"v0.9"`; do not fabricate it here.
        if messages.isEmpty {
            let blocks = JsonBlockParser.parseJsonBlocks(text)
            for block in blocks {
                guard let json = block as? [String: Any] else { continue }
                if let message = MockServerToClientMessages.decodeMessage(json) {
                    messages.append(message)
                }
            }
        }

        print("[GeminiTransport] parseA2uiMessages: \(messages.count) messages from \(text.count) chars")
        return messages
    }

    /// Strip JSON code blocks from text, leaving only the conversational text.
    /// Delegates to `JsonBlockParser.stripJsonBlock` from SPM.
    private func stripJSONBlocks(from text: String) -> String {
        JsonBlockParser.stripJsonBlock(text)
    }

    // MARK: - Prompts (framework-level fragments added by PromptBuilder in Flutter)
    //
    // The user-facing prompt fragments (currentDate, systemPrompt,
    // uiGenerationRestriction) are now defined as `prompt` in
    // TravelPlannerView.swift, matching Flutter's `travel_planner_page.dart`.
    // They are passed to this transport via `systemInstructionFragments`.

    /// Matches Flutter's `SurfaceOperations.createAndUpdate(dataModel: true).systemPromptFragments`.
    /// Generated by `SurfaceOperations._controllingUI` in `prompt_builder.dart`.
    private static let controllingTheUI = """
-----CONTROLLING_THE_UI_START-----
You can control the UI by outputting valid A2UI JSON messages wrapped in markdown code blocks.

Supported messages are: `createSurface`, `updateComponents`, `updateDataModel`.

- `createSurface`: Creates a new surface.
- `updateComponents`: Updates components in a surface.
- `updateDataModel`: Updates the data model.

Properties:

- `createSurface`: Requires `surfaceId` (you must always use a unique ID for each created surface), `catalogId` (use the catalog ID provided in system instructions), and `sendDataModel: true`.
- `updateComponents`: Requires `surfaceId` and a list of `components`. One component MUST have `id: "root"`.
- `updateDataModel`: Requires `surfaceId`, `path` and `value`.

To create a new UI:
1. Output a `createSurface` message with a unique `surfaceId` and `catalogId` (use the catalog ID provided in system instructions).
2. Output an `updateComponents` message with the `surfaceId` and the component definitions.

To update an existing UI:
1. Output an `updateComponents` message with the existing `surfaceId` and the new component definitions.
-----CONTROLLING_THE_UI_END-----
"""

    /// Matches Flutter's `SurfaceOperations.systemPromptFragments` output format section.
    private static let outputFormat = """
-----OUTPUT_FORMAT_START-----
When constructing UI, you must output a VALID A2UI JSON object representing one of the A2UI message types (`createSurface`, `updateComponents`, `updateDataModel`).
- You can treat the A2UI schema as a specification for the JSON you typically output.
- You may include a brief conversational explanation before or after the JSON block if it helps the user, but the JSON block must be valid and complete.
- Ensure your JSON is fenced with ```json and ```.
-----OUTPUT_FORMAT_END-----
"""

    // MARK: - A2UI Message Schema (matching Flutter's ServerToClientMessage.ServerToClientMessageSchema output)

    /// Generates the full A2UI Message Schema JSON string matching Flutter's
    /// `ServerToClientMessage.ServerToClientMessageSchema(catalog).toJson(indent: '  ')` output.
    /// This is the proper JSON Schema format that Gemini needs to understand
    /// the available components and their properties.
    static var catalogSchema: String {
        // Helper: action schema (event-based)
        let actionSchema: [String: Any] = [
            "oneOf": [
                [
                    "type": "object",
                    "properties": [
                        "event": [
                            "type": "object",
                            "properties": [
                                "name": [
                                    "type": "string",
                                    "description": "The name of the action to be dispatched to the server."
                                ],
                                "context": [
                                    "type": "object",
                                    "description": "Arbitrary context data to send with the action.",
                                    "additionalProperties": true
                                ]
                            ],
                            "required": ["name"]
                        ]
                    ],
                    "required": ["event"]
                ]
            ]
        ]

        // Helper: string reference (literal or data-binding)
        func stringRef(_ desc: String, enumValues: [String]? = nil) -> [String: Any] {
            var literal: [String: Any] = ["type": "string", "description": "A literal string value."]
            if let enumValues { literal["enum"] = enumValues }
            return [
                "description": desc,
                "oneOf": [
                    literal,
                    [
                        "type": "object",
                        "description": "A path to a string.",
                        "properties": ["path": ["type": "string", "description": "A relative or absolute path in the data model."]],
                        "required": ["path"]
                    ]
                ]
            ]
        }

        // Helper: component reference (just a string ID)
        func compRef(_ desc: String) -> [String: Any] {
            return ["type": "string", "description": desc]
        }

        // Helper: component array reference (list of IDs or template)
        func compArrayRef(_ desc: String) -> [String: Any] {
            return [
                "description": desc,
                "oneOf": [
                    ["type": "array", "items": ["type": "string", "description": "Component ID"]],
                    [
                        "type": "object",
                        "properties": [
                            "componentId": ["type": "string", "description": "The ID of a component."],
                            "path": ["type": "string", "description": "A relative or absolute path in the data model."]
                        ],
                        "required": ["componentId", "path"]
                    ]
                ]
            ]
        }

        // --- Component schemas (each with "component" discriminator) ---

        let buttonSchema: [String: Any] = [
            "type": "object",
            "description": "An interactive button that triggers an action when pressed.",
            "properties": [
                "component": ["type": "string", "enum": ["Button"]],
                "child": compRef("ID of child widget (e.g., Text)."),
                "action": actionSchema,
                "variant": ["type": "string", "description": "Button style hint.", "enum": ["primary", "borderless"]]
            ],
            "required": ["component", "child", "action"]
        ]

        let columnSchema: [String: Any] = [
            "type": "object",
            "description": "A layout widget that arranges its children vertically.",
            "properties": [
                "component": ["type": "string", "enum": ["Column"]],
                "justify": ["type": "string", "description": "Main axis alignment.", "enum": ["start", "center", "end", "spaceBetween", "spaceAround", "spaceEvenly", "stretch"]],
                "align": ["type": "string", "description": "Cross axis alignment.", "enum": ["start", "center", "end", "stretch"]],
                "children": compArrayRef("List of widget IDs or template with data binding.")
            ],
            "required": ["component", "children"]
        ]

        let textSchema: [String: Any] = [
            "type": "object",
            "description": "A block of styled text.",
            "properties": [
                "component": ["type": "string", "enum": ["Text"]],
                "text": stringRef("Text content (markdown supported, but prefer UI components)."),
                "variant": ["type": "string", "description": "Base text style hint.", "enum": ["h1", "h2", "h3", "h4", "h5", "caption", "body"]]
            ],
            "required": ["component", "text"]
        ]

        let imageSchema: [String: Any] = [
            "type": "object",
            "description": "A UI element for displaying image data from URL or asset.",
            "properties": [
                "component": ["type": "string", "enum": ["Image"]],
                "url": stringRef("Asset path (assets/...) or network URL (https://...)."),
                "fit": ["type": "string", "description": "How image inscribed into box.", "enum": ["contain", "cover", "fill", "fitWidth", "fitHeight", "none", "scaleDown"]],
                "variant": ["type": "string", "description": "Size/style hint.", "enum": ["icon", "avatar", "smallFeature", "mediumFeature", "largeFeature", "header"]]
            ],
            "required": ["component"]
        ]

        let travelCarouselSchema: [String: Any] = [
            "type": "object",
            "description": "A horizontal carousel of travel items with images and actions.",
            "properties": [
                "component": ["type": "string", "enum": ["TravelCarousel"]],
                "title": stringRef("Optional title above carousel."),
                "items": [
                    "type": "array",
                    "description": "List of carousel items.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "description": stringRef("Short description (e.g., \"The Dart Inn in Sunnyvale, CA for $150\")."),
                            "imageChildId": compRef("ID of Image widget for this item."),
                            "listingSelectionId": ["type": "string", "description": "Optional ID of listing."],
                            "action": actionSchema
                        ],
                        "required": ["description", "imageChildId", "action"]
                    ]
                ]
            ],
            "required": ["component", "items"]
        ]

        let informationCardSchema: [String: Any] = [
            "type": "object",
            "description": "A card displaying information about a destination or topic.",
            "properties": [
                "component": ["type": "string", "enum": ["InformationCard"]],
                "imageChildId": ["type": "string", "description": "ID of Image widget at top of card."],
                "title": stringRef("The title of the card."),
                "subtitle": stringRef("The subtitle."),
                "body": stringRef("Body text (supports markdown).")
            ],
            "required": ["component", "title", "body"]
        ]

        let itinerarySchema: [String: Any] = [
            "type": "object",
            "description": "Widget to show an itinerary or a plan for travel.",
            "properties": [
                "component": ["type": "string", "enum": ["Itinerary"]],
                "title": stringRef("The title of the itinerary."),
                "subheading": stringRef("The subheading."),
                "imageChildId": compRef("ID of Image widget for the itinerary header."),
                "days": [
                    "type": "array",
                    "description": "A list of days in the itinerary.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": stringRef("e.g., \"Day 1\"."),
                            "subtitle": stringRef("e.g., \"Arrival in Tokyo\"."),
                            "description": stringRef("Short description (markdown)."),
                            "imageChildId": compRef("ID of Image widget."),
                            "entries": [
                                "type": "array",
                                "description": "A list of itinerary entries for this day.",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "title": stringRef("The title."),
                                        "subtitle": stringRef("The subtitle."),
                                        "bodyText": stringRef("Body text (markdown)."),
                                        "address": stringRef("The address."),
                                        "time": stringRef("Time (formatted string)."),
                                        "totalCost": stringRef("Total cost."),
                                        "type": ["type": "string", "description": "Type of entry.", "enum": ["accommodation", "transport", "activity"]],
                                        "status": ["type": "string", "description": "Booking status.", "enum": ["noBookingRequired", "choiceRequired", "chosen"]],
                                        "choiceRequiredAction": actionSchema
                                    ],
                                    "required": ["title", "bodyText", "time", "type", "status"]
                                ]
                            ]
                        ],
                        "required": ["title", "subtitle", "description", "imageChildId", "entries"]
                    ]
                ]
            ],
            "required": ["component", "title", "subheading", "imageChildId", "days"]
        ]

        let inputGroupSchema: [String: Any] = [
            "type": "object",
            "description": "A group of input chips with a submit button.",
            "properties": [
                "component": ["type": "string", "enum": ["InputGroup"]],
                "submitLabel": stringRef("Label for submit button."),
                "children": ["type": "array", "description": "Widget IDs for input children (e.g., OptionsFilterChipInput).", "items": ["type": "string"]],
                "action": actionSchema
            ],
            "required": ["component", "submitLabel", "children", "action"]
        ]

        let optionsFilterChipSchema: [String: Any] = [
            "type": "object",
            "description": "Chip for mutually exclusive options. Must be inside InputGroup.",
            "properties": [
                "component": ["type": "string", "enum": ["OptionsFilterChipInput"]],
                "chipLabel": ["type": "string", "description": "Title (e.g., \"budget\", \"activity type\")."],
                "options": ["type": "array", "description": "List of options (at least three).", "items": ["type": "string"]],
                "iconName": ["type": "string", "description": "Icon to display.", "enum": ["location", "hotel", "restaurant", "airport", "train", "car", "date", "time", "calendar", "people", "person", "family", "wallet", "receipt"]],
                "value": stringRef("Initially selected option name.")
            ],
            "required": ["component", "chipLabel", "options"]
        ]

        let checkboxFilterChipSchema: [String: Any] = [
            "type": "object",
            "description": "Chip where more than one option can be chosen. Must be inside InputGroup.",
            "properties": [
                "component": ["type": "string", "enum": ["CheckboxFilterChipsInput"]],
                "chipLabel": ["type": "string", "description": "Title (e.g., \"amenities\", \"dietary restrictions\")."],
                "options": ["type": "array", "description": "List of options.", "items": ["type": "string"]],
                "iconName": ["type": "string", "description": "Icon to display.", "enum": ["location", "hotel", "restaurant", "airport", "train", "car", "date", "time", "calendar", "people", "person", "family", "wallet", "receipt"]],
                "selectedOptions": ["type": "array", "description": "Initially selected option names.", "items": ["type": "string"]]
            ],
            "required": ["component", "chipLabel", "options", "selectedOptions"]
        ]

        let dateInputChipSchema: [String: Any] = [
            "type": "object",
            "description": "A date picker chip. Must be inside InputGroup.",
            "properties": [
                "component": ["type": "string", "enum": ["DateInputChip"]],
                "value": stringRef("Initial date in yyyy-mm-dd format."),
                "label": ["type": "string", "description": "Label for date picker."]
            ],
            "required": ["component"]
        ]

        let textInputChipSchema: [String: Any] = [
            "type": "object",
            "description": "Input chip for free text, e.g., to select destination. Inside InputGroup only.",
            "properties": [
                "component": ["type": "string", "enum": ["TextInputChip"]],
                "label": ["type": "string", "description": "Label for text input chip."],
                "value": stringRef("Initial value."),
                "obscured": ["type": "boolean", "description": "Whether text obscured (passwords)."]
            ],
            "required": ["component", "label"]
        ]

        let trailheadSchema: [String: Any] = [
            "type": "object",
            "description": "A set of topic chips the user can tap to explore. Use for suggestions.",
            "properties": [
                "component": ["type": "string", "enum": ["Trailhead"]],
                "topics": [
                    "type": "array",
                    "description": "List of topics to display as chips.",
                    "items": stringRef("A topic to explore.")
                ],
                "action": actionSchema
            ],
            "required": ["component", "topics", "action"]
        ]

        let listingsBookerSchema: [String: Any] = [
            "type": "object",
            "description": "A widget to select among a set of listings.",
            "properties": [
                "component": ["type": "string", "enum": ["ListingsBooker"]],
                "listingSelectionIds": ["type": "array", "description": "Listings to select among.", "items": ["type": "string"]],
                "itineraryName": stringRef("The name of the itinerary."),
                "modifyAction": actionSchema
            ],
            "required": ["component", "listingSelectionIds"]
        ]

        let tabbedSectionsSchema: [String: Any] = [
            "type": "object",
            "description": "A tabbed sections widget.",
            "properties": [
                "component": ["type": "string", "enum": ["TabbedSections"]],
                "sections": [
                    "type": "array",
                    "description": "List of sections to display as tabs.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": stringRef("Title of the tab."),
                            "child": compRef("ID of child widget for content.")
                        ],
                        "required": ["child", "title"]
                    ]
                ]
            ],
            "required": ["component", "sections"]
        ]

        // Assemble the full A2UI Message Schema
        let allComponentSchemas: [Any] = [
            buttonSchema,
            columnSchema,
            textSchema,
            imageSchema,
            travelCarouselSchema,
            informationCardSchema,
            itinerarySchema,
            inputGroupSchema,
            optionsFilterChipSchema,
            checkboxFilterChipSchema,
            dateInputChipSchema,
            textInputChipSchema,
            trailheadSchema,
            listingsBookerSchema,
            tabbedSectionsSchema
        ]

        let fullSchema: [String: Any] = [
            "allOf": [
                [
                    "type": "object",
                    "title": "A2UI Message Schema",
                    "description": "Describes a JSON payload for an A2UI (Agent to UI) message. A message MUST contain exactly ONE of the action properties.",
                    "properties": [
                        "version": ["type": "string", "const": "v0.9"],
                        "createSurface": [
                            "type": "object",
                            "properties": [
                                "surfaceId": ["type": "string", "description": "The unique identifier for the surface."],
                                "catalogId": ["type": "string", "description": "The URI of the component catalog."],
                                "sendDataModel": ["type": "boolean", "description": "Whether to send the data model to every client request."]
                            ],
                            "required": ["surfaceId", "catalogId"]
                        ],
                        "updateComponents": [
                            "type": "object",
                            "properties": [
                                "surfaceId": ["type": "string", "description": "The unique identifier for the UI surface."],
                                "components": [
                                    "type": "array",
                                    "description": "A flat list of component definitions. Each must have an \"id\" field and match one of the component schemas.",
                                    "minItems": 1,
                                    "items": [
                                        "oneOf": allComponentSchemas,
                                        "description": "Must match one of the component definitions in the catalog."
                                    ]
                                ]
                            ],
                            "required": ["surfaceId", "components"]
                        ],
                        "deleteSurface": [
                            "type": "object",
                            "properties": [
                                "surfaceId": ["type": "string"]
                            ],
                            "required": ["surfaceId"]
                        ]
                    ],
                    "required": ["version"]
                ]
            ],
            "anyOf": [
                ["required": ["createSurface"]],
                ["required": ["updateComponents"]],
                ["required": ["deleteSurface"]]
            ]
        ]

        // Serialize to JSON string
        if let data = try? JSONSerialization.data(withJSONObject: fullSchema, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: data, encoding: .utf8) {
            return "A2UI Message Schema:\n" + jsonString
        }
        return "Error: could not generate catalog schema"
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Gemini API"
        case .apiError(let statusCode, let message):
            let short = extractErrorMessage(from: message)
            return "Gemini API error (\(statusCode)): \(short)"
        }
    }

    private func extractErrorMessage(from raw: String) -> String {
        if let data = raw.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let msg = error["message"] as? String {
            return msg
        }
        return String(raw.prefix(200))
    }
}
