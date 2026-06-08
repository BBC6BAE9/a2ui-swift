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

#if (canImport(UIKit) && !os(watchOS)) || canImport(AppKit)
import A2UISwiftCore

// MARK: - Expression-aware observation
//
// SwiftUI gets expression reactivity for free: evaluating a function-call inside
// `body` reads every referenced PathSlot via @Observable, so SwiftUI re-renders
// when any of them changes. The imperative renderer must do this explicitly:
// collect the data paths an expression references (fan-in), subscribe to each,
// and re-resolve on any change. Built entirely on public Core APIs — Core is
// untouched.
//
// Covers all three Dynamic cases: `.literal` (seed once), `.dataBinding` (one
// path), `.functionCall` (every referenced path).

/// Observe a `DynamicString` reactively, including function-call expressions.
func a2ui_observeString(
    _ value: DynamicString,
    dataContext dc: DataContext,
    bag: inout DataSubscriptions,
    onChange: @escaping (String) -> Void
) {
    onChange(dc.resolve(value)) // seed
    switch value {
    case .literal:
        break
    case .dataBinding:
        dc.subscribeString(for: value) { onChange($0) }.store(in: &bag)
    case .functionCall(let fc):
        for path in a2ui_referencedPaths(of: fc, dataContext: dc) {
            dc.subscribeDynamicValue(.dataBinding(path: path)) { _ in
                onChange(dc.resolve(value))
            }.store(in: &bag)
        }
    }
}

// MARK: - Reference collection

/// All absolute data paths an expression depends on (recursively through nested
/// function-call arguments).
func a2ui_referencedPaths(of fc: FunctionCall, dataContext dc: DataContext) -> Set<String> {
    var paths = Set<String>()
    for (_, arg) in fc.args {
        a2ui_collectPaths(DynamicValue(from: arg), dataContext: dc, into: &paths)
    }
    return paths
}

private func a2ui_collectPaths(
    _ value: DynamicValue, dataContext dc: DataContext, into paths: inout Set<String>
) {
    switch value {
    case .dataBinding(let path):
        paths.insert(dc.resolvePath(path))
    case .functionCall(let fc):
        for (_, arg) in fc.args {
            a2ui_collectPaths(DynamicValue(from: arg), dataContext: dc, into: &paths)
        }
    default:
        break
    }
}

#endif
