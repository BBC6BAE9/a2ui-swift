// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

// MARK: - Data Model

struct InformationCardData {
    let title: String
    let subtitle: String?
    let body: String
    let imageName: String?
}

// MARK: - View

/// A card displaying detailed information about a travel destination.
/// Equivalent to the Flutter `InformationCard` catalog component.
struct InformationCardView: View {
    let data: InformationCardData
    var imageNode: ComponentNode? = nil
    var surface: SurfaceModel? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let node = imageNode, let surface {
                A2UIComponentView(node: node, surface: surface)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
            } else if let imageName = data.imageName {
                let assetName = a2uiExtractAssetName(from: imageName)
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(data.title)
                    .font(.title2)
                    .fontWeight(.bold)

                if let subtitle = data.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(markdownAttributed(data.body))
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .padding()
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .frame(maxWidth: 400)
    }
}

// MARK: - A2UI Wrapper

/// Renders an `InformationCard` from an A2UI `ComponentNode`.
struct A2UIInformationCardView: View {
    let node: ComponentNode
    let children: [ComponentNode]
    let surface: SurfaceModel

    private var props: [String: AnyCodable] { node.instance.properties }

    var body: some View {
        let title = A2UIHelpers.resolveString(props["title"], surface: surface, dataContextPath: node.dataContextPath) ?? ""
        let subtitle = A2UIHelpers.resolveString(props["subtitle"], surface: surface, dataContextPath: node.dataContextPath)
        let body = A2UIHelpers.resolveString(props["body"], surface: surface, dataContextPath: node.dataContextPath) ?? ""

        let imageNode: ComponentNode? = {
            guard let imageChildId = props["imageChildId"]?.stringValue,
                  let model = surface.componentsModel.get(imageChildId) else { return nil }
            let raw = RawComponent(id: model.id, component: model.type, properties: model.properties)
            return ComponentNode(
                id: model.id,
                baseComponentId: model.id,
                type: raw.componentType,
                dataContextPath: node.dataContextPath,
                weight: nil,
                instance: raw
            )
        }()

        InformationCardView(
            data: InformationCardData(
                title: title,
                subtitle: subtitle,
                body: body,
                imageName: nil
            ),
            imageNode: imageNode,
            surface: imageNode != nil ? surface : nil
        )
        .padding(.horizontal)
    }
}

#Preview {
    InformationCardView(data: MockData.santoriniInfo)
        .padding()
}
