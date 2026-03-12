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

import SwiftUI
import A2UI

/// Card-style agent page matching the official Lit shell pattern:
///
/// 1. Initial: hero area + search form (pre-filled placeholder, no auto-send)
/// 2. User submits → form hides, loading animation with rotating text
/// 3. Result → A2UI surfaces replace the loading area
/// 4. User action → loading → new surfaces replace old ones
struct AgentCardPage: View {
    let title: String
    let agentURL: URL
    let initialQuery: String
    var loadingTexts: [String] = [
        "Finding the best spots for you...",
        "Checking reviews...",
        "Looking for open tables...",
        "Almost there..."
    ]
    var customRenderer: CustomComponentRenderer? = nil
    
    @State private var manager = SurfaceManager()
    @State private var client: A2AClient?
    @State private var status: ConnectionStatus = .idle
    @State private var actionLog: [ActionLogEntry] = []
    @State private var showLog = false
    @State private var queryText = ""
    @State private var isSending = false
    @State private var contextId: String?
    @State private var loadingTextIndex = 0
    @State private var loadingTimer: Timer?
    @State private var hasResults = false
    
    var body: some View {
        VStack(spacing: 0) {
            switch status {
            case .idle, .connecting:
                ProgressView("Connecting to Agent...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .connected:
                connectedContent
            case .error(let message):
                ContentUnavailableView(
                    "Connection Failed",
                    systemImage: "wifi.exclamationmark",
                    description: Text(message)
                )
            }
        }
        .navigationTitle(title)
#if !os(visionOS) && !os(tvOS)
        .navigationSubtitle(status.subtitle(url: agentURL))
#endif
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showLog.toggle()
                } label: {
                    Label("Log", systemImage: "list.bullet.rectangle")
                }
#if !os(tvOS)
                .badge(actionLog.count)
#endif
                .id(actionLog.count)
            }
        }
#if !os(visionOS) && !os(tvOS)
        .inspector(isPresented: $showLog) {
            actionLogView
                .inspectorColumnWidth(min: 260, ideal: 320, max: 450)
        }
#endif
        .task { await connect() }
    }
    
    // MARK: - Connected Content
    
    private var connectedContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !hasResults && !isSending {
                    heroSection
                } else if isSending {
                    loadingSection
                } else {
                    resultSection
                }
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Hero / Search Form
    
    private var heroSection: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)
            
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            
            Text(title)
                .font(.largeTitle.bold())
            
            HStack(spacing: 8) {
                TextField("What are you looking for?", text: $queryText)
#if !os(tvOS)
                    .textFieldStyle(.roundedBorder)
#endif
                    .onSubmit { submitQuery() }
                
                Button {
                    submitQuery()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .disabled(queryText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if queryText.isEmpty {
                queryText = initialQuery
            }
        }
    }
    
    // MARK: - Loading Animation
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 120)
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text(loadingTexts[loadingTextIndex])
                .font(.callout)
                .foregroundStyle(.secondary)
                .animation(.easeInOut, value: loadingTextIndex)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Result Surfaces
    
    private var resultSection: some View {
        VStack(spacing: 0) {
            // Surfaces
            LazyVStack(spacing: 0) {
                ForEach(manager.orderedSurfaceIds, id: \.self) { surfaceId in
                    if let vm = manager.surfaces[surfaceId],
                       let rootNode = vm.componentTree {
                        A2UIComponentView(node: rootNode, viewModel: vm)
                            .tint(vm.a2uiStyle.primaryColor)
                            .environment(\.a2uiStyle, vm.a2uiStyle)
                            .environment(\.a2uiActionHandler) { action in
                                logAction(action, surfaceId: surfaceId)
                                Task { await sendAction(action, surfaceId: surfaceId) }
                            }
                            .environment(\.a2uiCustomComponentRenderer, customRenderer)
                            .padding()
                    }
                }
            }
        }
    }
    
    // MARK: - Action Log
    
    private var actionLogView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Action Log", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.bold())
                Spacer()
                if !actionLog.isEmpty {
                    Button("Clear") { actionLog.removeAll() }
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
#if !os(tvOS)
            .background(.bar)
#endif
            
            if actionLog.isEmpty {
                Text("Interact with components to see actions here.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(actionLog) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: entry.direction == .outgoing
                                  ? "arrow.up.circle.fill"
                                  : "arrow.down.circle.fill")
                            .foregroundStyle(entry.direction == .outgoing ? .blue : .green)
                            Text(entry.summary).font(.subheadline).bold()
                            Spacer()
                            Text(entry.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if !entry.detail.isEmpty {
                            Text(entry.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - Networking
    
    private var supportsStreaming: Bool {
        client?.agentCard?.streaming == true
    }
    
    private func connect() async {
        status = .connecting
        do {
            let a2aClient = try await A2AClient.fromBaseURL(agentURL)
            client = a2aClient
            logEntry(.incoming, summary: "Connected",
                     detail: "Discovered \(a2aClient.agentCard?.name ?? "Agent") at \(a2aClient.endpointURL)"
                     + (a2aClient.agentCard?.streaming == true ? " (streaming)" : ""))
            status = .connected
        } catch {
            status = .error(error.localizedDescription)
        }
    }
    
    private func submitQuery() {
        let text = queryText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let client else { return }
        queryText = ""
        isSending = true
        startLoadingAnimation()
        logEntry(.outgoing, summary: "Query", detail: text)
        
        Task {
            defer {
                isSending = false
                stopLoadingAnimation()
            }
            if supportsStreaming {
                await handleStream(client.sendTextStream(text, contextId: contextId), summary: "Response")
            } else {
                do {
                    let result = try await client.sendText(text, contextId: contextId)
                    contextId = result.contextId ?? contextId
                    manager.clearAll()
                    processResult(result, summary: "Response")
                } catch {
                    logEntry(.incoming, summary: "Error", detail: error.localizedDescription)
                }
            }
        }
    }
    
    private func sendAction(_ action: ResolvedAction, surfaceId: String) async {
        guard let client else { return }
        isSending = true
        startLoadingAnimation()
        defer {
            isSending = false
            stopLoadingAnimation()
        }
        
        if supportsStreaming {
            await handleStream(
                client.sendActionStream(action, surfaceId: surfaceId, contextId: contextId),
                summary: "Response to \(action.name)"
            )
        } else {
            do {
                let result = try await client.sendAction(action, surfaceId: surfaceId, contextId: contextId)
                contextId = result.contextId ?? contextId
                manager.clearAll()
                processResult(result, summary: "Response to \(action.name)")
            } catch {
                logEntry(.incoming, summary: "Error", detail: error.localizedDescription)
            }
        }
    }
    
    /// Consume SSE stream, show intermediate status, finalize with A2UI content.
    private func handleStream(
        _ stream: AsyncThrowingStream<StreamEvent, Error>,
        summary: String
    ) async {
        var lastResult: SendResult?
        var lastFinalText: String?
        do {
            for try await event in stream {
                switch event {
                case .status(let state, let text, _, let ctx, let isFinal):
                    if let ctx { contextId = ctx }
                    logEntry(.incoming, summary: "Stream [\(state.rawValue)]", detail: text ?? "")
                    if isFinal, let text, !text.isEmpty {
                        lastFinalText = text
                    }
                case .result(let result):
                    if let ctx = result.contextId { contextId = ctx }
                    lastResult = result
                }
            }
            if let result = lastResult {
                manager.clearAll()
                processResult(result, summary: summary)
            } else if let text = lastFinalText {
                manager.clearAll()
                logEntry(.incoming, summary: summary, detail: text)
            } else {
                logEntry(.incoming, summary: summary, detail: "Stream ended without result")
            }
        } catch {
            logEntry(.incoming, summary: "Error", detail: error.localizedDescription)
        }
    }
    
    private func processResult(_ result: SendResult, summary: String) {
        hasResults = true
        var errorCount = 0
        for msg in result.messages {
            do { try manager.processMessage(msg) } catch { errorCount += 1 }
        }
        logEntry(.incoming, summary: summary,
                 detail: "Received \(result.messages.count) message(s), state: \(result.taskState.rawValue)"
                 + (errorCount > 0 ? ", \(errorCount) skipped" : ""))
    }
    
    // MARK: - Loading Animation
    
    private func startLoadingAnimation() {
        loadingTextIndex = 0
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            loadingTextIndex = (loadingTextIndex + 1) % loadingTexts.count
        }
    }
    
    private func stopLoadingAnimation() {
        loadingTimer?.invalidate()
        loadingTimer = nil
    }
    
    // MARK: - Logging
    
    private func logAction(_ action: ResolvedAction, surfaceId: String) {
        let contextStr = action.context.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        logEntry(.outgoing, summary: "\(action.name) [\(surfaceId)]", detail: contextStr)
    }
    
    private func logEntry(_ direction: ActionLogEntry.Direction, summary: String, detail: String) {
        actionLog.append(ActionLogEntry(direction: direction, summary: summary, detail: detail))
    }
}

// MARK: - Supporting Types

private enum ConnectionStatus {
    case idle, connecting, connected, error(String)
    
    func subtitle(url: URL) -> String {
        switch self {
        case .idle: return url.absoluteString
        case .connecting: return "Connecting to \(url.host() ?? url.absoluteString)..."
        case .connected: return "Connected"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

private struct ActionLogEntry: Identifiable {
    let id = UUID()
    let direction: Direction
    let summary: String
    let detail: String
    let timestamp = Date()
    
    enum Direction { case outgoing, incoming }
}
