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

// MARK: - Layout Axis Environment Key

/// The main axis of the nearest enclosing layout container (Row or Column).
/// `WeightModifier` reads this to expand only along the main axis, matching
/// CSS flex-grow semantics: a weighted child in a Row grows horizontally;
/// in a Column it grows vertically.
enum A2UILayoutAxis {
    case horizontal  // Row / HStack main axis
    case vertical    // Column / VStack main axis
}

private struct A2UILayoutAxisKey: EnvironmentKey {
    static let defaultValue: A2UILayoutAxis = .vertical
}

extension EnvironmentValues {
    var a2uiLayoutAxis: A2UILayoutAxis {
        get { self[A2UILayoutAxisKey.self] }
        set { self[A2UILayoutAxisKey.self] = newValue }
    }
}

// MARK: - WeightModifier

/// Applies `flex-grow` equivalent: when a component has `weight`, it expands
/// to fill available space proportionally within an HStack/VStack.
/// Expands only along the parent's main axis (horizontal for Row, vertical for Column).
struct WeightModifier: ViewModifier {
    let weight: Double?

    @Environment(\.a2uiLayoutAxis) private var layoutAxis

    init(weight: Double?) {
        self.weight = weight
    }

    func body(content: Content) -> some View {
        if let w = weight, w > 0 {
            switch layoutAxis {
            case .horizontal:
                content
                    .frame(maxWidth: .infinity)
                    .layoutPriority(w)
            case .vertical:
                content
                    .frame(maxHeight: .infinity)
                    .layoutPriority(w)
            }
        } else {
            content
        }
    }
}
