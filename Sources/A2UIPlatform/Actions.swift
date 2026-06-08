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

// MARK: - Action dispatch
//
// Framework-agnostic — shared verbatim by every interactive component.
// Mirrors SwiftUI A2UIButton.handleAction: resolve event context one level deep
// then dispatch to the surface; function-call actions execute client-side.

func a2ui_dispatch(
    _ action: Action,
    from componentId: String,
    dataContext dc: DataContext,
    surface: SurfaceModel
) {
    switch action {
    case .event(let name, let ctx):
        var resolved: [String: AnyCodable] = [:]
        if let ctx {
            for (key, dv) in ctx {
                resolved[key] = dc.resolveDynamicValue(dv) ?? .null
            }
        }
        surface.dispatchAction(name: name, sourceComponentId: componentId, context: resolved)
    case .functionCall(let fc):
        _ = dc.resolveDynamicValue(.functionCall(fc))
    }
}

#endif
