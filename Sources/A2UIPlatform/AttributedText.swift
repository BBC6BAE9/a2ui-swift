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

/// Renders text the way SwiftUI's A2UIText does: parse inline Markdown
/// (**bold** / *italic* / [links]) onto the variant's base font/color, then tint
/// any bare URLs/emails. Phone numbers stay plain.
func a2ui_linkedText(_ string: String, font: PlatformFont, color: PlatformColor) -> NSAttributedString {
    // 1. Parse inline Markdown (falls back to plain text on failure).
    let attributed: NSMutableAttributedString
    if let parsed = try? NSAttributedString(
        markdown: string,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
        attributed = NSMutableAttributedString(attributedString: parsed)
    } else {
        attributed = NSMutableAttributedString(string: string)
    }

    let full = NSRange(location: 0, length: attributed.length)
    // 2. Re-base every run onto the variant font (preserving bold/italic traits)
    //    and color, since Markdown parsing uses the system default font.
    // (runs without a font attribute report value == nil and get the base font)
    attributed.enumerateAttribute(.font, in: full) { value, range, _ in
        let runFont = value as? PlatformFont
        attributed.addAttribute(.font, value: a2ui_mergeTraits(of: runFont, onto: font), range: range)
    }
    attributed.addAttribute(.foregroundColor, value: color, range: full)

    // 3. Tint bare URLs/emails.
    let plain = attributed.string
    if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
        let r = NSRange(plain.startIndex..., in: plain)
        detector.enumerateMatches(in: plain, options: [], range: r) { match, _, _ in
            if let range = match?.range {
                attributed.addAttribute(.foregroundColor, value: A2UIPlatformStyle.tint, range: range)
            }
        }
    }
    return attributed
}

/// Applies a run's bold/italic symbolic traits onto the base font at its size.
private func a2ui_mergeTraits(of runFont: PlatformFont?, onto base: PlatformFont) -> PlatformFont {
    guard let runFont else { return base }
    #if canImport(UIKit) && !os(watchOS)
    let traits = runFont.fontDescriptor.symbolicTraits.intersection([.traitBold, .traitItalic])
    guard !traits.isEmpty,
          let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else { return base }
    return UIFont(descriptor: descriptor, size: base.pointSize)
    #elseif canImport(AppKit)
    let traits = runFont.fontDescriptor.symbolicTraits.intersection([.bold, .italic])
    guard !traits.isEmpty else { return base }
    let descriptor = base.fontDescriptor.withSymbolicTraits(traits)
    return NSFont(descriptor: descriptor, size: base.pointSize) ?? base
    #endif
}

#endif
