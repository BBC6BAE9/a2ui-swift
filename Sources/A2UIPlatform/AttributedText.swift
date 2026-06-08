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
import Foundation

#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Cross-platform label colors

extension PlatformColor {
    static var a2uiLabel: PlatformColor {
        #if canImport(UIKit) && !os(watchOS)
        return .label
        #elseif canImport(AppKit)
        return .labelColor
        #endif
    }
    static var a2uiSecondaryLabel: PlatformColor {
        #if canImport(UIKit) && !os(watchOS)
        return .secondaryLabel
        #elseif canImport(AppKit)
        return .secondaryLabelColor
        #endif
    }
}

// MARK: - Auto-linked text

/// Builds an attributed string with the base font/color, then tints any
/// detected URLs, emails, and phone numbers — matching SwiftUI's markdown
/// auto-linking of bare links.
func a2ui_linkedText(_ string: String, font: PlatformFont, color: PlatformColor) -> NSAttributedString {
    let attributed = NSMutableAttributedString(
        string: string,
        attributes: [.font: font, .foregroundColor: color]
    )
    // Only URLs/emails are auto-linked (SwiftUI leaves phone numbers as plain text).
    guard !string.isEmpty,
          let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
        return attributed
    }
    let full = NSRange(string.startIndex..., in: string)
    detector.enumerateMatches(in: string, options: [], range: full) { match, _, _ in
        if let range = match?.range {
            attributed.addAttribute(.foregroundColor, value: A2UIPlatformStyle.tint, range: range)
        }
    }
    return attributed
}

#endif
