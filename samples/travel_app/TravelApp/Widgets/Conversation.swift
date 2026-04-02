// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI
import Primitives
/// The conversation list view showing messages and dynamic A2UI surfaces.
///
/// Mirrors Flutter's `Conversation` widget from `widgets/conversation.dart`.
struct Conversation: View {
    let messages: [ConversationEntry]
    let viewModel: TravelPlannerViewModel
    
    var body: some View {
        ForEach(messages) { message in
            switch message.role {
            case .user:
                if let text = message.text {
                    UserMessageBubble(text: text)
                }
            case .model, .system:
                if message.isLoading {
                    LoadingBubble(statusText: message.statusText)
                } else if let text = message.text {
                    ModelMessageBubble(text: text)
                } else if let surfaceIds = message.surfaceIds {
                    SurfaceListView(surfaceIds: surfaceIds, viewModel: viewModel)
                }
            }
        }
    }
}

// MARK: - A2UI Surface Rendering

/// Renders surfaces by ID from the shared SurfaceManager on the viewModel.
/// Matches Flutter's pattern where each message references surfaceIds
/// and the Surface widget looks them up from the shared SurfaceController.
private struct SurfaceListView: View {
    let surfaceIds: [String]
    let viewModel: TravelPlannerViewModel
    
    var body: some View {
        // Read surfaceUpdateCounter to ensure this view re-evaluates
        // when surfaces are updated in-place via updateComponents.
        let _ = viewModel.surfaceUpdateCounter
        
        ForEach(surfaceIds, id: \.self) { surfaceId in
            if let vm = viewModel.surfaceViewModels[surfaceId],
               let rootNode = vm.componentTree {
                A2UIComponentView(node: rootNode, surface: vm.surface)
                    .a2uiCatalog(TravelCatalog())
                    .a2uiLeafMargin(0)
                    .environment(\.a2uiActionHandler) { action in
                        Task { @MainActor in
                            viewModel.handleAction(action, surfaceId: surfaceId)
                        }
                    }
                    .a2uiCatalogItem(.text) { ctx in
                        AnyView(
                            ctx.buildDefaultView()
                                .padding(16)
                        )
                    }
                    .a2uiImageResolver { urlString in
                        let name = a2uiExtractAssetName(from: urlString)
#if canImport(UIKit)
                        guard UIImage(named: name) != nil else { return nil }
#elseif canImport(AppKit)
                        guard NSImage(named: name) != nil else { return nil }
#endif
                        return Image(name)
                    }
                    .padding(.vertical, Constants.messageVerticalPadding)
            }
        }
    }
}

// MARK: - Message Bubbles

struct UserMessageBubble: View {
    let text: String
    
    var body: some View {
        HStack {
            Spacer(minLength: 60)
            HStack(spacing: 12) {
                Text(text)
                    .font(.body)
                Image(systemName: "person.fill")
            }
            .padding(14)
            .background(.regularMaterial)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 25,
                    bottomLeadingRadius: 25,
                    bottomTrailingRadius: 25,
                    topTrailingRadius: 5
                )
            )
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .padding(.vertical, Constants.messageVerticalPadding)
        .padding(.horizontal)
    }
}

/// Model message bubble with Card style and robot icon.
/// Mirrors Flutter's `ChatMessageView` with `Icons.smart_toy_outlined`.
struct ModelMessageBubble: View {
    let text: String
    
    var body: some View {
        HStack {
            HStack(alignment: .center, spacing: 12) {
                Image("smart_toy")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .padding(.top, 2)
                MarkdownWidget(text: text)
            }
            .padding(14)
            .background(.regularMaterial)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 5,
                    bottomLeadingRadius: 25,
                    bottomTrailingRadius: 25,
                    topTrailingRadius: 25
                )
            )
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            Spacer(minLength: 60)
        }
        .padding(.vertical, Constants.messageVerticalPadding)
        .padding(.horizontal)
    }
}

struct LoadingBubble: View {
    let statusText: String?
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(statusText ?? "Thinking...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .clipShape(Capsule())
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, Constants.messageVerticalPadding)
    }
}

// MARK: - Markdown rendering
//
// `MarkdownWidget` is defined in `Utils.swift`, mirroring Flutter's
// `MarkdownWidget` from `utils.dart`.

#Preview {
    ScrollView {
        Conversation(
            messages: [
                .agent("Welcome!"),
                .user("Plan a trip to Greece"),
                .agent("Here's a plan with **bold**, _italic_, and `code`.\n\n- Item 1\n- Item 2"),
            ],
            viewModel: TravelPlannerViewModel(transport: GeminiTravelTransport(apiKey: ""))
        )
    }
}

#Preview {
    ScrollView {
        Conversation(
            messages: [
                .agent("I'd love to help you plan a trip! To get started, what king of experience are you looking for?"),
            ],
            viewModel: TravelPlannerViewModel(transport: GeminiTravelTransport(apiKey: ""))
        )
    }
}
