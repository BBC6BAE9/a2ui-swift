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

// MARK: - Two-way Binding Helpers
//
// These helpers bridge A2UI DynamicValue types to SwiftUI `Binding<T>`.
//
// get: reads PathSlot.value via DataContext — SwiftUI builds a per-path reactive dependency.
// set: writes back through DataContext.set() — updates DataModel, PathSlot fires, view re-renders.

@MainActor
func a2uiStringBinding(
    for value: DynamicString?,
    dataContext: DataContext
) -> Binding<String> {
    let fallback: String = {
        if case .literal(let s) = value { return s }
        return ""
    }()
    return Binding<String>(
        get: {
            guard let value else { return fallback }
            return dataContext.resolve(value)
        },
        set: { newValue in
            guard case .dataBinding(let path) = value else { return }
            try? dataContext.set(path, value: .string(newValue))
        }
    )
}

@MainActor
func a2uiBoolBinding(
    for value: DynamicBoolean,
    dataContext: DataContext
) -> Binding<Bool> {
    return Binding<Bool>(
        get: { dataContext.resolve(value) },
        set: { newValue in
            guard case .dataBinding(let path) = value else { return }
            try? dataContext.set(path, value: .bool(newValue))
        }
    )
}

@MainActor
func a2uiDoubleBinding(
    for value: DynamicNumber,
    fallback: Double = 0,
    dataContext: DataContext
) -> Binding<Double> {
    let effectiveFallback: Double = {
        if case .literal(let n) = value { return n }
        return fallback
    }()
    return Binding<Double>(
        get: { dataContext.resolve(value) ?? effectiveFallback },
        set: { newValue in
            guard case .dataBinding(let path) = value else { return }
            try? dataContext.set(path, value: .number(newValue))
        }
    )
}

private nonisolated(unsafe) let _iso8601Formatter: ISO8601DateFormatter = ISO8601DateFormatter()

@MainActor
func a2uiDateBinding(
    for value: DynamicString,
    dataContext: DataContext
) -> Binding<Date> {
    let formatter = _iso8601Formatter
    return Binding<Date>(
        get: {
            let str = dataContext.resolve(value)
            return formatter.date(from: str) ?? Date()
        },
        set: { newValue in
            guard case .dataBinding(let path) = value else { return }
            try? dataContext.set(path, value: .string(formatter.string(from: newValue)))
        }
    )
}

// MARK: - Layout Helpers

@MainActor
@ViewBuilder
func a2uiDistributedContent(
    _ children: [ComponentNode],
    justify: Justify?,
    stretchWidth: Bool,
    stretchHeight: Bool,
    surface: SurfaceModel
) -> some View {
    switch justify {
    case .spaceBetween:
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, surface: surface)
            if child.id != children.last?.id { Spacer(minLength: 0) }
        }
    case .spaceAround:
        ForEach(children) { child in
            Spacer(minLength: 0)
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, surface: surface)
            Spacer(minLength: 0)
        }
    case .spaceEvenly:
        Spacer(minLength: 0)
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, surface: surface)
            Spacer(minLength: 0)
        }
    case .center:
        Spacer(minLength: 0)
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, surface: surface)
        }
        Spacer(minLength: 0)
    case .end:
        Spacer(minLength: 0)
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, surface: surface)
        }
    case .stretch:
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: true, stretchHeight: true, surface: surface)
        }
    default:
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, surface: surface)
        }
    }
}

@MainActor
@ViewBuilder
func a2uiChildView(
    _ child: ComponentNode,
    stretchWidth: Bool,
    stretchHeight: Bool,
    surface: SurfaceModel
) -> some View {
    A2UIComponentView(node: child, surface: surface)
        .frame(
            maxWidth: stretchWidth ? .infinity : nil,
            maxHeight: stretchHeight ? .infinity : nil,
            alignment: stretchWidth ? .leading : .center
        )
}

// MARK: - Accessibility Modifier

extension View {
    /// Applies VoiceOver `accessibilityLabel` and `accessibilityHint` from A2UI
    /// `AccessibilityAttributes`, resolved against the given `DataContext`.
    ///
    /// - If `attrs` is `nil`, the view is returned unchanged.
    /// - `attrs.label`       → `.accessibilityLabel(Text(...))`
    /// - `attrs.description` → `.accessibilityHint(Text(...))`
    @ViewBuilder
    func a2uiAccessibility(
        _ attrs: A2UIAccessibility?,
        dataContext: DataContext
    ) -> some View {
        if let label = attrs?.label, let hint = attrs?.description {
            self
                .accessibilityLabel(Text(dataContext.resolve(label)))
                .accessibilityHint(Text(dataContext.resolve(hint)))
        } else if let label = attrs?.label {
            self.accessibilityLabel(Text(dataContext.resolve(label)))
        } else if let hint = attrs?.description {
            self.accessibilityHint(Text(dataContext.resolve(hint)))
        } else {
            self
        }
    }
}
