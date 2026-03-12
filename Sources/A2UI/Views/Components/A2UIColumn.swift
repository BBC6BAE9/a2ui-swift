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

/// Spec v0.8 Column → VStack.
/// - `distribution`: main-axis (justify-content) via Spacer-based layout in `a2uiDistributedContent`.
/// - `alignment`: cross-axis (align-items) → VStack's `HorizontalAlignment`; defaults to stretch.
/// - `weight`: handled globally by `WeightModifier` in `A2UIComponentView`, not here.
struct A2UIColumn: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    var body: some View {
        if let props = try? node.payload.typedProperties(ColumnProperties.self) {
            // Web-core default: alignment="stretch" (column.ts:28)
            let crossStretch = props.alignment == nil || props.alignment == "stretch"
            VStack(alignment: a2uiHorizontalAlignment(props.alignment), spacing: 8) {
                a2uiDistributedContent(
                    node.children, justify: props.distribution,
                    stretchWidth: crossStretch, stretchHeight: false,
                    viewModel: viewModel
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("Column - Default") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["a","b","c"]}}}},{"id":"a","component":{"Text":{"text":{"literalString":"Item A"}}}},{"id":"b","component":{"Text":{"text":{"literalString":"Item B"}}}},{"id":"c","component":{"Text":{"text":{"literalString":"Item C"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Column - Center Aligned") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["a","b"]},"alignment":"center"}}},{"id":"a","component":{"Text":{"text":{"literalString":"Short"}}}},{"id":"b","component":{"Text":{"text":{"literalString":"A longer text to show centering"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Column - Space Between") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["a","b","c"]},"distribution":"spaceBetween"}}},{"id":"a","component":{"Text":{"text":{"literalString":"Top"}}}},{"id":"b","component":{"Text":{"text":{"literalString":"Middle"}}}},{"id":"c","component":{"Text":{"text":{"literalString":"Bottom"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).frame(height: 300).padding()
    }
}

#Preview("Column - Weight") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["a","b","c"]}}}},{"id":"a","weight":1,"component":{"Text":{"text":{"literalString":"1"}}}},{"id":"b","weight":2,"component":{"Text":{"text":{"literalString":"2"}}}},{"id":"c","weight":1,"component":{"Text":{"text":{"literalString":"1"}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).frame(height: 300).padding()
    }
}
