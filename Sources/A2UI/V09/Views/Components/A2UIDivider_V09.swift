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

/// # Divider
/// Directly maps to `SwiftUI.Divider()`. The spec's `axis` property is intentionally ignored --
/// SwiftUI's Divider auto-adapts orientation based on parent container (horizontal in VStack,
/// vertical in HStack), making manual axis handling unnecessary.
struct A2UIDivider_V09: View {
    let node: ComponentNode_V09

    var body: some View {
        // Intentionally ignored: spec defines `axis` ("horizontal"/"vertical"), but SwiftUI's
        // Divider auto-adapts orientation based on parent (horizontal in VStack, vertical in HStack).
        // swiftlint:disable:next unused_optional_binding
        let _ = (try? node.typedProperties(DividerProperties_V09.self))?.axis
        SwiftUI.Divider()
    }
}
