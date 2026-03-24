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

/// A2UI ProgressBar — display-only progress indicator.
///
/// Maps to `SwiftUI.ProgressView`:
/// - **Determinate**: `ProgressView(value:total:)` when `value` is present.
/// - **Indeterminate**: `ProgressView()` (spinner) when `value` is absent.
///
/// Read-only — never writes to the data model. Agents drive progress updates
/// by streaming `dataModelUpdate` messages targeting the bound `value` path.
///
/// ## Platform behavior
/// `ProgressView` is available on all platforms (iOS, macOS, tvOS, watchOS,
/// visionOS) — no `#if os(...)` fallbacks required.
struct A2UIProgressBar: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(ProgressBarProperties.self) {
            ProgressBarNodeView(
                props: props,
                viewModel: viewModel,
                dataContextPath: dataContextPath,
                pbStyle: style.progressBarStyle
            )
        }
    }
}

// MARK: - ProgressBarNodeView

private struct ProgressBarNodeView: View {
    let props: ProgressBarProperties
    let viewModel: SurfaceViewModel
    let dataContextPath: String
    let pbStyle: A2UIStyle.ProgressBarComponentStyle

    var body: some View {
        let minVal = props.minValue ?? 0
        let maxVal = props.maxValue ?? 100

        VStack(alignment: .leading, spacing: 4) {
            if let labelValue = props.label {
                let labelText = viewModel.resolveString(labelValue, dataContextPath: dataContextPath)
                if !labelText.isEmpty {
                    Text(labelText)
                        .font(pbStyle.labelFont)
                        .foregroundStyle(pbStyle.labelColor ?? .primary)
                }
            }

            if let numberValue = props.value {
                let current = viewModel.resolveNumber(numberValue, dataContextPath: dataContextPath) ?? minVal
                ProgressView(value: current - minVal, total: maxVal - minVal)
                    .tint(pbStyle.tintColor)
            } else {
                ProgressView()
                    .tint(pbStyle.tintColor)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Previews

#Preview("ProgressBar - Determinate") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"ProgressBar":{"label":{"literalString":"Uploading..."},"value":{"path":"/progress"},"minValue":0,"maxValue":100}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"progress","valueNumber":65}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("ProgressBar - Indeterminate") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"ProgressBar":{"label":{"literalString":"Generating response..."}}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("ProgressBar - No label") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"ProgressBar":{"value":{"path":"/p"},"minValue":0,"maxValue":10}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"p","valueNumber":3}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
