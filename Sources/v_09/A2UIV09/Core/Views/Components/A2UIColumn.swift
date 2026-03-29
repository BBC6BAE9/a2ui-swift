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

/// Spec v0.9 Column -> VStack.
/// - `justify`: main-axis (justify-content) via Spacer-based layout in `a2uiDistributedContent`.
/// - `align`: cross-axis (align-items) -> VStack's `HorizontalAlignment`; defaults to stretch.
/// - `weight`: handled globally by `WeightModifier` in `A2UIComponentView`, not here.
struct A2UIColumn: View {
    let node: ComponentNode
    let surface: SurfaceModel

    var body: some View {
        if let props = try? node.typedProperties(ColumnProperties.self) {
            let dc = DataContext(surface: surface, path: node.dataContextPath)
            // Web-core default: align="stretch" (column.ts:28)
            let crossStretch = props.align == nil || props.align == .stretch
            VStack(alignment: a2uiHorizontalAlignment(props.align?.rawValue), spacing: 8) {
                a2uiDistributedContent(
                    node.children, justify: props.justify,
                    stretchWidth: crossStretch, stretchHeight: false,
                    surface: surface
                )
            }
            .a2uiAccessibility(node.accessibility, dataContext: dc)
        }
    }
}
