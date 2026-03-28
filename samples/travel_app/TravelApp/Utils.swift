// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI

/// Renders markdown text using iOS native `AttributedString`.
///
/// Mirrors Flutter's `MarkdownWidget` from `utils.dart`, which uses the
/// `gpt_markdown` package. In Swift, we use Foundation's built-in markdown
/// parsing via `AttributedString(markdown:)`.
struct MarkdownWidget: View {
    let text: String

    var body: some View {
        Text(markdownAttributed(text))
            .font(.body)
            .tint(.blue)
            .textSelection(.enabled)
    }
}
