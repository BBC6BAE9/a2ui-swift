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

/// Spec v0.8 List — scrollable container for children.
///
/// Spec properties:
/// - `children` (required): explicitList or template — items to display
/// - `direction` (optional): "vertical" | "horizontal" (defaults to vertical)
/// - `alignment` (optional): "start" | "center" | "end" | "stretch" — cross-axis alignment
///
/// ## Rendering strategy: `ScrollView` + `LazyVStack` / `LazyHStack`.
///
/// List is a pure layout container — no tap/hover/focus handling.
/// Interaction is the responsibility of child components (e.g. Button).
///
/// ## Platform behavior:
/// - All platforms: system `ScrollView` with lazy stacks for performance.
struct A2UIList: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    var body: some View {
        if let props = try? node.payload.typedProperties(ListProperties.self) {
            let isHorizontal = props.direction == "horizontal"

            ScrollView(isHorizontal ? .horizontal : .vertical) {
                if isHorizontal {
                    LazyHStack(alignment: a2uiVerticalAlignment(props.alignment)) {
                        ForEach(node.children) { child in
                            A2UIComponentView(node: child, viewModel: viewModel)
                        }
                    }
                } else {
                    LazyVStack(alignment: a2uiHorizontalAlignment(props.alignment)) {
                        ForEach(node.children) { child in
                            A2UIComponentView(node: child, viewModel: viewModel)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("List - Vertical") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"List":{"children":{"explicitList":["l1","l2","l3"]},"direction":"vertical"}}},{"id":"l1","component":{"Text":{"text":{"literalString":"Item 1"}}}},{"id":"l2","component":{"Text":{"text":{"literalString":"Item 2"}}}},{"id":"l3","component":{"Text":{"text":{"literalString":"Item 3"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("List - Horizontal") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"List":{"children":{"explicitList":["h1","h2","h3"]},"direction":"horizontal"}}},{"id":"h1","component":{"Card":{"child":"ht1"}}},{"id":"ht1","component":{"Text":{"text":{"literalString":"Card A"}}}},{"id":"h2","component":{"Card":{"child":"ht2"}}},{"id":"ht2","component":{"Text":{"text":{"literalString":"Card B"}}}},{"id":"h3","component":{"Card":{"child":"ht3"}}},{"id":"ht3","component":{"Text":{"text":{"literalString":"Card C"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
