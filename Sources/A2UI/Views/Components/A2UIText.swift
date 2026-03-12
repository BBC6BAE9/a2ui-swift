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

/// # Text
/// Maps `usageHint` (h1–h5, caption, body) to semantic `Font` and `AccessibilityHeadingLevel`.
/// Supports inline Markdown via `AttributedString(markdown:)`. Styles are overridable through
/// `A2UIStyle.textStyles` (font, weight, color per hint). Caption defaults to `.secondary` color.
struct A2UIText: View {
    let node: ComponentNode
    var viewModel: SurfaceViewModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.payload.typedProperties(TextProperties.self) {
            let resolved = viewModel.resolveString(
                props.text, dataContextPath: dataContextPath
            )
            let hint = props.usageHint
            let override = style.textStyles[hint ?? "body"]

            styledText(resolved, hint: hint, override: override)
        }
    }

    private func styledText(
        _ resolved: String,
        hint: String?,
        override: A2UIStyle.TextStyle?
    ) -> some View {
        let weight = override?.weight
        let color = override?.color ?? defaultColor(for: hint)
        let level = accessibilityHeadingLevel(for: hint)

        return Text(markdownAttributedString(resolved))
            .font(override?.font ?? defaultFont(for: hint))
            .fontWeight(weight)
            .foregroundColor(color)
            .accessibilityAddTraits(level != nil ? .isHeader : [])
            .accessibilityHeading(level ?? .unspecified)
    }

    /// Default semantic font for the given usageHint.
    private func defaultFont(for hint: String?) -> Font {
        switch hint {
        case "h1": return .largeTitle
        case "h2": return .title
        case "h3": return .title2
        case "h4": return .title3
        case "h5": return .headline
        case "caption": return .caption
        default: return .body
        }
    }

    /// Default foreground color for the given usageHint (nil = inherit).
    private func defaultColor(for hint: String?) -> Color? {
        hint == "caption" ? .secondary : nil
    }

    /// Maps heading hints to VoiceOver heading levels.
    private func accessibilityHeadingLevel(
        for hint: String?
    ) -> AccessibilityHeadingLevel? {
        switch hint {
        case "h1": return .h1
        case "h2": return .h2
        case "h3": return .h3
        case "h4": return .h4
        case "h5": return .h5
        default: return nil
        }
    }

    private func markdownAttributedString(_ string: String) -> AttributedString {
        (try? AttributedString(markdown: string, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(string)
    }
}

// MARK: - Previews

#Preview("Text - Body") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hello, World!"}}}}]}}
    """) {
        A2UIText(node: root, viewModel: vm).padding()
    }
}

#Preview("Text - Headings") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["h1","h2","h3","h4","h5"]}}}},{"id":"h1","component":{"Text":{"text":{"literalString":"Heading 1"},"usageHint":"h1"}}},{"id":"h2","component":{"Text":{"text":{"literalString":"Heading 2"},"usageHint":"h2"}}},{"id":"h3","component":{"Text":{"text":{"literalString":"Heading 3"},"usageHint":"h3"}}},{"id":"h4","component":{"Text":{"text":{"literalString":"Heading 4"},"usageHint":"h4"}}},{"id":"h5","component":{"Text":{"text":{"literalString":"Heading 5"},"usageHint":"h5"}}}]}}
    """) {
        A2UIComponentView(node: root, viewModel: vm).padding()
    }
}

#Preview("Text - Caption") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Text":{"text":{"literalString":"This is a caption"},"usageHint":"caption"}}}]}}
    """) {
        A2UIText(node: root, viewModel: vm).padding()
    }
}

#Preview("Text - Markdown") {
    if let (vm, root) = previewViewModel(jsonl: """
    {"beginRendering":{"surfaceId":"s","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"s","components":[{"id":"root","component":{"Text":{"text":{"literalString":"**Bold**, *italic*, and [a link](https://example.com)"}}}}]}}
    """) {
        A2UIText(node: root, viewModel: vm).padding()
    }
}
