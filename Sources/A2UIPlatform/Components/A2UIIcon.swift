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

/// Spec v0.9 `Icon`. `name` is either a symbol name (rendered as an SF Symbol)
/// or a custom SVG path.
///
/// Baseline: SF Symbol names are fully supported. Custom SVG paths
/// (`IconNameValue.customPath`) are NOT yet rendered — that needs the SVG-path →
/// `CAShapeLayer` port (SwiftUI keeps this in SVGPathShape). Tracked as deferred.
final class A2UIIcon: PlatformView, A2UIPlatformComponent {

    private let imageView = PlatformImageView()
    private var subscriptions = DataSubscriptions()

    override init(frame: CGRect) {
        super.init(frame: frame)
        a2ui_pinEdges(of: imageView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        a2ui_pinEdges(of: imageView)
    }

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        subscriptions.unsubscribeAll()
        guard let props = try? node.typedProperties(IconProperties.self) else { return }
        let ctx = DataContext(surface: surface, path: node.dataContextPath)

        switch props.name {
        case .standard(let dynamicName):
            setSymbol(ctx.resolve(dynamicName))
            ctx.subscribeString(for: dynamicName) { [weak self] in self?.setSymbol($0) }
                .store(in: &subscriptions)
        case .customPath:
            // Deferred: render the SVG path via CAShapeLayer.
            break
        }
    }

    deinit { subscriptions.unsubscribeAll() }

    private func setSymbol(_ name: String) {
        guard !name.isEmpty else { imageView.image = nil; return }
        let symbol = a2ui_sfSymbolName(for: name)
        #if canImport(UIKit) && !os(watchOS)
        imageView.image = UIImage(systemName: symbol) ?? UIImage(systemName: "questionmark.diamond")
        #elseif canImport(AppKit)
        imageView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "questionmark.diamond", accessibilityDescription: nil)
        #endif
    }
}

#endif
