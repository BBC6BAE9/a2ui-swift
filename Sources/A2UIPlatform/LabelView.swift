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

#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A lightweight, non-data-bound text label used for component chrome:
/// input field labels, validation errors, and skeleton placeholders.
/// Wraps the per-platform label control behind a single `text` accessor.
final class A2UILabelView: PlatformView {

    #if canImport(UIKit) && !os(watchOS)
    private let label = UILabel()
    #elseif canImport(AppKit)
    private let label = NSTextField(labelWithString: "")
    #endif

    init(font: PlatformFont, color: PlatformColor) {
        super.init(frame: .zero)
        #if canImport(UIKit) && !os(watchOS)
        label.numberOfLines = 0
        label.font = font
        label.textColor = color
        #elseif canImport(AppKit)
        label.maximumNumberOfLines = 0
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byWordWrapping
        label.cell?.wraps = true
        #endif
        a2ui_pinEdges(of: label)
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    var text: String {
        get {
            #if canImport(UIKit) && !os(watchOS)
            return label.text ?? ""
            #elseif canImport(AppKit)
            return label.stringValue
            #endif
        }
        set {
            #if canImport(UIKit) && !os(watchOS)
            label.text = newValue
            #elseif canImport(AppKit)
            label.stringValue = newValue
            #endif
        }
    }

    /// Convenience: a red caption label for validation errors.
    static func makeError() -> A2UILabelView {
        #if canImport(UIKit) && !os(watchOS)
        return A2UILabelView(font: .preferredFont(forTextStyle: .caption1), color: .systemRed)
        #elseif canImport(AppKit)
        return A2UILabelView(font: .preferredFont(forTextStyle: .caption1), color: .systemRed)
        #endif
    }

    /// Convenience: a monospaced-digit secondary value label (e.g. Slider value).
    static func makeValue() -> A2UILabelView {
        let size: CGFloat
        #if canImport(UIKit) && !os(watchOS)
        size = UIFont.preferredFont(forTextStyle: .body).pointSize
        return A2UILabelView(font: .monospacedDigitSystemFont(ofSize: size, weight: .regular),
                             color: .secondaryLabel)
        #elseif canImport(AppKit)
        size = NSFont.preferredFont(forTextStyle: .body).pointSize
        return A2UILabelView(font: .monospacedDigitSystemFont(ofSize: size, weight: .regular),
                             color: .secondaryLabelColor)
        #endif
    }

    /// Convenience: a secondary caption label for field titles.
    static func makeFieldLabel() -> A2UILabelView {
        #if canImport(UIKit) && !os(watchOS)
        return A2UILabelView(font: .preferredFont(forTextStyle: .subheadline), color: .secondaryLabel)
        #elseif canImport(AppKit)
        return A2UILabelView(font: .preferredFont(forTextStyle: .subheadline), color: .secondaryLabelColor)
        #endif
    }
}

#endif
