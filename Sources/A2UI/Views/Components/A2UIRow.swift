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

/// Spec v0.8 Row → HStack.
/// - `distribution`: main-axis (justify-content) via Spacer-based layout in `a2uiDistributedContent`.
/// - `alignment`: cross-axis (align-items) → HStack's `VerticalAlignment`; defaults to stretch.
/// - `weight`: handled globally by `WeightModifier` in `A2UIComponentView`, not here.
struct A2UIRow: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    var body: some View {
        if let props = try? node.payload.typedProperties(RowProperties.self) {
            // Web-core default: alignment="stretch" (row.ts:28)
            let crossStretch = props.alignment == nil || props.alignment == "stretch"
            HStack(alignment: a2uiVerticalAlignment(props.alignment)) {
                a2uiDistributedContent(
                    node.children, justify: props.distribution,
                    stretchWidth: false, stretchHeight: crossStretch,
                    viewModel: viewModel
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("Row - Default") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["a","b","c"]}}}},{"id":"a","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"b","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"c","component":{"Text":{"text":{"literalString":"C"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Row - Space Between") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["a","b","c"]},"distribution":"spaceBetween"}}},{"id":"a","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"b","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"c","component":{"Text":{"text":{"literalString":"C"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Row - Alignment Center") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["a","b"]},"alignment":"center"}}},{"id":"a","component":{"Text":{"text":{"literalString":"Short"}}}},{"id":"b","component":{"Text":{"text":{"literalString":"Tall\\nMulti\\nLine"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Row - Weight") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["a","b","c"]}}}},{"id":"a","weight":1,"component":{"Text":{"text":{"literalString":"1"}}}},{"id":"b","weight":2,"component":{"Text":{"text":{"literalString":"2"}}}},{"id":"c","weight":1,"component":{"Text":{"text":{"literalString":"1"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
