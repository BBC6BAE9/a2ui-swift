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

/// Applies `flex-grow` equivalent: when a component has `weight`, it expands
/// to fill available space proportionally within an HStack/VStack.
struct WeightModifier: ViewModifier {
    let weight: Double?

    func body(content: Content) -> some View {
        if let w = weight, w > 0 {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(w)
        } else {
            content
        }
    }
}
