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

/// Renders a `.custom(typeName)` node by delegating to the `AnyCustomComponentCatalog`
/// stored in the SwiftUI environment.
///
/// If the catalog returns `nil` (i.e. does not handle this typeName),
/// the default fallback renders the node's children in a VStack.
struct A2UICustom: View {
    let node: ComponentNode
    let surface: SurfaceModel

    @Environment(\.a2uiCatalog) private var catalog

    var body: some View {
        // Establish @Observable tracking on node.instance so SwiftUI re-renders
        // when the server pushes property updates — same as built-in components
        // that call node.typedProperties() inside body.
        let _ = node.instance
        if case .custom(let typeName) = node.type {
            if let built = catalog.build(typeName: typeName, node: node, surface: surface) {
                built
            } else {
                // Catalog does not handle this type — fall back to rendering children.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(node.children) { child in
                        A2UIComponentView(node: child, surface: surface)
                    }
                }
            }
        }
    }
}
