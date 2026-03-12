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

/// Renders an SVG path string as an icon whose size automatically matches the
/// current font environment — behaving like an SF Symbol with zero hardcoded
/// dimensions.
///
/// ## How it works
///
/// Uses a custom `Layout` that proposes zero size to a hidden `Text("W")` to
/// read its ideal (intrinsic) height, then uses that as the icon's side length.
/// The SVG path is drawn via `Canvas`, which unlike `Shape` does **not** expand
/// greedily — it respects the size proposed by the layout.
///
/// This automatically responds to:
/// - **Platform** (tvOS body ≈ 29pt, iOS ≈ 17pt, macOS ≈ 13pt)
/// - **Dynamic Type** / Accessibility sizes
/// - **`.font()` modifiers** on ancestor views
/// - **Bold Text** accessibility setting
///
/// No `@ScaledMetric`, no hardcoded values, no overlay hacks.
struct SVGIconView: View {
    let svgPath: String

    var body: some View {
        IconSizingLayout {
            // First child: hidden Text that provides the font metric.
            // The layout reads its ideal size but renders it at 0×0.
            Text("W")
                .hidden()
                .accessibilityHidden(true)

            // Second child: Canvas that draws the SVG path.
            // Canvas does NOT expand greedily — it uses exactly the size
            // proposed by the layout.
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let shape = SVGPathShape(svgPath: svgPath)
                let path = shape.path(in: rect)
                context.fill(path, with: .foreground)
            }
        }
    }
}

/// A custom `Layout` that sizes its second child (the icon) to a square whose
/// side equals the first child's (the Text's) ideal height.
///
/// - Subview 0: measurement probe (hidden Text) — not rendered visually.
/// - Subview 1: the actual icon content, proposed as a square.
private struct IconSizingLayout: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        // Ask the Text for its ideal size — this gives us the font's line height.
        let textSize = subviews[0].sizeThatFits(.unspecified)
        let side = textSize.height
        return CGSize(width: side, height: side)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }
        // Place the Text at zero size — it's just a measurement probe.
        subviews[0].place(
            at: bounds.origin,
            proposal: .init(width: 0, height: 0)
        )
        // Place the Canvas filling the full square bounds.
        subviews[1].place(
            at: bounds.origin,
            proposal: .init(width: bounds.width, height: bounds.height)
        )
    }
}
