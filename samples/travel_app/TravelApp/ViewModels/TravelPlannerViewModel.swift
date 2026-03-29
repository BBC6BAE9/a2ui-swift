// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI
import Primitives
/// The main view model managing the travel planning conversation.
/// Uses the A2UI SDK to process server messages and render dynamic surfaces.
///
/// Mirrors the Flutter architecture: a single persistent `MessageProcessor` receives
/// all messages across the conversation, so surfaces can be updated in-place by
/// subsequent `updateComponents` messages.
@Observable
final class TravelPlannerViewModel {
    var messages: [ConversationEntry] = []
    var isProcessing: Bool = false

    /// Bumped whenever surfaces are updated in-place to force SwiftUI re-renders.
    var surfaceUpdateCounter: Int = 0

    /// Bumped to signal the view should scroll to bottom.
    /// Mirrors Flutter's explicit `_scrollToBottom()` calls in travel_planner_page.dart.
    var scrollTrigger: Int = 0

    /// Persistent message processor — shared across the entire conversation.
    /// Supports both the canonical `travelAppCatalog` (from `Catalog.swift`,
    /// mirroring Flutter's `catalog.dart`) and a legacy short-id alias so mock
    /// data with `catalogId: "travel"` still works.
    let messageProcessor = MessageProcessor(
        catalogs: [
            travelAppCatalog,
            Catalog(
                id: "travel",
                componentNames: basicCatalog.componentNames.union(Set(TravelComponentNames.allNames)),
                functions: basicCatalog.functions
            ),
        ]
    )

    /// Per-surface SwiftUI view models, keyed by surfaceId.
    /// Updated in sync with messageProcessor as surfaces are created/deleted.
    var surfaceViewModels: [String: SurfaceViewModel] = [:]

    /// Subscription token for surface creation events (kept alive for lifetime of viewModel).
    private var surfaceCreatedSubscription: Subscription?

    private(set) var transport: TravelTransport
    private var contextId: String?

    func setStreaming(_ enabled: Bool) {
        (transport as? GeminiTravelTransport)?.supportsStreaming = enabled
    }

    init(transport: TravelTransport) {
        self.transport = transport
        // Subscribe to surface creation to auto-create SurfaceViewModels
        surfaceCreatedSubscription = messageProcessor.onSurfaceCreated { [weak self] surfaceModel in
            guard let self else { return }
            let vm = SurfaceViewModel(surface: surfaceModel)
            self.surfaceViewModels[surfaceModel.id] = vm
        }
    }

    private func scrollToBottom() {
        scrollTrigger += 1
    }

    // MARK: - Actions

    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isProcessing else { return }

        messages.append(.user(text))
        let loadingIndex = messages.count
        messages.append(.loading())
        isProcessing = true
        scrollToBottom()

        Task { @MainActor in
            do {
                let response = try await withRetry {
                    if let stream = self.transport.sendTextStream(text, contextId: self.contextId) {
                        return try await self.collectStream(stream, loadingIndex: loadingIndex)
                    } else {
                        return try await self.transport.sendText(text, contextId: self.contextId)
                    }
                }
                contextId = response.contextId ?? contextId
                handleTransportResponse(response, loadingIndex: loadingIndex)
            } catch {
                replaceLoading(at: loadingIndex, with: .agent("Sorry, something went wrong: \(error.localizedDescription)"))
                scrollToBottom()
            }
            isProcessing = false
        }
    }

    /// Handle a UI action (button click, carousel tap, trailhead selection).
    /// Unlike `sendMessage`, this does NOT show a user bubble in the chat,
    /// but does show a loading indicator while waiting for the response.
    func handleAction(_ action: ResolvedAction, surfaceId: String) {
        guard !isProcessing else { return }

        let loadingIndex = messages.count
        messages.append(.loading(statusText: "Working..."))
        isProcessing = true
        scrollToBottom()

        // Set the client data model on the transport so Gemini has full context
        // about the current UI state — matching Flutter's A2uiTransportAdapter.
        updateClientDataModel()

        Task { @MainActor in
            do {
                let response = try await withRetry {
                    if let stream = self.transport.sendActionStream(action, surfaceId: surfaceId, contextId: self.contextId) {
                        return try await self.collectStream(stream, loadingIndex: loadingIndex)
                    } else {
                        return try await self.transport.sendAction(action, surfaceId: surfaceId, contextId: self.contextId)
                    }
                }
                contextId = response.contextId ?? contextId
                handleTransportResponse(response, loadingIndex: loadingIndex)
            } catch {
                replaceLoading(at: loadingIndex, with: .agent("Sorry, something went wrong: \(error.localizedDescription)"))
                scrollToBottom()
            }
            isProcessing = false
        }
    }

    // MARK: - Private

    /// Handle a transport response: process A2UI messages, show text, or handle in-place updates.
    private func handleTransportResponse(_ response: TransportResponse, loadingIndex: Int) {
        let agentMessage = processServerMessages(response.messages)
        let hasText = response.textResponse?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        // Check if the loading slot was replaced by streaming text during collectStream
        let slotHasStreamedText = loadingIndex < messages.count && messages[loadingIndex].role == .model && !messages[loadingIndex].isLoading && messages[loadingIndex].text != nil

        if let agentMessage {
            if slotHasStreamedText {
                // Keep the streamed text and append the surface message after it
                messages.append(agentMessage)
            } else if hasText, let text = response.textResponse {
                replaceLoading(at: loadingIndex, with: .agent(text))
                messages.append(agentMessage)
            } else {
                replaceLoading(at: loadingIndex, with: agentMessage)
            }
        } else if hasText, let text = response.textResponse {
            if !slotHasStreamedText {
                replaceLoading(at: loadingIndex, with: .agent(text))
            }
        } else if slotHasStreamedText {
            // Streaming text is already shown — nothing more to do
        } else {
            // In-place update only or empty response — remove loading
            removeLoading(at: loadingIndex)
        }
        scrollToBottom()
    }

    /// Process server messages through the persistent MessageProcessor and build a ConversationEntry.
    /// Only newly created surfaces get added to a new ConversationEntry.
    /// Surfaces that are merely updated (via updateComponents on an existing surfaceId)
    /// are updated in-place and re-rendered by the ConversationEntry that originally referenced them.
    private func processServerMessages(_ serverMessages: [A2uiMessage]) -> ConversationEntry? {
        if serverMessages.isEmpty {
            return nil
        }

        // Track which surfaces are newly created vs merely updated
        var newSurfaceIds: [String] = []
        var hasUpdates = false
        for msg in serverMessages {
            if case .createSurface(let payload) = msg {
                if !newSurfaceIds.contains(payload.surfaceId) {
                    newSurfaceIds.append(payload.surfaceId)
                }
            } else {
                hasUpdates = true
            }
        }

        // Auto-create surfaces for updateComponents that reference a surface
        // not yet created. In streaming mode, the model may emit updateComponents
        // before (or without) a separate createSurface message. Flutter avoids
        // this because it uses non-streaming generateContent and processes all
        // JSON blocks at once.
        for msg in serverMessages {
            if case .updateComponents(let payload) = msg {
                let sid = payload.surfaceId
                if messageProcessor.model.getSurface(sid) == nil {
                    let autoCreate = A2uiMessage.createSurface(CreateSurfacePayload(
                        surfaceId: sid,
                        catalogId: travelAppCatalog.id,
                        sendDataModel: true
                    ))
                    messageProcessor.processMessages([autoCreate])
                    if !newSurfaceIds.contains(sid) {
                        newSurfaceIds.append(sid)
                    }
                    print("[TravelVM] Auto-created surface '\(sid)' for orphan updateComponents")
                }
            }
        }

        // Process all messages through the MessageProcessor (creates SurfaceModels)
        // and then forward each message to the corresponding SurfaceViewModel.
        do {
            messageProcessor.processMessages(serverMessages)

            // For newly created surfaces, the SurfaceViewModel was auto-created
            // by the onSurfaceCreated subscription in init. Now forward all messages to them.
            for msg in serverMessages {
                switch msg {
                case .createSurface(let payload):
                    try surfaceViewModels[payload.surfaceId]?.processMessage(msg)
                case .updateComponents(let payload):
                    try surfaceViewModels[payload.surfaceId]?.processMessage(msg)
                case .updateDataModel(let payload):
                    try surfaceViewModels[payload.surfaceId]?.processMessage(msg)
                case .deleteSurface(let payload):
                    try surfaceViewModels[payload.surfaceId]?.processMessage(msg)
                    surfaceViewModels.removeValue(forKey: payload.surfaceId)
                }
            }
        } catch {
            return ConversationEntry.agent("Failed to render: \(error.localizedDescription)")
        }

        if newSurfaceIds.isEmpty {
            // All changes were in-place updates — bump counter to ensure re-render.
            if hasUpdates {
                surfaceUpdateCounter += 1
                scrollToBottom()
            }
            return nil
        }

        return ConversationEntry.agentSurface(ids: newSurfaceIds)
    }

    /// Collect a stream into a single TransportResponse.
    ///
    /// Mirrors Flutter's A2uiParserTransformer pipeline:
    /// - `.text` events → streamed prose updates the chat bubble in real-time
    /// - `.message` events → immediately processed by MessageProcessor (surfaces appear mid-stream)
    ///
    /// This means JSON blocks NEVER reach the UI as text, and surfaces render
    /// as soon as the LLM finishes generating each JSON block — exactly like Flutter.
    private func collectStream(_ stream: AsyncThrowingStream<StreamEvent, Error>, loadingIndex: Int) async throws -> TransportResponse {
        var streamingText = ""

        // Incremental parser — mirrors A2uiParserTransformer in Flutter.
        let parser = A2UIStreamParser()

        // Consume parser events concurrently while feeding chunks below.
        let parserTask = Task { @MainActor in
            for await event in parser.events {
                switch event {
                case .text(let chunk):
                    // Prose text: update streaming bubble in real-time (JSON already stripped)
                    let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    streamingText += chunk
                    if loadingIndex < self.messages.count {
                        self.messages[loadingIndex] = ConversationEntry.agent(streamingText)
                    }
                    self.scrollToBottom()

                case .message(let msg):
                    // A2UI message: process immediately — mirrors Flutter's
                    // incomingMessages → SurfaceController.handleMessage()
                    if let agentMsg = self.processServerMessages([msg]) {
                        self.messages.append(agentMsg)
                        self.scrollToBottom()
                    }

                case .error:
                    break
                }
            }
        }

        for try await event in stream {
            switch event {
            case .textChunk(let chunk):
                // Feed through parser — it separates prose from JSON blocks
                await parser.add(chunk)

            case .status(_, let text, _, let ctxId, _):
                if let ctxId { contextId = ctxId }
                if loadingIndex < messages.count && messages[loadingIndex].isLoading {
                    messages[loadingIndex].statusText = text ?? "Working..."
                }

            case .result(let r):
                // Tool-use path: final messages from non-streaming follow-up call.
                // Process any messages that weren't already handled inline.
                if !r.messages.isEmpty {
                    if let agentMsg = processServerMessages(r.messages) {
                        messages.append(agentMsg)
                        scrollToBottom()
                    }
                }
                if let ctxId = r.contextId { contextId = ctxId }
            }
        }

        // Flush any buffered text (e.g. trailing prose after last JSON block)
        await parser.finish()
        await parserTask.value

        // Remove the loading/streaming bubble if nothing was shown
        if loadingIndex < messages.count && messages[loadingIndex].isLoading {
            removeLoading(at: loadingIndex)
        }

        // Return empty — all processing was done inline above
        return TransportResponse(messages: [], contextId: nil, textResponse: nil)
    }

    private func withRetry<T>(maxAttempts: Int = 3, operation: @escaping () async throws -> T) async throws -> T {
        let retryableCodes = [
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorTimedOut,
        ]
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch let error as NSError where retryableCodes.contains(error.code) {
                lastError = error
                if attempt < maxAttempts {
                    let delay = Double(attempt) * 2.0
                    print("[TravelVM] Retryable error \(error.code) (attempt \(attempt)/\(maxAttempts)), retrying in \(delay)s...")
                    try? await Task.sleep(for: .seconds(delay))
                }
            }
        }
        throw lastError!
    }

    private func replaceLoading(at index: Int, with message: ConversationEntry) {
        if index < messages.count && messages[index].isLoading {
            messages[index] = message
        } else {
            messages.append(message)
        }
    }

    private func removeLoading(at index: Int) {
        if index < messages.count && messages[index].isLoading {
            messages.remove(at: index)
        }
    }

    /// Sync the client data model from all surfaces to the transport,
    /// matching Flutter's pattern of including data model in system instructions.
    private func updateClientDataModel() {
        guard let geminiTransport = transport as? GeminiTravelTransport else { return }
        geminiTransport.clientDataModel = messageProcessor.getClientDataModel()
    }
}
