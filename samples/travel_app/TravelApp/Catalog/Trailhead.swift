// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

// MARK: - Data Model

struct TrailheadData {
    let topics: [String]
    let actionName: String
}

// MARK: - View

/// Presents suggested follow-up topics as tappable chips.
/// Equivalent to the Flutter `Trailhead` catalog component.
struct TrailheadView: View {
    let data: TrailheadData
    var onTopicSelected: ((String) -> Void)?

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(data.topics, id: \.self) { topic in
                Button {
                    onTopicSelected?(topic)
                } label: {
                    Text(topic)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
                                .background(Capsule().fill(Color.accentColor.opacity(0.05)))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

// MARK: - A2UI Wrapper

/// Renders a `Trailhead` from an A2UI `ComponentNode`.
struct A2UITrailheadView: View {
    let node: ComponentNode
    let surface: SurfaceModel
    @Environment(\.a2uiActionHandler) private var actionHandler

    private var props: [String: AnyCodable] { node.instance.properties }

    var body: some View {
        let topics = A2UIHelpers.resolveStringList(props["topics"], surface: surface, dataContextPath: node.dataContextPath)

        FlowLayout(spacing: 8) {
            ForEach(topics, id: \.self) { topic in
                Button {
                    if let baseAction = A2UIHelpers.resolveAction(props["action"], node: node, surface: surface) {
                        var ctx = baseAction.context
                        ctx["topic"] = .string(topic)
                        let action = ResolvedAction(
                            name: baseAction.name,
                            sourceComponentId: baseAction.sourceComponentId,
                            context: ctx
                        )
                        actionHandler?(action)
                    }
                } label: {
                    Text(topic)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
                                .background(Capsule().fill(Color.accentColor.opacity(0.05)))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

#Preview("Trailhead") {
    TrailheadView(data: MockData.postItinerarySuggestions)
}
