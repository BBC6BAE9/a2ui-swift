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
/// - `enableDate` (optional): show date selector (defaults to **false** per spec)
/// - `enableTime` (optional): show time selector (defaults to **false** per spec)
/// - `min` (optional): DynamicString ISO 8601 — minimum selectable date
/// - `max` (optional): DynamicString ISO 8601 — maximum selectable date
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
            // ③ Spec v0.9 defaults: enableDate and enableTime are both false when omitted.
            let enableDate = props.enableDate ?? false
            let enableTime = props.enableTime ?? false

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

            // ② Resolve optional min/max ISO 8601 bounds.
            let minDate: Date? = props.min.map { dc.resolve($0) }.flatMap { parseISO8601($0) }
            let maxDate: Date? = props.max.map { dc.resolve($0) }.flatMap { parseISO8601($0) }

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

                    // ② Wire min/max to DatePicker's `in:` range.
                    datePickerView(
                        selection: a2uiDateBinding(for: props.value, dataContext: dc),
                        minDate: minDate,
                        maxDate: maxDate,
                        components: components,
                        label: {
                            Text(labelText)
                                .font(dtStyle.labelFont)
                                .foregroundStyle(dtStyle.labelColor ?? .primary)
                        }
                    )
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

    // MARK: - Helpers

#if !os(tvOS)
    /// Returns a `DatePicker` configured with the appropriate date range.
    /// Four variants exist because `DatePicker`'s `in:` parameter is generic over
    /// `RangeExpression<Date>`, requiring concrete type branches.
    @ViewBuilder
    private func datePickerView(
        selection: Binding<Date>,
        minDate: Date?,
        maxDate: Date?,
        components: DatePicker.Components,
        @ViewBuilder label: () -> some View
    ) -> some View {
        if let lo = minDate, let hi = maxDate {
            DatePicker(selection: selection, in: lo...hi, displayedComponents: components, label: label)
        } else if let lo = minDate {
            DatePicker(selection: selection, in: lo..., displayedComponents: components, label: label)
        } else if let hi = maxDate {
            DatePicker(selection: selection, in: ...hi, displayedComponents: components, label: label)
        } else {
            DatePicker(selection: selection, displayedComponents: components, label: label)
        }
    }
#endif

    /// Parses an ISO 8601 date string, tolerating both full date-time and date-only formats.
    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: string)
    }
}
