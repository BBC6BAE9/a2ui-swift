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

/// Applies accessibility attributes from the A2UI spec to SwiftUI views.
struct AccessibilityModifier: ViewModifier {
    let accessibility: A2UIAccessibility?
    var viewModel: SurfaceViewModel
    var dataContextPath: String

    func body(content: Content) -> some View {
        if let a11y = accessibility {
            let label = a11y.label.map { viewModel.resolveString($0, dataContextPath: dataContextPath) }
            let hint = a11y.description.map { viewModel.resolveString($0, dataContextPath: dataContextPath) }
            content
                .accessibilityLabel(label ?? "")
                .accessibilityHint(hint ?? "")
        } else {
            content
        }
    }
}
