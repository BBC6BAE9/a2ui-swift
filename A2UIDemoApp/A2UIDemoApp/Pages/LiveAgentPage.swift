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

// Mirrors the DEMO_ITEMS array from the official Lit component-gallery.
private struct DemoItem: Identifiable {
    let id: String        // surfaceId from agent
    let title: String
    let description: String
    let dataPath: String? // non-nil → show "Log Value" button
}

private let demoItems: [DemoItem] = [
    .init(id: "demo-text", title: "TextField", description: "Allows user to enter text. Supports binding to data model.", dataPath: "galleryData/textField"),
    .init(id: "demo-text-regex", title: "TextField (Regex)", description: "TextField with 5-digit regex validation.", dataPath: "galleryData/textFieldRegex"),
    .init(id: "demo-checkbox", title: "CheckBox", description: "A binary toggle.", dataPath: "galleryData/checkbox"),
    .init(id: "demo-slider", title: "Slider", description: "Select a value from a range.", dataPath: "galleryData/slider"),
    .init(id: "demo-date", title: "DateTimeInput", description: "Pick a date or time.", dataPath: "galleryData/date"),
    .init(id: "demo-mc-single-checkbox", title: "Single Select — Picker", description: "Pick one (Picker/Radio).", dataPath: "galleryData/singleCheckbox"),
    .init(id: "demo-mc-single-chips", title: "Single Select — Chips", description: "Pick one (Chips).", dataPath: "galleryData/singleChips"),
    .init(id: "demo-mc-multi-checkbox", title: "Multi Select — Checkbox", description: "Select multiple (Checkmark).", dataPath: "galleryData/multiCheckbox"),
    .init(id: "demo-mc-multi-chips", title: "Multi Select — Chips", description: "Select multiple (Chips).", dataPath: "galleryData/multiChips"),
    .init(id: "demo-mc-filter-checkbox", title: "Filterable — Checkbox", description: "Search and filter (Checkmark).", dataPath: "galleryData/filterCheckbox"),
    .init(id: "demo-mc-filter-chips", title: "Filterable — Chips", description: "Search and filter (Chips).", dataPath: "galleryData/filterChips"),
    .init(id: "demo-image", title: "Image", description: "Displays an image from a URL.", dataPath: nil),
    .init(id: "demo-button", title: "Button", description: "Triggers a client-side action.", dataPath: nil),
    .init(id: "demo-tabs", title: "Tabs", description: "Switch between different views.", dataPath: nil),
    .init(id: "demo-icon", title: "Icon", description: "Standard icons.", dataPath: nil),
    .init(id: "demo-divider", title: "Divider", description: "Visual separation.", dataPath: nil),
    .init(id: "demo-card", title: "Card", description: "A container for other components.", dataPath: nil),
    .init(id: "demo-video", title: "Video", description: "Video player.", dataPath: nil),
    .init(id: "demo-modal", title: "Modal", description: "Overlay dialog.", dataPath: nil),
    .init(id: "demo-list", title: "List", description: "Vertical or horizontal list.", dataPath: nil),
    .init(id: "demo-audio", title: "AudioPlayer", description: "Play audio content.", dataPath: nil),
]

struct LiveAgentPage: View {
    let agentURL: URL
    let initialQuery: String
    
    @State private var manager = SurfaceManager()
    @State private var client: A2AClient?
    @State private var status: ConnectionStatus = .idle
    @State private var actionLog: [ActionLogEntry] = []
    @State private var inspectorMode: InspectorMode?
    
    var body: some View {
        Group {
            switch status {
            case .idle, .connecting:
                ProgressView("Connecting to Agent…")
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
        .navigationTitle("Live Agent")
#if !os(visionOS) && !os(tvOS)
        .navigationSubtitle(status.subtitle(url: agentURL))
#endif
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 4) {
                    Button {
                        inspectorMode = inspectorMode == .info ? nil : .info
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                    Button {
                        inspectorMode = inspectorMode == .log ? nil : .log
                    } label: {
                        Label("Log", systemImage: "list.bullet.rectangle")
                    }
#if !os(tvOS)
                    .badge(actionLog.count)
#endif
                }
                .id(actionLog.count)
            }
        }
#if !os(visionOS) && !os(tvOS)
        .inspector(isPresented: Binding(
            get: { inspectorMode != nil },
            set: { if !$0 { inspectorMode = nil } }
        )) {
            Group {
                switch inspectorMode {
                case .info:
                    aboutView
                case .log:
                    actionLogView
                case nil:
                    EmptyView()
                }
            }
            .inspectorColumnWidth(min: 260, ideal: 320, max: 450)
        }
        .task { await connect() }
#endif
    }
    
    // MARK: - Connected Layout
    
    private var connectedContent: some View {
        galleryPane
    }
    
    // MARK: - Gallery Pane (scrollable cards)
    
    private var galleryPane: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(demoItems) { item in
                    demoCard(for: item)
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func demoCard(for item: DemoItem) -> some View {
        let vm = manager.surfaces[item.id]
        let rootNode = vm?.componentTree
        
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            if let rootNode, let vm {
                A2UIComponentView(node: rootNode, viewModel: vm)
                    .tint(vm.a2uiStyle.primaryColor)
                    .environment(\.a2uiStyle, vm.a2uiStyle)
                    .environment(\.a2uiActionHandler) { action in
                        logAction(action, surfaceId: item.id)
                        Task { await sendAction(action, surfaceId: item.id) }
                    }
            } else {
                Text("Surface not loaded")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            if let dataPath = item.dataPath, let vm {
                Divider()
                HStack {
                    Spacer()
                    Button("Log Value") {
                        logDataValue(vm: vm, path: dataPath, item: item)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - About Inspector
    
    private var aboutView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Component Gallery Agent")
                    .font(.title3.bold())
                
                Text("This page connects to the Component Gallery Agent — a deterministic (non-AI) A2UI server that returns hardcoded JSON for all 18 standard components.")
                
                if let vm = manager.surfaces["response-surface"],
                   let rootNode = vm.componentTree {
                    Section("Agent Response") {
                        A2UIComponentView(node: rootNode, viewModel: vm)
                            .tint(vm.a2uiStyle.primaryColor)
                            .environment(\.a2uiStyle, vm.a2uiStyle)
                    }
                }
                
                Section("How it works") {
                    VStack(alignment: .leading, spacing: 8) {
                        bulletPoint("1", "Client sends \"START_GALLERY\" to Agent")
                        bulletPoint("2", "Agent returns ~50 A2UI messages (beginRendering + surfaceUpdate + dataModelUpdate for each component)")
                        bulletPoint("3", "Client renders each Surface as a card")
                        bulletPoint("4", "User interacts → userAction sent to Agent → Agent returns surfaceUpdate for response-surface")
                    }
                }
                
                Section("Action flow") {
                    VStack(alignment: .leading, spacing: 8) {
                        bulletPoint("Log Value", "Reads the data model value at the component's bound path and sends it to the Agent as a shell_log_value action")
                        bulletPoint("Trigger Action", "Sends the Button's configured action (with context) to the Agent")
                    }
                }
                
                Section("Agent") {
                    LabeledContent("URL", value: agentURL.absoluteString)
                    LabeledContent("Protocol", value: "A2A JSON-RPC")
                    LabeledContent("AI Model", value: "None (hardcoded)")
                    LabeledContent("Surfaces", value: "\(manager.orderedSurfaceIds.count)")
                }
                .font(.caption)
            }
            .padding()
        }
    }
    
    private func bulletPoint(_ label: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.tint)
                .frame(minWidth: 20)
            Text(text)
                .font(.caption)
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
        let a2aClient = A2AClient(endpointURL: agentURL)
        client = a2aClient
        
        do {
            let result = try await a2aClient.sendText(initialQuery)
            var errorCount = 0
            for msg in result.messages {
                do {
                    try manager.processMessage(msg)
                } catch {
                    errorCount += 1
                }
            }
            logEntry(.incoming, summary: "Initial load", detail: "Received \(result.messages.count) message(s)" + (errorCount > 0 ? ", \(errorCount) skipped" : ""))
            status = .connected
        } catch {
            status = .error(error.localizedDescription)
        }
    }
    
    private func sendAction(_ action: ResolvedAction, surfaceId: String) async {
        guard let client else { return }
        
        do {
            let result = try await client.sendAction(action, surfaceId: surfaceId)
            for msg in result.messages {
                try? manager.processMessage(msg)
            }
            if !result.messages.isEmpty {
                logEntry(.incoming, summary: "Response to \(action.name)", detail: "Received \(result.messages.count) message(s)")
            }
        } catch {
            logEntry(.incoming, summary: "Error", detail: error.localizedDescription)
        }
    }
    
    // MARK: - Log Value (mirrors Lit demo's #logValue)
    
    private func logDataValue(vm: SurfaceViewModel, path: String, item: DemoItem) {
        let value = vm.resolveString(StringValue(path: path))
        logAction(
            ResolvedAction(name: "shell_log_value", sourceComponentId: "log-btn", context: [
                "path": .string(path),
                "value": .string(value),
                "component": .string(item.title),
            ]),
            surfaceId: item.id
        )
        Task { await sendLogValueAction(surfaceId: item.id, path: path, value: value, component: item.title) }
    }
    
    private func sendLogValueAction(surfaceId: String, path: String, value: String, component: String) async {
        guard let client else { return }
        let action = ResolvedAction(
            name: "shell_log_value",
            sourceComponentId: "shell-log-btn",
            context: [
                "path": .string(path),
                "value": .string(value),
                "component": .string(component),
            ]
        )
        do {
            let result = try await client.sendAction(action, surfaceId: surfaceId)
            for msg in result.messages {
                try? manager.processMessage(msg)
            }
            if !result.messages.isEmpty {
                logEntry(.incoming, summary: "Response to log_value", detail: "Received \(result.messages.count) message(s)")
            }
        } catch {
            logEntry(.incoming, summary: "Error", detail: error.localizedDescription)
        }
    }
    
    // MARK: - Logging Helpers
    
    private func logAction(_ action: ResolvedAction, surfaceId: String) {
        let contextStr = action.context.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        logEntry(.outgoing, summary: "\(action.name) [\(surfaceId)]", detail: contextStr)
    }
    
    private func logEntry(_ direction: ActionLogEntry.Direction, summary: String, detail: String) {
        actionLog.append(ActionLogEntry(direction: direction, summary: summary, detail: detail))
    }
}

// MARK: - Supporting Types

private enum InspectorMode {
    case info, log
}

private enum ConnectionStatus {
    case idle, connecting, connected, error(String)
    
    var label: String {
        switch self {
        case .idle: "Idle"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .error: "Error"
        }
    }
    
    var dotColor: Color {
        switch self {
        case .idle: .gray
        case .connecting: .orange
        case .connected: .green
        case .error: .red
        }
    }
    
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
