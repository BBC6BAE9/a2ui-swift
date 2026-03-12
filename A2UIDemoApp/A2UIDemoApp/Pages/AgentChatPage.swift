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
import os

private let logger = Logger(subsystem: "com.a2ui.demo", category: "AgentChat")

/// Chat-style agent page: conversation with message history.
///
/// - Bottom chat input bar
/// - Messages accumulate in a scrollable list
/// - Agent responses embed A2UI surfaces inline within chat bubbles
/// - Suitable for conversational agents
struct AgentChatPage: View {
    let title: String
    let agentURL: URL
    
    @State private var client: A2AClient?
    @State private var status: ConnectionStatus = .idle
    @State private var chatMessages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isSending = false
    @State private var contextId: String?
    @State private var showLog = false
    @State private var actionLog: [ActionLogEntry] = []
    
    private let initialQuery: String?
    private let customRenderer: CustomComponentRenderer?
    
    init(title: String, agentURL: URL, initialQuery: String? = nil,
         customRenderer: CustomComponentRenderer? = nil) {
        self.title = title
        self.agentURL = agentURL
        self.initialQuery = initialQuery
        self.customRenderer = customRenderer
    }
    
    var body: some View {
        VStack(spacing: 0) {
            connectedContent
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
            logView
                .inspectorColumnWidth(min: 260, ideal: 320, max: 450)
        }
#endif
        .task { await connect() }
    }
    
    // MARK: - Connected Content
    
    private var connectedContent: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            chatBar
        }
    }
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if chatMessages.isEmpty {
                        if case .error(let msg) = status {
                            ContentUnavailableView(
                                "Connection Failed",
                                systemImage: "wifi.exclamationmark",
                                description: Text(msg)
                            )
                            .padding(.top, 60)
                        }
                    }
                    ForEach(chatMessages) { msg in
                        chatBubble(msg)
                            .id(msg.id)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: chatMessages.count) {
                if let last = chatMessages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func chatBubble(_ msg: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if msg.role == .agent {
                Image(systemName: "cpu")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
            }
            
            VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 8) {
                if let text = msg.text {
                    Text(text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(msg.role == .user ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.quaternary))
                        .foregroundStyle(msg.role == .user ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                if let manager = msg.surfaceManager {
                    ForEach(manager.orderedSurfaceIds, id: \.self) { surfaceId in
                        if let vm = manager.surfaces[surfaceId],
                           let rootNode = vm.componentTree {
                            A2UIComponentView(node: rootNode, viewModel: vm)
                                .tint(vm.a2uiStyle.primaryColor)
                                .environment(\.a2uiStyle, vm.a2uiStyle)
                                .environment(\.a2uiActionHandler) { action in
                                    logAction(action, surfaceId: surfaceId)
                                    Task { await handleAction(action, surfaceId: surfaceId, messageId: msg.id) }
                                }
                                .environment(\.a2uiCustomComponentRenderer, customRenderer)
                                .padding(12)
                                .background(.fill.quaternary)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                
                if msg.isLoading {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(msg.statusText ?? "Thinking…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.15), value: msg.statusText)
                }
            }
            .frame(maxWidth: .infinity, alignment: msg.role == .user ? .trailing : .leading)
            
            if msg.role == .user {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
            }
        }
    }
    
    private var isInputDisabled: Bool {
        isSending || client == nil
    }
    
    private var chatBar: some View {
        HStack(spacing: 8) {
            TextField(client == nil ? "Connecting…" : "Send a message…", text: $inputText)
#if !os(tvOS)
                .textFieldStyle(.roundedBorder)
#endif
                .onSubmit { sendMessage() }
                .disabled(isInputDisabled)
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isInputDisabled)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    // MARK: - Log
    
    private var logView: some View {
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
    
    private func connect() async {
        status = .connecting
        do {
            let a2aClient = try await A2AClient.fromBaseURL(agentURL)
            client = a2aClient
            let streamLabel = a2aClient.agentCard?.streaming == true ? " (streaming)" : ""
            logEntry(.incoming, summary: "Connected",
                     detail: "\(a2aClient.agentCard?.name ?? "Agent") at \(a2aClient.endpointURL)\(streamLabel)")
        } catch {
            // Agent card discovery failed — use direct endpoint
            client = A2AClient(endpointURL: agentURL)
            logEntry(.incoming, summary: "Connected (direct)",
                     detail: "Agent card unavailable, using \(agentURL) directly")
        }
        status = .connected
        
        // Auto-send the initial query if provided
        if let query = initialQuery, !query.isEmpty {
            await sendText(query)
        }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        Task { await sendText(text) }
    }
    
    private var supportsStreaming: Bool {
        client?.agentCard?.streaming == true
    }
    
    private func sendText(_ text: String) async {
        guard let client else { return }
        isSending = true
        defer { isSending = false }
        
        let userMsg = ChatMessage(role: .user, text: text)
        chatMessages.append(userMsg)
        
        let placeholderId = UUID()
        let placeholder = ChatMessage(id: placeholderId, role: .agent, isLoading: true)
        chatMessages.append(placeholder)
        
        logEntry(.outgoing, summary: "Text", detail: text)
        
        if supportsStreaming {
            await handleStream(
                client.sendTextStream(text, contextId: contextId),
                placeholderId: placeholderId,
                actionName: nil
            )
        } else {
            do {
                let result = try await client.sendText(text, contextId: contextId)
                contextId = result.contextId ?? contextId
                replacePlaceholder(placeholderId, with: buildAgentMessage(from: result))
                logEntry(.incoming, summary: "Response",
                         detail: "\(result.messages.count) message(s), state: \(result.taskState.rawValue)")
            } catch {
                replacePlaceholder(placeholderId, with: ChatMessage(role: .agent, text: "Error: \(error.localizedDescription)"))
                logEntry(.incoming, summary: "Error", detail: error.localizedDescription)
            }
        }
    }
    
    private func handleAction(_ action: ResolvedAction, surfaceId: String, messageId: UUID) async {
        guard let client else { return }
        isSending = true
        defer { isSending = false }
        
        let placeholderId = UUID()
        let placeholder = ChatMessage(id: placeholderId, role: .agent, isLoading: true)
        chatMessages.append(placeholder)
        
        logEntry(.outgoing, summary: "\(action.name) [\(surfaceId)]",
                 detail: action.context.map { "\($0.key): \($0.value)" }.joined(separator: ", "))
        
        if supportsStreaming {
            await handleStream(
                client.sendActionStream(action, surfaceId: surfaceId, contextId: contextId),
                placeholderId: placeholderId,
                actionName: action.name
            )
        } else {
            do {
                let result = try await client.sendAction(action, surfaceId: surfaceId, contextId: contextId)
                contextId = result.contextId ?? contextId
                replacePlaceholder(placeholderId, with: buildAgentMessage(from: result))
                logEntry(.incoming, summary: "Response to \(action.name)",
                         detail: "\(result.messages.count) message(s), state: \(result.taskState.rawValue)")
            } catch {
                replacePlaceholder(placeholderId, with: ChatMessage(role: .agent, text: "Error: \(error.localizedDescription)"))
                logEntry(.incoming, summary: "Error", detail: error.localizedDescription)
            }
        }
    }
    
    /// Consume SSE stream events, update the placeholder in real-time with status text,
    /// and finalize with A2UI content when the result arrives.
    private func handleStream(
        _ stream: AsyncThrowingStream<StreamEvent, Error>,
        placeholderId: UUID,
        actionName: String?
    ) async {
        var lastResult: SendResult?
        var lastFinalText: String?
        let label = actionName.map { "Response to \($0)" } ?? "Response"
        
        do {
            for try await event in stream {
                switch event {
                case .status(let state, let text, _, let ctx, let isFinal):
                    if let ctx { contextId = ctx }
                    let statusText = text ?? state.rawValue
                    updatePlaceholderStatus(placeholderId, text: statusText)
                    logger.info("[A2UI] Stream status: \(state.rawValue) text=\(text ?? "nil") final=\(isFinal)")
                    logEntry(.incoming, summary: "Stream [\(state.rawValue)]", detail: text ?? "")
                    // When the agent sends a final status with text but no A2UI content
                    // (e.g. "completed" with a plain text reply), capture it as fallback.
                    if isFinal, let text, !text.isEmpty {
                        lastFinalText = text
                    }
                    
                case .result(let result):
                    if let ctx = result.contextId { contextId = ctx }
                    logger.info("[A2UI] Stream result: \(result.messages.count) messages, state=\(result.taskState.rawValue)")
                    lastResult = result
                }
            }
            
            if let result = lastResult {
                replacePlaceholder(placeholderId, with: buildAgentMessage(from: result))
                logEntry(.incoming, summary: label,
                         detail: "\(result.messages.count) message(s), state: \(result.taskState.rawValue)")
            } else if let text = lastFinalText {
                replacePlaceholder(placeholderId, with: ChatMessage(role: .agent, text: text))
                logEntry(.incoming, summary: label, detail: text)
            } else {
                replacePlaceholder(placeholderId, with: ChatMessage(role: .agent, text: "Stream ended without result."))
                logEntry(.incoming, summary: label, detail: "No result in stream")
            }
        } catch {
            replacePlaceholder(placeholderId, with: ChatMessage(role: .agent, text: "Error: \(error.localizedDescription)"))
            logEntry(.incoming, summary: "Error", detail: error.localizedDescription)
        }
    }
    
    private func updatePlaceholderStatus(_ id: UUID, text: String) {
        if let idx = chatMessages.firstIndex(where: { $0.id == id }) {
            chatMessages[idx].statusText = text
        }
    }
    
    private func buildAgentMessage(from result: SendResult) -> ChatMessage {
        if result.messages.isEmpty {
            return ChatMessage(role: .agent, text: "No response from agent.")
        }
        let mgr = SurfaceManager()
        var errorDetails: [String] = []
        for (i, msg) in result.messages.enumerated() {
            // Log raw message JSON for debugging
            if let data = try? JSONEncoder().encode(msg),
               let json = String(data: data, encoding: .utf8) {
                let truncated = json.count > 500 ? String(json.prefix(500)) + "…" : json
                logger.info("[A2UI] Message[\(i)] raw: \(truncated)")
                logEntry(.incoming, summary: "Msg[\(i)] raw", detail: truncated)
            }
            do {
                try mgr.processMessage(msg)
            } catch {
                let errMsg = "Message[\(i)] failed: \(error)"
                logger.error("[A2UI] \(errMsg)")
                errorDetails.append(errMsg)
            }
        }
        // Log surface/data model state
        for surfaceId in mgr.orderedSurfaceIds {
            if let vm = mgr.surfaces[surfaceId] {
                let hasTree = vm.componentTree != nil
                let nodeType = vm.componentTree.map { "\($0.type)" } ?? "nil"
                let childCount = vm.componentTree?.children.count ?? 0
                logger.info("[A2UI] Surface[\(surfaceId)] tree=\(hasTree) rootType=\(nodeType) children=\(childCount)")
                logEntry(.incoming, summary: "Surface[\(surfaceId)]",
                         detail: "tree=\(hasTree) rootType=\(nodeType) children=\(childCount)")
                // Log data model keys
                let dataKeys = vm.dataStoreKeys
                if !dataKeys.isEmpty {
                    let keysStr = dataKeys.joined(separator: ", ")
                    logger.info("[A2UI] Surface[\(surfaceId)] dataKeys: \(keysStr)")
                    logEntry(.incoming, summary: "Data[\(surfaceId)]", detail: keysStr)
                }
            }
        }
        if !errorDetails.isEmpty {
            return ChatMessage(role: .agent, text: errorDetails.joined(separator: "\n"), surfaceManager: mgr)
        }
        return ChatMessage(role: .agent, surfaceManager: mgr)
    }
    
    private func replacePlaceholder(_ id: UUID, with message: ChatMessage) {
        if let idx = chatMessages.firstIndex(where: { $0.id == id }) {
            chatMessages[idx] = message
        } else {
            chatMessages.append(message)
        }
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

private struct ChatMessage: Identifiable {
    let id: UUID
    let role: Role
    var text: String?
    var surfaceManager: SurfaceManager?
    var isLoading: Bool
    var statusText: String?
    
    init(id: UUID = UUID(), role: Role, text: String? = nil,
         surfaceManager: SurfaceManager? = nil, isLoading: Bool = false,
         statusText: String? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.surfaceManager = surfaceManager
        self.isLoading = isLoading
        self.statusText = statusText
    }
    
    enum Role { case user, agent }
}

private enum ConnectionStatus {
    case idle, connecting, connected, error(String)
    
    func subtitle(url: URL) -> String {
        switch self {
        case .idle: return url.absoluteString
        case .connecting: return "Connecting to \(url.host() ?? url.absoluteString)…"
        case .connected: return "Connected · \(url.absoluteString)"
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
