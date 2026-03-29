// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import A2UISwiftCore
import Primitives

/// A client that uses the Google Generative Language API to generate content.
///
/// Mirrors Flutter's `GoogleGenerativeAiClient` from
/// `ai_client/google_generative_ai_client.dart`.
///
/// Uses non-streaming `generateContent` to match Flutter's approach. Results
/// are pushed to ``a2uiMessageStream`` and ``textResponseStream`` as they are
/// parsed from the model response.
final class GoogleGenerativeAiClient: AiClient {

    // MARK: - Configuration

    /// System instruction fragments provided by the caller (domain-specific).
    /// These are prepended to the standard A2UI protocol instructions.
    let systemInstruction: [String]

    /// Optional catalog schema JSON string. Appended to the system instruction
    /// so the model knows which UI components are available.
    let catalogSchema: String?

    /// Tools available to the AI model.
    let additionalTools: [AiTool]

    /// The Gemini model name (e.g., "gemini-3-flash-preview").
    let modelName: String

    /// The API key for authentication.
    let apiKey: String

    /// The generative service used for API calls.
    /// Mirrors Flutter's dependency on `GoogleGenerativeServiceInterface`.
    private let service: GoogleGenerativeServiceInterface

    // MARK: - Token Usage

    /// Total input tokens consumed across all requests.
    private(set) var inputTokenUsage: Int = 0

    /// Total output tokens consumed across all requests.
    private(set) var outputTokenUsage: Int = 0

    // MARK: - Streams

    private let a2uiContinuation: AsyncStream<A2uiMessage>.Continuation
    private let textContinuation: AsyncStream<String>.Continuation
    private let eventContinuation: AsyncStream<AiGenerationEvent>.Continuation
    private let errorContinuation: AsyncStream<Error>.Continuation

    /// A2UI messages parsed from the model response.
    let a2uiMessageStream: AsyncStream<A2uiMessage>

    /// Text chunks (with JSON blocks stripped) from the model response.
    let textResponseStream: AsyncStream<String>

    /// Generation lifecycle events (tool calls, token usage).
    let eventStream: AsyncStream<AiGenerationEvent>

    /// Errors encountered during generation.
    let errorStream: AsyncStream<Error>

    // MARK: - State

    /// Whether the client is currently processing a request.
    private(set) var isProcessing: Bool = false

    private static let generationConfig: [String: Any] = [
        "maxOutputTokens": 65536,
    ]

    // MARK: - Init

    /// Creates a `GoogleGenerativeAiClient`.
    ///
    /// - Parameters:
    ///   - systemInstruction: Domain-specific prompt fragments (e.g., travel
    ///     agent instructions). The client automatically appends standard A2UI
    ///     protocol instructions.
    ///   - catalogSchema: Optional JSON schema string describing available UI
    ///     components. Typically generated from the catalog definition.
    ///   - additionalTools: Tools the model can invoke (e.g., hotel search).
    ///   - modelName: Gemini model identifier.
    ///   - apiKey: Google AI API key.
    init(
        systemInstruction: [String] = [],
        catalogSchema: String? = nil,
        additionalTools: [AiTool] = [],
        modelName: String = "gemini-3-flash-preview",
        apiKey: String,
        service: GoogleGenerativeServiceInterface? = nil
    ) {
        self.systemInstruction = systemInstruction
        self.catalogSchema = catalogSchema
        self.additionalTools = additionalTools
        self.modelName = modelName
        self.apiKey = apiKey
        self.service = service ?? GoogleGenerativeServiceWrapper(apiKey: apiKey)

        var a2uiCont: AsyncStream<A2uiMessage>.Continuation!
        self.a2uiMessageStream = AsyncStream { a2uiCont = $0 }
        self.a2uiContinuation = a2uiCont

        var textCont: AsyncStream<String>.Continuation!
        self.textResponseStream = AsyncStream { textCont = $0 }
        self.textContinuation = textCont

        var eventCont: AsyncStream<AiGenerationEvent>.Continuation!
        self.eventStream = AsyncStream { eventCont = $0 }
        self.eventContinuation = eventCont

        var errorCont: AsyncStream<Error>.Continuation!
        self.errorStream = AsyncStream { errorCont = $0 }
        self.errorContinuation = errorCont
    }

    func dispose() {
        service.close()
        a2uiContinuation.finish()
        textContinuation.finish()
        eventContinuation.finish()
        errorContinuation.finish()
    }

    // MARK: - AiClient

    func sendRequest(
        _ message: Primitives.ChatMessage,
        history: [Primitives.ChatMessage]? = nil,
        clientDataModel: [String: Any]? = nil
    ) async throws {
        isProcessing = true
        defer { isProcessing = false }

        let messages: [Primitives.ChatMessage]
        if let history {
            messages = history + [message]
        } else {
            messages = [message]
        }

        do {
            try await generate(
                messages: messages,
                clientDataModel: clientDataModel
            )
        } catch is CancellationError {
            print("[GoogleGenerativeAiClient] Request cancelled")
        } catch {
            print("[GoogleGenerativeAiClient] Error: \(error)")
            errorContinuation.yield(error)
            throw error
        }
    }

    // MARK: - Generation

    /// Core generation loop. Converts messages to Gemini format, calls the API,
    /// handles tool-call cycles, and emits results to the output streams.
    ///
    /// Mirrors Flutter's `GoogleGenerativeAiClient._generate()`.
    private func generate(
        messages: [Primitives.ChatMessage],
        clientDataModel: [String: Any]?
    ) async throws {
        var content = GoogleContentConverter.toGeminiContents(messages)
        let tools = buildGeminiTools()
        let systemContent = buildSystemInstruction(clientDataModel: clientDataModel)

        var toolCycle = 0
        let maxToolCycles = 40

        while toolCycle < maxToolCycles {
            try Task.checkCancellation()

            toolCycle += 1
            print("[GoogleGenerativeAiClient] Inference cycle \(toolCycle)")

            let request = GenerateContentRequest(
                model: "models/\(modelName)",
                contents: content,
                systemInstruction: systemContent,
                generationConfig: Self.generationConfig,
                tools: tools.isEmpty ? nil : tools,
                toolConfig: tools.isEmpty ? nil : [
                    "functionCallingConfig": ["mode": "AUTO"],
                ]
            )

            let response = try await service.generateContent(request)

            // Track token usage
            if let usageMetadata = response.usageMetadata {
                let inputTokens = usageMetadata["promptTokenCount"] as? Int ?? 0
                let outputTokens = usageMetadata["candidatesTokenCount"] as? Int ?? 0
                inputTokenUsage += inputTokens
                outputTokenUsage += outputTokens
                eventContinuation.yield(
                    .tokenUsage(inputTokens: inputTokens, outputTokens: outputTokens)
                )
            }

            guard let candidates = response.candidates,
                  let candidate = candidates.first else {
                print("[GoogleGenerativeAiClient] Response has no candidates")
                return
            }

            let finishReason = candidate["finishReason"] as? String
            if finishReason == "MAX_TOKENS" {
                print("[GoogleGenerativeAiClient] Response truncated (MAX_TOKENS)")
            }

            guard let candidateContent = candidate["content"] as? [String: Any],
                  let partsJson = candidateContent["parts"] as? [[String: Any]] else {
                print("[GoogleGenerativeAiClient] No content parts in response")
                return
            }

            var functionCalls: [[String: Any]] = []
            var textParts: [String] = []

            for part in partsJson {
                if part["functionCall"] != nil {
                    functionCalls.append(part)
                } else if let text = part["text"] as? String {
                    textParts.append(text)
                }
            }

            if functionCalls.isEmpty {
                handleTextResponse(textParts: textParts)
                content.append(candidateContent)
                return
            }

            print("[GoogleGenerativeAiClient] \(functionCalls.count) function call(s)")
            content.append(candidateContent)

            let functionResponseParts = try await processFunctionCalls(functionCalls)

            if !functionResponseParts.isEmpty {
                content.append([
                    "role": "user",
                    "parts": functionResponseParts,
                ])
                print(
                    "[GoogleGenerativeAiClient] Added "
                    + "\(functionResponseParts.count) tool response(s)"
                )
            }
        }

        print("[GoogleGenerativeAiClient] Exceeded max tool cycles (\(maxToolCycles))")
    }

    // MARK: - Text & A2UI Parsing

    /// Parses A2UI JSON blocks from the model text, emits them on
    /// ``a2uiMessageStream``, then emits remaining text on ``textResponseStream``.
    private func handleTextResponse(textParts: [String]) {
        let fullText = textParts.joined()
        print("[GoogleGenerativeAiClient] Text response (\(fullText.count) chars)")

        let jsonBlocks = JsonBlockParser.parseJsonBlocks(fullText)
        for block in jsonBlocks {
            guard var json = block as? [String: Any] else { continue }
            // Inject version if missing — matches Flutter's SurfaceController.
            if json["version"] == nil { json["version"] = "v0.9" }
            if let data = try? JSONSerialization.data(withJSONObject: json),
               let message = try? JSONDecoder().decode(A2uiMessage.self, from: data) {
                a2uiContinuation.yield(message)
                print("[GoogleGenerativeAiClient] Emitted A2UI message")
            }
        }

        let cleanText = JsonBlockParser.stripJsonBlock(fullText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanText.isEmpty {
            textContinuation.yield(cleanText)
        }
    }

    // MARK: - Tool Processing

    /// Executes function calls returned by the model and builds Gemini-format
    /// function response parts.
    ///
    /// Mirrors Flutter's `GoogleGenerativeAiClient._processFunctionCalls()`.
    private func processFunctionCalls(
        _ functionCalls: [[String: Any]]
    ) async throws -> [[String: Any]] {
        var functionResponseParts: [[String: Any]] = []

        for callPart in functionCalls {
            guard let functionCall = callPart["functionCall"] as? [String: Any],
                  let callName = functionCall["name"] as? String else {
                continue
            }

            let args = functionCall["args"] as? [String: Any] ?? [:]
            print("[GoogleGenerativeAiClient] Executing tool: \(callName)")

            let tool = additionalTools.first { t in
                t.name == callName || t.fullName == callName
            }

            eventContinuation.yield(.toolStart(toolName: callName, args: args))
            let startTime = Date()

            var result: [String: Any]
            if let tool {
                do {
                    result = try await tool.invoke(args)
                    print("[GoogleGenerativeAiClient] Tool \(callName) succeeded")
                } catch {
                    print("[GoogleGenerativeAiClient] Tool \(callName) error: \(error)")
                    result = ["error": "Tool \(callName) failed: \(error)"]
                }
            } else {
                print("[GoogleGenerativeAiClient] Unknown tool: \(callName)")
                result = ["error": "Unknown tool: \(callName)"]
            }

            let duration = Date().timeIntervalSince(startTime)
            eventContinuation.yield(
                .toolEnd(toolName: callName, result: result, duration: duration)
            )

            functionResponseParts.append([
                "functionResponse": [
                    "name": callName,
                    "response": result,
                ] as [String: Any],
            ])
        }

        return functionResponseParts
    }

    // MARK: - Tool Setup

    /// Converts `additionalTools` to the Gemini `tools` JSON format.
    ///
    /// Each tool is registered under its `name`. If `fullName` differs (i.e.,
    /// the tool has a prefix), it is registered under both names so the model
    /// can call either.
    private func buildGeminiTools() -> [[String: Any]] {
        guard !additionalTools.isEmpty else { return [] }

        var seenNames = Set<String>()
        var declarations: [[String: Any]] = []

        for tool in additionalTools {
            guard !seenNames.contains(tool.name) else {
                print("[GoogleGenerativeAiClient] Duplicate tool \(tool.name) — skipped")
                continue
            }
            seenNames.insert(tool.name)

            var declaration: [String: Any] = [
                "name": tool.name,
                "description": tool.description,
            ]
            if let parameters = tool.parameters {
                let adapter = GoogleSchemaAdapter()
                let result = adapter.adapt(parameters)
                if let schema = result.schema {
                    declaration["parameters"] = schema
                }
                for error in result.errors {
                    print("[GoogleGenerativeAiClient] Schema adaptation: \(error)")
                }
            }
            declarations.append(declaration)

            if tool.name != tool.fullName, !seenNames.contains(tool.fullName) {
                seenNames.insert(tool.fullName)
                var fullDeclaration = declaration
                fullDeclaration["name"] = tool.fullName
                declarations.append(fullDeclaration)
            }
        }

        return [["functionDeclarations": declarations]]
    }

    // MARK: - System Instruction

    /// Assembles the system instruction in Gemini REST API format.
    ///
    /// Assembly order mirrors Flutter's `PromptBuilder.custom()`:
    /// 1. Caller-provided fragments (domain-specific prompts)
    /// 2. "Use the provided tools..." boilerplate
    /// 3. Technical possibilities (IMPORTANT statements)
    /// 4. A2UI controlling-the-UI instructions
    /// 5. A2UI output format instructions
    /// 6. Catalog schema (if provided)
    /// 7. Client data model (if provided)
    private func buildSystemInstruction(
        clientDataModel: [String: Any]?
    ) -> [String: Any] {
        var parts: [[String: Any]] = []

        // 1. Caller-provided fragments
        for fragment in systemInstruction {
            parts.append(["text": fragment])
        }

        // 2. Tool usage boilerplate
        parts.append(["text":
            "Use the provided tools to respond to user using rich UI elements."
        ])

        // 3. Technical possibilities
        parts.append(["text":
            "IMPORTANT: You do not have the ability to execute code. "
            + "If you need to perform calculations, do them yourself."
        ])
        parts.append(["text":
            "IMPORTANT: You do not have the ability to use tools for UI generation."
        ])
        parts.append(["text":
            "IMPORTANT: You do not have the ability to use function calls "
            + "for UI generation."
        ])

        // 4–5. A2UI protocol instructions
        parts.append(["text": Self.controllingTheUI])
        parts.append(["text": Self.outputFormat])

        // 6. Catalog schema
        if let catalogSchema {
            parts.append(["text": catalogSchema])
        }

        // 7. Client data model
        if let clientDataModel, !clientDataModel.isEmpty {
            if let data = try? JSONSerialization.data(
                withJSONObject: clientDataModel,
                options: [.prettyPrinted, .sortedKeys]
            ),
               let dataString = String(data: data, encoding: .utf8) {
                parts.append(["text": "Client Data Model:\n\(dataString)"])
            }
        }

        return ["parts": parts]
    }

    // MARK: - A2UI Protocol Prompts

    /// Matches Flutter's `SurfaceOperations.createAndUpdate(dataModel: true)
    /// .systemPromptFragments` — the "controllingTheUI" fragment.
    private static let controllingTheUI = """
    -----CONTROLLING_THE_UI_START-----
    You can control the UI by outputting valid A2UI JSON messages wrapped in \
    markdown code blocks.

    Supported messages are: `createSurface`, `updateComponents`, `updateDataModel`.

    - `createSurface`: Creates a new surface.
    - `updateComponents`: Updates components in a surface.
    - `updateDataModel`: Updates the data model.

    Properties:

    - `createSurface`: Requires `surfaceId` (you must always use a unique ID \
    for each created surface), `catalogId` (use the catalog ID provided in \
    system instructions), and `sendDataModel: true`.
    - `updateComponents`: Requires `surfaceId` and a list of `components`. One \
    component MUST have `id: "root"`.
    - `updateDataModel`: Requires `surfaceId`, `path` and `value`.

    To create a new UI:
    1. Output a `createSurface` message with a unique `surfaceId` and \
    `catalogId` (use the catalog ID provided in system instructions).
    2. Output an `updateComponents` message with the `surfaceId` and the \
    component definitions.

    To update an existing UI:
    1. Output an `updateComponents` message with the existing `surfaceId` and \
    the new component definitions.
    -----CONTROLLING_THE_UI_END-----
    """

    /// Matches Flutter's `SurfaceOperations.systemPromptFragments` — the
    /// output format section.
    private static let outputFormat = """
    -----OUTPUT_FORMAT_START-----
    When constructing UI, you must output a VALID A2UI JSON object representing \
    one of the A2UI message types (`createSurface`, `updateComponents`, \
    `updateDataModel`).
    - You can treat the A2UI schema as a specification for the JSON you \
    typically output.
    - You may include a brief conversational explanation before or after the \
    JSON block if it helps the user, but the JSON block must be valid and \
    complete.
    - Ensure your JSON is fenced with ```json and ```.
    -----OUTPUT_FORMAT_END-----
    """
}
