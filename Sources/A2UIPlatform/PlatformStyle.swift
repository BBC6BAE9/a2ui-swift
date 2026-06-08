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

// MARK: - A2UIPlatformStyle
//
// Minimal styling tokens mapped to native `Platform*` types. The SwiftUI
// `A2UIStyle` uses SwiftUI Color/Font (can't cross frameworks); these are the
// imperative-renderer equivalents. Values are defaults for now; wiring them to
// the surface theme is a later refinement.

public enum A2UIPlatformStyle {

    public static var leafMargin: CGFloat = 8
    public static var cornerRadius: CGFloat = 8
    public static var dividerThickness: CGFloat = 1

    /// Theme override for the accent color, parsed from `surface.theme`
    /// (`primaryColor` hex) by the host. Falls back to the system tint.
    public static var tintOverride: PlatformColor?

    public static var tint: PlatformColor {
        if let tintOverride { return tintOverride }
        #if canImport(UIKit) && !os(watchOS)
        return .tintColor
        #elseif canImport(AppKit)
        return .controlAccentColor
        #endif
    }

    /// Applies a surface theme dictionary (e.g. `{"primaryColor": "#FF0000"}`).
    public static func applyTheme(_ theme: [String: String]?) {
        if let hex = theme?["primaryColor"], let color = PlatformColor(a2uiHex: hex) {
            tintOverride = color
        } else {
            tintOverride = nil
        }
    }

    public static var separator: PlatformColor {
        #if canImport(UIKit) && !os(watchOS)
        return .separator
        #elseif canImport(AppKit)
        return .separatorColor
        #endif
    }

    public static var skeleton: PlatformColor {
        #if canImport(UIKit) && !os(watchOS)
        return .systemGray5
        #elseif canImport(AppKit)
        return .quaternaryLabelColor
        #endif
    }

    /// SwiftUI's Card default background is `.background` (the page background),
    /// so a default Card is visually invisible — just padding. Match that.
    public static var cardBackground: PlatformColor {
        #if canImport(UIKit) && !os(watchOS)
        return .systemBackground
        #elseif canImport(AppKit)
        return .windowBackgroundColor
        #endif
    }

    public static var cardPadding: CGFloat = 16

    /// Maps a Text variant to a native preferred font (h1–h5 / body / caption),
    /// mirroring SwiftUI's `.largeTitle`/`.title`/… mapping.
    public static func font(for variant: TextVariant?) -> PlatformFont {
        #if canImport(UIKit) && !os(watchOS)
        let style: UIFont.TextStyle
        switch variant {
        case .h1: style = .largeTitle
        case .h2: style = .title1
        case .h3: style = .title2
        case .h4: style = .title3
        case .h5: style = .headline
        case .caption: style = .caption1
        default: style = .body
        }
        return UIFont.preferredFont(forTextStyle: style)
        #elseif canImport(AppKit)
        let style: NSFont.TextStyle
        switch variant {
        case .h1: style = .largeTitle
        case .h2: style = .title1
        case .h3: style = .title2
        case .h4: style = .title3
        case .h5: style = .headline
        case .caption: style = .caption1
        default: style = .body
        }
        return NSFont.preferredFont(forTextStyle: style)
        #endif
    }
}

#endif
