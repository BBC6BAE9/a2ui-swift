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

/// Constructs a `SurfaceViewModel` and its root `ComponentNode` from a JSONL
/// string (the same format used by the CatalogPage in the demo app).
///
/// Returns `nil` if parsing fails. Use in `#Preview` blocks:
///
/// ```swift
/// #Preview("Text - Headings") {
///     if let (vm, root) = previewViewModel(jsonl: "...") {
///         A2UIText(node: root, viewModel: vm)
///     }
/// }
/// ```
func previewViewModel(jsonl: String) -> (SurfaceViewModel, ComponentNode)? {
    let vm = SurfaceViewModel()
    let decoder = JSONDecoder()
    for line in jsonl.components(separatedBy: "\n")
    where !line.trimmingCharacters(in: .whitespaces).isEmpty {
        guard let data = line.data(using: .utf8),
              let msg = try? decoder.decode(ServerToClientMessage.self, from: data) else {
            return nil
        }
        try? vm.processMessage(msg)
    }
    guard let root = vm.componentTree else { return nil }
    return (vm, root)
}
