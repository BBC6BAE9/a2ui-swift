// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

// MARK: - A2UI View

/// Renders a `TabbedSections` from an A2UI `ComponentNode`.
/// Equivalent to the Flutter `TabbedSections` catalog component.
struct A2UITabbedSectionsView: View {
    let node: ComponentNode
    let children: [ComponentNode]
    let surface: SurfaceModel

    private var props: [String: AnyCodable] { node.instance.properties }
    @State private var selectedTab = 0

    private var sections: [SectionInfo] {
        guard case .array(let sectionsArray) = props["sections"] else { return [] }
        return sectionsArray.compactMap { sectionVal -> SectionInfo? in
            guard case .dictionary(let dict) = sectionVal else { return nil }
            let title = A2UIHelpers.resolveString(dict["title"], surface: surface, dataContextPath: node.dataContextPath) ?? ""
            let childId = dict["child"]?.stringValue
            let childNode: ComponentNode? = childId.flatMap { cid in
                children.first { $0.baseComponentId == cid }
            }
            return SectionInfo(title: title, childNode: childNode)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                    Button {
                        withAnimation { selectedTab = index }
                    } label: {
                        Text(section.title)
                            .font(.subheadline)
                            .fontWeight(selectedTab == index ? .semibold : .regular)
                            .foregroundStyle(selectedTab == index ? .primary : .secondary)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .bottom) {
                                if selectedTab == index {
                                    Rectangle()
                                        .fill(Color.accentColor)
                                        .frame(height: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            if selectedTab < sections.count, let childNode = sections[selectedTab].childNode {
                A2UIComponentView(node: childNode, surface: surface)
            }
        }
    }

    private struct SectionInfo {
        let title: String
        let childNode: ComponentNode?
    }
}
