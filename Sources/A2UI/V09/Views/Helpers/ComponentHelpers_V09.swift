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

// MARK: - Binding Helpers (v0.9 DynamicValue types)

func a2uiStringBinding(
    for value: DynamicString_V09?,
    viewModel: SurfaceViewModel_V09,
    dataContextPath: String
) -> Binding<String> {
    let fallback: String = {
        if case .literal(let s) = value { return s }
        return ""
    }()
    return Binding<String>(
        get: {
            guard case .dataBinding(let path) = value else { return fallback }
            let full = viewModel.dataStore.resolvePath(path, context: dataContextPath)
            return viewModel.dataStore.getDataByPath(full)?.stringValue ?? fallback
        },
        set: { newValue in
            guard case .dataBinding(let path) = value else { return }
            viewModel.dataStore.setData(
                path: path,
                value: .string(newValue),
                dataContextPath: dataContextPath
            )
        }
    )
}

func a2uiBoolBinding(
    for value: DynamicBoolean_V09,
    viewModel: SurfaceViewModel_V09,
    dataContextPath: String
) -> Binding<Bool> {
    let fallback: Bool = {
        if case .literal(let b) = value { return b }
        return false
    }()
    return Binding<Bool>(
        get: {
            guard case .dataBinding(let path) = value else { return fallback }
            let full = viewModel.dataStore.resolvePath(path, context: dataContextPath)
            return viewModel.dataStore.getDataByPath(full)?.boolValue ?? fallback
        },
        set: { newValue in
            guard case .dataBinding(let path) = value else { return }
            viewModel.dataStore.setData(
                path: path,
                value: .bool(newValue),
                dataContextPath: dataContextPath
            )
        }
    )
}

func a2uiDoubleBinding(
    for value: DynamicNumber_V09,
    fallback: Double = 0,
    viewModel: SurfaceViewModel_V09,
    dataContextPath: String
) -> Binding<Double> {
    let effectiveFallback: Double = {
        if case .literal(let n) = value { return n }
        return fallback
    }()
    return Binding<Double>(
        get: {
            guard case .dataBinding(let path) = value else { return effectiveFallback }
            let full = viewModel.dataStore.resolvePath(path, context: dataContextPath)
            return viewModel.dataStore.getDataByPath(full)?.numberValue ?? effectiveFallback
        },
        set: { newValue in
            guard case .dataBinding(let path) = value else { return }
            viewModel.dataStore.setData(
                path: path,
                value: .number(newValue),
                dataContextPath: dataContextPath
            )
        }
    )
}

func a2uiDateBinding(
    for value: DynamicString_V09,
    viewModel: SurfaceViewModel_V09,
    dataContextPath: String
) -> Binding<Date> {
    let formatter = ISO8601DateFormatter()
    return Binding<Date>(
        get: {
            guard case .dataBinding(let path) = value else { return Date() }
            let full = viewModel.dataStore.resolvePath(path, context: dataContextPath)
            guard let str = viewModel.dataStore.getDataByPath(full)?.stringValue,
                  !str.isEmpty,
                  let date = formatter.date(from: str) else {
                return Date()
            }
            return date
        },
        set: { newValue in
            guard case .dataBinding(let path) = value else { return }
            viewModel.dataStore.setData(
                path: path,
                value: .string(formatter.string(from: newValue)),
                dataContextPath: dataContextPath
            )
        }
    )
}

// MARK: - Layout Helpers (v0.9)

@ViewBuilder
func a2uiDistributedContent(
    _ children: [ComponentNode_V09],
    justify: Justify_V09?,
    stretchWidth: Bool,
    stretchHeight: Bool,
    viewModel: SurfaceViewModel_V09
) -> some View {
    switch justify {
    case .spaceBetween:
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, viewModel: viewModel)
            if child.id != children.last?.id {
                Spacer(minLength: 0)
            }
        }
    case .spaceAround:
        ForEach(children) { child in
            Spacer(minLength: 0)
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, viewModel: viewModel)
            Spacer(minLength: 0)
        }
    case .spaceEvenly:
        Spacer(minLength: 0)
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, viewModel: viewModel)
            Spacer(minLength: 0)
        }
    case .center:
        Spacer(minLength: 0)
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, viewModel: viewModel)
        }
        Spacer(minLength: 0)
    case .end:
        Spacer(minLength: 0)
        ForEach(children) { child in
            a2uiChildView(child, stretchWidth: stretchWidth, stretchHeight: stretchHeight, viewModel: viewModel)
        }
    case .stretch:
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
    _ child: ComponentNode_V09,
    stretchWidth: Bool,
    stretchHeight: Bool,
    viewModel: SurfaceViewModel_V09
) -> some View {
    A2UIComponentView_V09(node: child, viewModel: viewModel)
        .frame(
            maxWidth: stretchWidth ? .infinity : nil,
            maxHeight: stretchHeight ? .infinity : nil,
            alignment: stretchWidth ? .leading : .center
        )
}
