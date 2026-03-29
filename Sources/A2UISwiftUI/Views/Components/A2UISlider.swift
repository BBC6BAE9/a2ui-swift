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

/// Spec v0.9 Slider — numeric range input.
///
/// Spec properties:
/// - `value` (required): DynamicNumber — bound to data model
/// - `min` (optional): minimum bound (defaults to 0)
/// - `max` (optional): maximum bound (defaults to 1)
/// - `label` (optional): DynamicString
///
/// ## Rendering strategy: system `Slider`, zero hardcoded values.
///
/// ## Platform behavior:
/// - iOS / macOS / visionOS / watchOS: system `Slider`
/// - tvOS: `Slider` is unavailable — falls back to +/- `Button` pair with
///   `ProgressView` for visual feedback. Step size is 1/20 of the range.
struct A2UISlider: View {
    let node: ComponentNode
    let surface: SurfaceModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(SliderProperties.self) {
            let dc = DataContext(surface: surface, path: dataContextPath)
            let minVal = props.min ?? 0
            let maxVal = props.max
            let sliderStyle = style.sliderStyle
            let binding = a2uiDoubleBinding(for: props.value, fallback: minVal, dataContext: dc)

            let checksError = dc.firstFailingCheckMessage(props.checks)
            VStack(alignment: .leading) {
                if let labelValue = props.label {
                    let labelText = dc.resolve(labelValue)
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
                if let msg = checksError {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(style.textFieldStyle.errorColor ?? .red)
                }
            }
            .a2uiAccessibility(node.accessibility, dataContext: dc)
            .padding(style.leafMargin)
        }
    }
}
