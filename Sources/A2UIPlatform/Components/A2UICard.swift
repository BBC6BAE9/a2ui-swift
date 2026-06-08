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

/// Spec v0.9 `Card` — a styled surface wrapping a single child.
/// The child is pre-resolved into `node.children[0]` by the tree builder.
/// Fully shared: background, corner radius, child hosting via shared helpers.
final class A2UICard: PlatformView, A2UIPlatformComponent {

    private var hosted: PlatformView?

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        // Default Card matches SwiftUI: page-colored background, no rounding —
        // visually just a padded container unless a style overrides it.
        a2ui_setBackground(A2UIPlatformStyle.cardBackground)

        hosted?.removeFromSuperview()
        guard let child = node.children.first else { hosted = nil; return }
        let view = factory.makeView(for: child, surface: surface)
        a2ui_pinEdges(of: view, inset: A2UIPlatformStyle.cardPadding)
        hosted = view
    }
}

#endif
