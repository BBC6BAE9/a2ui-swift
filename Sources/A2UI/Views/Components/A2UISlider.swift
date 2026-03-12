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

/// Spec v0.8 Slider — numeric range input.
///
/// Spec properties:
/// - `value` (required): literalNumber or path — bound to data model
/// - `minValue` (optional): minimum bound (defaults to 0)
/// - `maxValue` (optional): maximum bound (defaults to 1)
///
/// Note: `label` is not in Spec v0.8 (`additionalProperties: false`), but
/// the renderer supports it when present for UI context. The server-side
/// validator enforces the schema — if `label` is absent, we simply skip it.
///
/// ## Rendering strategy: system `Slider`, zero hardcoded values.
///
/// Uses `SwiftUI.Slider` directly — the system's native range input control.
/// This is intentionally NOT a media-style progress slider (like AVPlayer's):
/// A2UI Slider is a general-purpose numeric input (volume, rating, price range),
/// not a playback scrubber. Media playback has its own AudioPlayer/Video components.
///
/// ## Platform behavior:
/// - iOS / macOS / visionOS / watchOS: system `Slider`
/// - tvOS: `Slider` is unavailable — falls back to +/- `Button` pair with
///   `ProgressView` for visual feedback. Step size is 1/20 of the range.
struct A2UISlider: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(SliderProperties.self) {
            let minVal = props.minValue ?? 0
            let maxVal = props.maxValue ?? 1
            let sliderStyle = style.sliderStyle
            let binding = a2uiDoubleBinding(for: props.value, fallback: minVal, viewModel: viewModel, dataContextPath: dataContextPath)

            VStack(alignment: .leading) {
                if let labelValue = props.label {
                    let labelText = viewModel.resolveString(
                        labelValue, dataContextPath: dataContextPath
                    )
                    HStack {
                        Text(labelText)
                            .font(sliderStyle.labelFont)
                            .foregroundStyle(sliderStyle.labelColor ?? .primary)
                        Spacer()
                        Text(sliderStyle.valueFormatter(binding.wrappedValue))
                            .font(sliderStyle.valueFont ?? .body.monospacedDigit())
                            .foregroundStyle(sliderStyle.valueColor ?? .secondary)
                    }
                }
                #if os(tvOS)
                HStack {
                    Button {
                        binding.wrappedValue = max(minVal, binding.wrappedValue - (maxVal - minVal) / 20)
                    } label: {
                        Image(systemName: "minus")
                    }
                    ProgressView(value: binding.wrappedValue - minVal, total: maxVal - minVal)
                    Button {
                        binding.wrappedValue = min(maxVal, binding.wrappedValue + (maxVal - minVal) / 20)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                #else
                SwiftUI.Slider(value: binding, in: minVal...maxVal)
                    .tint(sliderStyle.tintColor)
                #endif
            }
        }
    }
}

// MARK: - Previews

#Preview("Slider - Basic") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Slider":{"value":{"path":"/val"},"minValue":0,"maxValue":100}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"val","valueNumber":50}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Slider - With Label") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Slider":{"label":{"literalString":"Volume"},"value":{"path":"/volume"},"minValue":0,"maxValue":100}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"volume","valueNumber":50}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Slider - Value Only (no min/max)") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Slider":{"label":{"literalString":"Opacity"},"value":{"path":"/opacity"}}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"opacity","valueNumber":0.7}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Slider - Decimal Range") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Slider":{"label":{"literalString":"Temperature"},"value":{"path":"/temp"},"minValue":36.0,"maxValue":42.0}}}]}}
    {"dataModelUpdate":{"surfaceId":"s","path":"/","contents":[{"key":"temp","valueNumber":37.5}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}
