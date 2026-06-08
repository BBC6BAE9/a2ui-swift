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

#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Accessibility
//
// Maps `A2UIAccessibility` (label / description) onto native accessibility.
// Mirrors SwiftUI's `a2uiAccessibility` modifier.

extension PlatformView {

    func a2ui_applyAccessibility(_ attrs: A2UIAccessibility?, dataContext dc: DataContext) {
        guard let attrs else { return }
        let label = attrs.label.map { dc.resolve($0) }
        let hint = attrs.description.map { dc.resolve($0) }

        #if canImport(UIKit) && !os(watchOS)
        if let label, !label.isEmpty { isAccessibilityElement = true; accessibilityLabel = label }
        if let hint, !hint.isEmpty { accessibilityHint = hint }
        #elseif canImport(AppKit)
        if let label, !label.isEmpty { setAccessibilityLabel(label) }
        if let hint, !hint.isEmpty { setAccessibilityHelp(hint) }
        #endif
    }
}

#endif
