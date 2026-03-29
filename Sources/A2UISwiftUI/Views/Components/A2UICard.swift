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

/// Spec v0.9 Card -- pure visual container with a single `child`.
///
/// Spec requires only: `child` (component ID, required). No styling properties in the spec.
/// Card is NOT interactive -- hover/focus effects belong to the outer Button/NavigationLink.
///
/// ## Rendering strategy: system defaults, zero hardcoded values.
///
/// Default appearance uses **only SwiftUI system APIs** with no magic numbers:
/// - `.padding()` -- system-default inset per platform & size class.
/// - `.background(.background)` -- system background ShapeStyle, auto light/dark.
/// - `.clipShape(.rect(cornerRadius:style:))` -- continuous squircle when overridden.
/// - No shadow by default -- Apple system cards (Settings, grouped lists) rely on
///   background color contrast for layer separation, not drop shadows.
///
/// All styling is overridable via `.a2uiCardStyle(...)`. Only explicitly set
/// properties take effect; `nil` means "use system default".
struct A2UICard: View {
    let node: ComponentNode
    let surface: SurfaceModel

    @Environment(\.a2uiStyle) private var style

    var body: some View {
        if let child = node.children.first {
            let dc = DataContext(surface: surface, path: node.dataContextPath)
            let card = style.cardStyle

            A2UIComponentView(node: child, surface: surface)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modify { view in
                    if let p = card.padding {
                        view.padding(p)
                    } else {
                        view.padding()
                    }
                }
                .modify { view in
                    if let r = card.cornerRadius {
                        let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
                        if let bg = card.backgroundColor {
                            view.background(bg, in: shape).clipShape(shape)
                        } else {
                            view.background(.background, in: shape).clipShape(shape)
                        }
                    } else {
                        if let bg = card.backgroundColor {
                            view.background(bg)
                        } else {
                            view.background(.background)
                        }
                    }
                }
                .modify { view in
                    if let sr = card.shadowRadius {
                        view.shadow(
                            color: card.shadowColor ?? .black.opacity(0.1),
                            radius: sr,
                            y: card.shadowY ?? 1
                        )
                    } else {
                        view
                    }
                }
                .a2uiAccessibility(node.accessibility, dataContext: dc)
                .padding(style.leafMargin)
        }
    }
}

// MARK: - Conditional modifier helper

private extension View {
    /// Applies a transform and returns the result. Avoids `AnyView` type-erasure.
    @ViewBuilder
    func modify<V: View>(@ViewBuilder _ transform: (Self) -> V) -> some View {
        transform(self)
    }
}
