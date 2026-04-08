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

/// Renders a resolved child `ComponentNode` inside a custom SwiftUI component.
///
/// Use this from a `CustomComponentCatalog` implementation when you need to
/// render one of the child nodes already attached to the current component,
/// mirroring Flutter's `itemContext.buildChild(...)` pattern.
public struct A2UIChildView: View {
    public let node: ComponentNode
    public let surface: SurfaceModel

    public init(node: ComponentNode, surface: SurfaceModel) {
        self.node = node
        self.surface = surface
    }

    public var body: some View {
        A2UIComponentView(node: node, surface: surface)
    }
}
