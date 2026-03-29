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

/// Spec v0.9 DateTimeInput — date and/or time picker.
///
/// Spec properties:
/// - `value` (required): DynamicString ISO 8601 string — bound to data model
/// - `enableDate` (optional): show date selector (defaults to true)
/// - `enableTime` (optional): show time selector (defaults to true)
/// - `min` (optional): DynamicString — minimum date bound
/// - `max` (optional): DynamicString — maximum date bound
/// - `label` (optional): DynamicString
///
/// ## Rendering strategy: system `DatePicker`, zero hardcoded values.
///
/// ## Platform behavior:
/// - iOS / macOS / visionOS / watchOS: system `DatePicker`
/// - tvOS: `DatePicker` is unavailable — falls back to read-only text display
struct A2UIDateTimeInput: View {
    let node: ComponentNode
    let surface: SurfaceModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(DateTimeInputProperties.self) {
            let dc = DataContext(surface: surface, path: dataContextPath)
            let enableDate = props.enableDate ?? true
            let enableTime = props.enableTime ?? true

            let labelText: String = {
                if let labelValue = props.label {
                    return dc.resolve(labelValue)
                }
                if enableDate && enableTime { return "Date & Time" }
                if enableDate { return "Date" }
                if enableTime { return "Time" }
                return "Date & Time"
            }()

            let dtStyle = style.dateTimeInputStyle

            let checksError = dc.firstFailingCheckMessage(props.checks)
            VStack(alignment: .leading, spacing: 4) {
                Group {
                    #if os(tvOS)
                    VStack(alignment: .leading) {
                        Text(labelText)
                            .font(dtStyle.labelFont)
                            .foregroundStyle(dtStyle.labelColor ?? .primary)
                        Text(dc.resolve(props.value))
                            .foregroundStyle(.secondary)
                    }
                    #else
                    let components: DatePicker.Components = {
                        var c: DatePicker.Components = []
                        if enableDate { c.insert(.date) }
                        if enableTime { c.insert(.hourAndMinute) }
                        if c.isEmpty { c = [.date, .hourAndMinute] }
                        return c
                    }()

                    DatePicker(
                        selection: a2uiDateBinding(for: props.value, dataContext: dc),
                        displayedComponents: components
                    ) {
                        Text(labelText)
                            .font(dtStyle.labelFont)
                            .foregroundStyle(dtStyle.labelColor ?? .primary)
                    }
                    .tint(dtStyle.tintColor)
                    #endif
                }
                if let msg = checksError {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .a2uiAccessibility(node.accessibility, dataContext: dc)
            .padding(style.leafMargin)
        }
    }
}
