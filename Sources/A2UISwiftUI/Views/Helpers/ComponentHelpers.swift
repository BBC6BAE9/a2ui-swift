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
// Free-function wrappers that delegate to DataContext extension methods
// defined in DataContext+SwiftUI.swift.
//
// These exist to maintain backward-compatible call sites in components
// that use the older `a2uiXxxBinding(for:dataContext:)` style.
// New code should prefer calling `dataContext.stringBinding(for:)` directly.

@MainActor
func a2uiStringBinding(
    for value: DynamicString?,
    dataContext: DataContext
) -> Binding<String> {
    dataContext.stringBinding(for: value)
}

@MainActor
func a2uiBoolBinding(
    for value: DynamicBoolean,
    dataContext: DataContext
) -> Binding<Bool> {
    dataContext.boolBinding(for: value)
}

@MainActor
func a2uiDoubleBinding(
    for value: DynamicNumber,
    fallback: Double = 0,
    dataContext: DataContext
) -> Binding<Double> {
    dataContext.doubleBinding(for: value, fallback: fallback)
}

@MainActor
func a2uiDateBinding(
    for value: DynamicString,
    dataContext: DataContext
) -> Binding<Date> {
    dataContext.dateBinding(for: value)
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
