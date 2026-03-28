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

struct A2UICustom: View {
    let node: ComponentNode
    let surface: SurfaceModel

    @Environment(\.a2uiCustomComponentRendererV09) private var customRenderer

    var body: some View {
        // Standard components observe property changes via typedProperties(),
        // which accesses `node.instance` and establishes @Observable tracking.
        // Custom components need the same observation — this is the SwiftUI
        // equivalent of React v0.9's GenericBinder subscribing to
        // componentModel.onUpdated via useSyncExternalStore.
        let _ = node.instance
        if case .custom(let typeName) = node.type {
            if let renderer = customRenderer,
               let customView = renderer(typeName, node, node.children, surface) {
                customView
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(node.children) { child in
                        A2UIComponentView(node: child, surface: surface)
                    }
                }
            }
        }
    }
}
