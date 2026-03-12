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

/// # Modal
/// Spec v0.8 Modal — entry-point-triggered sheet container.
///
/// Spec properties:
/// - `entryPointChild` (required): component ID that opens the modal when its Button fires an action.
/// - `contentChild` (required): component ID displayed inside the sheet.
///
/// Rendering strategy:
/// - Entry point renders as-is; interaction is handled by the Button inside it (action handler intercept).
/// - Content is presented via `.sheet` with `NavigationStack` + `ScrollView`.
/// - Close button uses `.cancellationAction` placement (top-leading, standard iOS dismiss position).
///
/// Platform differences:
/// - iOS / macOS / visionOS: `.presentationDetents([.medium, .large])` + `.presentationBackground(.regularMaterial)`.
/// - watchOS / tvOS: plain `.sheet` (no detent or material APIs available).
struct A2UIModal: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    var body: some View {
        // children[0] = entryPoint, children[1] = content
        if node.children.count >= 2 {
            ModalNodeView(
                entryPointNode: node.children[0],
                contentNode: node.children[1],
                uiState: node.uiState as? ModalUIState ?? ModalUIState(),
                viewModel: viewModel
            )
        }
    }
}

// MARK: - ModalNodeView

/// Modal that reads isPresented from `ModalUIState`.
struct ModalNodeView: View {
    let entryPointNode: ComponentNode
    let contentNode: ComponentNode
    var uiState: ModalUIState
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiActionHandler) private var parentActionHandler
    @Environment(\.a2uiStyle) private var style

    var body: some View {
        let modalStyle = style.modalStyle

        A2UIComponentView(
            node: entryPointNode,
            viewModel: viewModel
        )
        .environment(\.a2uiActionHandler) { action in
            uiState.isPresented = true
            parentActionHandler?(action)
        }
        .sheet(isPresented: Binding(
            get: { uiState.isPresented },
            set: { uiState.isPresented = $0 }
        )) {
            NavigationStack {
                ScrollView {
                    contentView(padding: modalStyle.contentPadding)
                }
                .toolbar {
                    if modalStyle.showCloseButton ?? true {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                uiState.isPresented = false
                            } label: {
                                Image(systemName: "xmark")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            #if os(iOS) || os(macOS) || os(visionOS)
            .presentationDetents([.medium, .large])
            .presentationBackground(.regularMaterial)
            #endif
        }
    }

    @ViewBuilder
    private func contentView(padding: CGFloat?) -> some View {
        let content = A2UIComponentView(
            node: contentNode,
            viewModel: viewModel
        )
        if let padding {
            content.padding(padding)
        } else {
            content.padding()
        }
    }
}

// MARK: - Previews

#Preview("Modal") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Modal":{"entryPointChild":"mbtn","contentChild":"mcol"}}},{"id":"mbtn","component":{"Button":{"child":"mbtn-text","action":{"name":"open_modal"}}}},{"id":"mbtn-text","component":{"Text":{"text":{"literalString":"Open Modal"}}}},{"id":"mcol","component":{"Column":{"children":{"explicitList":["mh","mp"]}}}},{"id":"mh","component":{"Text":{"text":{"literalString":"Modal Title"},"usageHint":"h3"}}},{"id":"mp","component":{"Text":{"text":{"literalString":"This is a modal dialog."}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Modal - Long Content") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Modal":{"entryPointChild":"mbtn","contentChild":"mcol"}}},{"id":"mbtn","component":{"Button":{"child":"mbtn-text","action":{"name":"open_modal"}}}},{"id":"mbtn-text","component":{"Text":{"text":{"literalString":"Open Long Modal"}}}},{"id":"mcol","component":{"Column":{"children":{"explicitList":["mh","mp1","mp2","mp3","mp4"]}}}},{"id":"mh","component":{"Text":{"text":{"literalString":"Scrollable Content"},"usageHint":"h3"}}},{"id":"mp1","component":{"Text":{"text":{"literalString":"Paragraph one with enough text to demonstrate scrolling behavior inside the modal sheet presentation."}}}},{"id":"mp2","component":{"Text":{"text":{"literalString":"Paragraph two continues with more content to fill the sheet and trigger scroll."}}}},{"id":"mp3","component":{"Text":{"text":{"literalString":"Paragraph three adds even more text so the content exceeds the medium detent height."}}}},{"id":"mp4","component":{"Text":{"text":{"literalString":"Paragraph four rounds out the long content preview."}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
