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

/// Spec v0.9 Row -> HStack.
/// - `justify`: main-axis (justify-content) via Spacer-based layout in `a2uiDistributedContent`.
/// - `align`: cross-axis (align-items) -> HStack's `VerticalAlignment`; defaults to stretch.
/// - `weight`: handled globally by `WeightModifier` in `A2UIComponentView`, not here.
struct A2UIRow: View {
    let node: ComponentNode
    let surface: SurfaceModel

    var body: some View {
        if let props = try? node.typedProperties(RowProperties.self) {
            let dc = DataContext(surface: surface, path: node.dataContextPath)
            // Web-core default: align="stretch" (row.ts:28)
            let crossStretch = props.align == nil || props.align == .stretch
            HStack(alignment: a2uiVerticalAlignment(props.align), spacing: 0) {
                a2uiDistributedContent(
                    node.children, justify: props.justify,
                    stretchWidth: false, stretchHeight: crossStretch,
                    surface: surface
                )
            }
            .environment(\.a2uiLayoutAxis, .horizontal)
            .a2uiAccessibility(node.accessibility, dataContext: dc)
        }
    }
}
