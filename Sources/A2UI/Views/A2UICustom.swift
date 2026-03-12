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

struct A2UICustom: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiCustomComponentRenderer) private var customRenderer

    var body: some View {
        if case .custom(let typeName) = node.type {
            if let renderer = customRenderer,
               let customView = renderer(typeName, node, node.children, viewModel) {
                customView
            } else {
                // Fallback: render children in a VStack
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(node.children) { child in
                        A2UIComponentView(node: child, viewModel: viewModel)
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Custom - Unknown Fallback") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Canvas":{"children":{"explicitList":["t1"]}}}},{"id":"t1","component":{"Text":{"text":{"literalString":"Child of custom component"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
