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

// MARK: - Alignment Helpers

func a2uiHorizontalAlignment(_ align: String?) -> HorizontalAlignment {
    switch align {
    case "start": return .leading
    case "center": return .center
    case "end": return .trailing
    default: return .leading
    }
}

func a2uiVerticalAlignment(_ align: String?) -> VerticalAlignment {
    switch align {
    case "start": return .top
    case "center": return .center
    case "end": return .bottom
    default: return .top
    }
}

// MARK: - Binding Helpers

func a2uiStringBinding(
    for value: StringValue?,
    viewModel: SurfaceViewModel,
    dataContextPath: String
) -> Binding<String> {
    let fallback = value?.literalValue ?? ""
    return Binding<String>(
        get: {
            guard let path = value?.path else { return fallback }
            let full = viewModel.resolvePath(path, context: dataContextPath)
            return viewModel.getDataByPath(full)?.stringValue ?? fallback
        },
        set: { newValue in
            guard let path = value?.path else { return }
            viewModel.setData(
                path: path,
                value: .string(newValue),
                dataContextPath: dataContextPath
            )
        }
    )
}

func a2uiBoolBinding(
    for value: BooleanValue,
    viewModel: SurfaceViewModel,
    dataContextPath: String
) -> Binding<Bool> {
    let fallback = value.literalValue ?? false
    return Binding<Bool>(
        get: {
            guard let path = value.path else { return fallback }
            let full = viewModel.resolvePath(path, context: dataContextPath)
            return viewModel.getDataByPath(full)?.boolValue ?? fallback
        },
        set: { newValue in
            guard let path = value.path else { return }
            viewModel.setData(
                path: path,
                value: .bool(newValue),
                dataContextPath: dataContextPath
            )
        }
    )
}

func a2uiDoubleBinding(
    for value: NumberValue,
    fallback: Double = 0,
    viewModel: SurfaceViewModel,
    dataContextPath: String
) -> Binding<Double> {
    let effectiveFallback = value.literalValue ?? fallback
    return Binding<Double>(
        get: {
            guard let path = value.path else { return effectiveFallback }
            let full = viewModel.resolvePath(path, context: dataContextPath)
            return viewModel.getDataByPath(full)?.numberValue ?? effectiveFallback
        },
        set: { newValue in
            guard let path = value.path else { return }
            viewModel.setData(
                path: path,
                value: .number(newValue),
                dataContextPath: dataContextPath
            )
        }
    )
}

func a2uiDateBinding(
    for value: StringValue,
    viewModel: SurfaceViewModel,
    dataContextPath: String
) -> Binding<Date> {
    let formatter = ISO8601DateFormatter()
    return Binding<Date>(
        get: {
            guard let path = value.path else { return Date() }
            let full = viewModel.resolvePath(path, context: dataContextPath)
            guard let str = viewModel.getDataByPath(full)?.stringValue,
                  !str.isEmpty,
                  let date = formatter.date(from: str) else {
                return Date()
            }
            return date
        },
        set: { newValue in
            guard let path = value.path else { return }
            viewModel.setData(
                path: path,
                value: .string(formatter.string(from: newValue)),
                dataContextPath: dataContextPath
            )
        }
    )
}

// MARK: - Layout Helpers

/// Lay out children according to a justify mode (maps to CSS justify-content).
/// `stretchWidth`/`stretchHeight` apply cross-axis stretch per CSS `align-items: stretch`.
@ViewBuilder
func a2uiDistributedContent(
    _ children: [ComponentNode],
    justify: String?,
    stretchWidth: Bool,
    stretchHeight: Bool,
    viewModel: SurfaceViewModel
) -> some View {
    switch justify {
    case "spaceBetween":
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, viewModel: viewModel)
            if child.id != children.last?.id {
                Spacer(minLength: 0)
            }
        }
    case "spaceAround":
        ForEach(children) { child in
            Spacer(minLength: 0)
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, viewModel: viewModel)
            Spacer(minLength: 0)
        }
    case "spaceEvenly":
        Spacer(minLength: 0)
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, viewModel: viewModel)
            Spacer(minLength: 0)
        }
    case "center":
        Spacer(minLength: 0)
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, viewModel: viewModel)
        }
        Spacer(minLength: 0)
    case "end":
        Spacer(minLength: 0)
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, viewModel: viewModel)
        }
    case "stretch":
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: true, stretchHeight: true, viewModel: viewModel)
        }
    default:
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, viewModel: viewModel)
        }
    }
}

@ViewBuilder
func a2uiChildView(
    _ child: ComponentNode,
    stretchWidth: Bool,
    stretchHeight: Bool,
    viewModel: SurfaceViewModel
) -> some View {
    A2UIComponentView(node: child, viewModel: viewModel)
        .frame(
            maxWidth: stretchWidth ? .infinity : nil,
            maxHeight: stretchHeight ? .infinity : nil,
            alignment: stretchWidth ? .leading : .center
        )
}
