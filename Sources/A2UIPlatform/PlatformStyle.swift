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

    public static var tint: PlatformColor {
        #if canImport(UIKit) && !os(watchOS)
        return .tintColor
        #elseif canImport(AppKit)
        return .controlAccentColor
        #endif
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

    public static var cardBackground: PlatformColor {
        #if canImport(UIKit) && !os(watchOS)
        return .secondarySystemBackground
        #elseif canImport(AppKit)
        return .controlBackgroundColor
        #endif
    }

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
