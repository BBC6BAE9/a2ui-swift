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

/// # Icon
/// Standard icons: SF Symbol via `A2UIStyle.sfSymbolName()` mapping (SPEC uses Material naming).
/// Fixed 24×24 frame per icon for grid alignment — matches web-core's `width:1em; height:1em`
/// approach with Material Symbols font.
/// Custom SVG path: delegates to `SVGIconView` which uses a custom `Layout` to size the Canvas
/// based on the current font's line height (no hardcoded size, adapts to Dynamic Type).
struct A2UIIcon: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(IconProperties.self) {
            switch props.name {
            case .standard(let nameValue):
                let name = viewModel.resolveString(
                    nameValue, dataContextPath: dataContextPath
                )
                let symbolName = style.sfSymbolName(for: normalizeIconName(name))
                Image(systemName: symbolName)
            case .customPath(let svgPath):
                SVGIconView(svgPath: svgPath)
            }
        }
    }

    /// Normalizes snake_case icon names (from server/Material) to camelCase
    /// to match `IconName` raw values.
    private func normalizeIconName(_ name: String) -> String {
        guard name.contains("_") else { return name }
        let parts = name.split(separator: "_")
        guard let first = parts.first else { return name }
        return String(first) + parts.dropFirst().map { $0.capitalized }.joined()
    }
}

// MARK: - Previews

#Preview("Icon - Standard") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["i1","i2","i3","i4"]}}}},{"id":"i1","component":{"Icon":{"name":{"literalString":"home"}}}},{"id":"i2","component":{"Icon":{"name":{"literalString":"search"}}}},{"id":"i3","component":{"Icon":{"name":{"literalString":"favorite"}}}},{"id":"i4","component":{"Icon":{"name":{"literalString":"settings"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Icon - Custom SVG Path") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Icon":{"name":{"path":"M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
