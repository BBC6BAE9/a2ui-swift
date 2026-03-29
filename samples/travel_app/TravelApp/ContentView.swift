// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import v_09

/// The root content view with a navigation-based layout.
/// Provides navigation to the AI chat planner and widget catalog.
struct ContentView: View {
    @AppStorage("geminiAPIKey") private var geminiAPIKey = ""
    @AppStorage("useStreaming") private var useStreaming = false
    @State private var travelViewId = UUID()
    @State private var showSettings = false
    @State private var showCatalog = false

    /// Resolved API key: env var → user-entered key.
    private var resolvedAPIKey: String {
        let stored = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stored.isEmpty { return stored }
        return GetApiKey.resolve()
    }

    private var hasAPIKey: Bool {
        !resolvedAPIKey.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasAPIKey {
                TravelPlannerView(
                    geminiAPIKey: resolvedAPIKey
                )
                    .id(travelViewId)
                } else {
                    APIKeyRequiredView {
                        showSettings = true
                    }
                }
            }
            .navigationTitle("Agentic Travel Inc.")
            #if !os(tvOS) && !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem() {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem() {
                    Button {
                        showCatalog = true
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                }
            }
            .navigationDestination(isPresented: $showCatalog) {
                CatalogView()
                    .navigationTitle("Widget Catalog")
                    #if !os(tvOS) && !os(macOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView(
                        geminiAPIKey: $geminiAPIKey,
                        useStreaming: $useStreaming,
                        onRestartChat: {
                            travelViewId = UUID()
                            showSettings = false
                        }
                    )
                    .navigationTitle("Settings")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showSettings = false }
                        }
                    }
                }
            }
        }
    }

}

// MARK: - Settings

private struct SettingsView: View {
    @Binding var geminiAPIKey: String
    @Binding var useStreaming: Bool
    var onRestartChat: () -> Void

    private var maskedKey: String {
        let key = GetApiKey.resolve()
        guard !key.isEmpty else { return "Not set" }
        guard key.count > 8 else { return "••••••••" }
        return String(key.prefix(4)) + "••••" + String(key.suffix(4))
    }

    var body: some View {
        Form {
            Section {
                Toggle("Streaming Mode", isOn: $useStreaming)
            } footer: {
                Text("When enabled, responses appear incrementally as they are generated. When disabled (default), the complete response is received before display — matching Flutter's behavior and more reliable for complex UI responses.")
            }

            Section {
                NavigationLink {
                    APIKeySettingsView(
                        geminiAPIKey: $geminiAPIKey,
                        onRestartChat: onRestartChat
                    )
                } label: {
                    HStack {
                        Text("API Key")
                        Spacer()
                        Text(maskedKey)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Gemini API")
            } footer: {
                Text("Priority: user-entered key → GEMINI_API_KEY env var.")
            }
        }
    }
}

// MARK: - API Key Settings

private struct APIKeySettingsView: View {
    @Binding var geminiAPIKey: String
    var onRestartChat: () -> Void

    var body: some View {
        Form {
            Section {
                SecureField("API Key", text: $geminiAPIKey)
                    .autocorrectionDisabled()
            } footer: {
                Text("Get a key at [aistudio.google.com](https://aistudio.google.com/apikey). Leave empty to use the GEMINI_API_KEY environment variable.")
            }

            if !geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section {
                    Button("Clear Custom Key", role: .destructive) {
                        geminiAPIKey = ""
                    }
                } footer: {
                    Text("Removes the custom key and falls back to the environment variable.")
                }
            }

            Section {
                Button("Apply & Restart Chat") {
                    onRestartChat()
                }
            }
        }
        .navigationTitle("API Key")
        #if !os(tvOS) && !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - API Key Required

private struct APIKeyRequiredView: View {
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Gemini API Key Required")
                .font(.title2.bold())
            Text("To get started, please enter your Gemini API key in Settings, or set the GEMINI_API_KEY environment variable.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                onOpenSettings()
            } label: {
                Label("Open Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
            Link(
                "Get a free API key",
                destination: URL(string: "https://aistudio.google.com/apikey")!
            )
            .font(.footnote)
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
