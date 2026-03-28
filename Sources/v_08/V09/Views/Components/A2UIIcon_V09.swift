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
/// Fixed 24x24 frame per icon for grid alignment -- matches web-core's `width:1em; height:1em`
/// approach with Material Symbols font.
/// Custom SVG path: delegates to `SVGIconView` which uses a custom `Layout` to size the Canvas
/// based on the current font's line height (no hardcoded size, adapts to Dynamic Type).
struct A2UIIcon_V09: View {
    let node: ComponentNode_V09
    var viewModel: SurfaceViewModel_V09

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(IconProperties_V09.self) {
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
