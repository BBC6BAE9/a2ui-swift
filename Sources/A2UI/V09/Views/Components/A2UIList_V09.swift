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

/// Spec v0.9 List -- scrollable container for children.
///
/// Spec properties:
/// - `children` (required): explicitList or template -- items to display
/// - `direction` (optional): "vertical" | "horizontal" (defaults to vertical)
/// - `align` (optional): "start" | "center" | "end" | "stretch" -- cross-axis alignment
///
/// ## Rendering strategy: `ScrollView` + `LazyVStack` / `LazyHStack`.
///
/// List is a pure layout container -- no tap/hover/focus handling.
/// Interaction is the responsibility of child components (e.g. Button).
///
/// ## Platform behavior:
/// - All platforms: system `ScrollView` with lazy stacks for performance.
struct A2UIList_V09: View {
    let node: ComponentNode_V09
    var viewModel: SurfaceViewModel_V09

    var body: some View {
        if let props = try? node.typedProperties(ListProperties_V09.self) {
            let isHorizontal = props.direction == .horizontal

            ScrollView(isHorizontal ? .horizontal : .vertical) {
                if isHorizontal {
                    LazyHStack(alignment: a2uiVerticalAlignment(props.align?.rawValue)) {
                        ForEach(node.children) { child in
                            A2UIComponentView_V09(node: child, viewModel: viewModel)
                        }
                    }
                } else {
                    LazyVStack(alignment: a2uiHorizontalAlignment(props.align?.rawValue)) {
                        ForEach(node.children) { child in
                            A2UIComponentView_V09(node: child, viewModel: viewModel)
                        }
                    }
                }
            }
        }
    }
}
