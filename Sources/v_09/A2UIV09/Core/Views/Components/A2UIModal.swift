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
/// Spec v0.9 Modal — trigger-activated sheet container.
///
/// Spec properties:
/// - `trigger` (required): component ID that opens the modal when its Button fires an action.
/// - `content` (required): component ID displayed inside the sheet.
///
/// Rendering strategy:
/// - Trigger renders as-is; interaction is handled by the Button inside it (action handler intercept).
/// - Content is presented via `.sheet` with `NavigationStack` + `ScrollView`.
/// - Close button uses `.cancellationAction` placement (top-leading, standard iOS dismiss position).
///
/// Platform differences:
/// - iOS / macOS / visionOS: `.presentationDetents([.medium, .large])` + `.presentationBackground(.regularMaterial)`.
/// - watchOS / tvOS: plain `.sheet` (no detent or material APIs available).
struct A2UIModal: View {
    let node: ComponentNode
    let surface: SurfaceModel

    var body: some View {
        // children[0] = trigger, children[1] = content
        if node.children.count >= 2 {
            let dc = DataContext(surface: surface, path: node.dataContextPath)
            ModalNodeView(
                triggerNode: node.children[0],
                contentNode: node.children[1],
                uiState: node.uiState as? ModalUIState ?? ModalUIState(),
                surface: surface
            )
            .a2uiAccessibility(node.accessibility, dataContext: dc)
        }
    }
}

// MARK: - ModalNodeView

/// Modal that reads isPresented from `ModalUIState`.
struct ModalNodeView: View {
    let triggerNode: ComponentNode
    let contentNode: ComponentNode
    var uiState: ModalUIState
    let surface: SurfaceModel

    @Environment(\.a2uiActionHandler) private var parentActionHandler
    @Environment(\.a2uiStyle) private var style

    var body: some View {
        let modalStyle = style.modalStyle

        A2UIComponentView(
            node: triggerNode,
            surface: surface
        )
        .environment(\.a2uiActionHandler) { action in
            MainActor.assumeIsolated {
                uiState.isPresented = true
                parentActionHandler?(action)
            }
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
            surface: surface
        )
        if let padding {
            content.padding(padding)
        } else {
            content.padding()
        }
    }
}
