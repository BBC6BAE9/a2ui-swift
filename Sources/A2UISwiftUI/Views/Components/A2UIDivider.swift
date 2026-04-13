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
import A2UISwiftCore

/// # Divider
/// Maps to `SwiftUI.Divider()`, oriented according to the spec's `axis` property.
/// - `horizontal` (default): full-width horizontal rule
/// - `vertical`: full-height vertical rule
struct A2UIDivider: View {
    let node: ComponentNode
    let surface: SurfaceModel

    @Environment(\.a2uiStyle) private var style

    var body: some View {
        let props = try? node.typedProperties(DividerProperties.self)
        let dc = DataContext(surface: surface, path: node.dataContextPath)
        let axis = props?.axis ?? .horizontal

        Group {
            if axis == .vertical {
                SwiftUI.Divider()
                    .frame(maxHeight: .infinity)
            } else {
                SwiftUI.Divider()
                    .frame(maxWidth: .infinity)
            }
        }
        .a2uiAccessibility(node.accessibility, dataContext: dc)
        .padding(style.leafMargin)
    }
}
