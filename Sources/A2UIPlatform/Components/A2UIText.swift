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

/// Spec v0.9 `Text` — a single styled, data-bound text leaf.
///
/// All shared: the data binding, the subscription lifecycle, the layout. The
/// ONLY platform-specific code is the label control itself (`UILabel` vs the
/// label-configured `NSTextField`) — see the `setText` / `makeLabel` shells.
final class A2UIText: PlatformView, A2UIPlatformComponent {

    private var subscriptions = DataSubscriptions()

    #if canImport(UIKit) && !os(watchOS)
    private let label = UILabel()
    #elseif canImport(AppKit)
    private let label = NSTextField(labelWithString: "")
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLabelControl()
        a2ui_pinEdges(of: label)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLabelControl()
        a2ui_pinEdges(of: label)
    }

    // MARK: A2UIPlatformComponent

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        subscriptions.unsubscribeAll()
        guard let props = try? node.typedProperties(TextProperties.self) else { return }
        let ctx = DataContext(surface: surface, path: node.dataContextPath)

        // `subscribe*` only delivers *changes*, so seed the initial value first
        // (mirrors what SwiftUI gets implicitly from `resolve()` in its body).
        applyVariant(props.variant)
        // Expression-aware: literals, data bindings, AND function-call expressions
        // all update reactively (fan-in over referenced paths).
        a2ui_observeString(props.text, dataContext: ctx, bag: &subscriptions) { [weak self] resolved in
            self?.setText(resolved)
        }
        a2ui_applyAccessibility(node.accessibility, dataContext: ctx)
    }

    deinit { subscriptions.unsubscribeAll() }

    private func applyVariant(_ variant: TextVariant?) {
        label.font = A2UIPlatformStyle.font(for: variant)
        let secondary = (variant == .caption)
        #if canImport(UIKit) && !os(watchOS)
        label.textColor = secondary ? .secondaryLabel : .label
        if let heading = headingTraitLevel(variant) {
            label.accessibilityTraits.insert(.header)
            _ = heading
        }
        #elseif canImport(AppKit)
        label.textColor = secondary ? .secondaryLabelColor : .labelColor
        #endif
    }

    private func headingTraitLevel(_ variant: TextVariant?) -> Int? {
        switch variant {
        case .h1: return 1
        case .h2: return 2
        case .h3: return 3
        case .h4: return 4
        case .h5: return 5
        default: return nil
        }
    }

    // MARK: - Platform shell (the only divergent part)

    private func configureLabelControl() {
        #if canImport(UIKit) && !os(watchOS)
        label.numberOfLines = 0
        #elseif canImport(AppKit)
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.cell?.wraps = true
        #endif
    }

    private func setText(_ value: String) {
        #if canImport(UIKit) && !os(watchOS)
        label.text = value
        #elseif canImport(AppKit)
        label.stringValue = value
        #endif
    }

    /// The currently displayed text. Exposed for tests / introspection.
    var currentText: String {
        #if canImport(UIKit) && !os(watchOS)
        return label.text ?? ""
        #elseif canImport(AppKit)
        return label.stringValue
        #endif
    }
}

#endif
