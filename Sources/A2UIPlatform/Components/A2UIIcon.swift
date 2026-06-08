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
        setupIconView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupIconView()
    }

    private func setupIconView() {
        a2ui_pinEdges(of: imageView)
        // SwiftUI renders icons in the primary (label) color, not the accent tint.
        #if canImport(UIKit) && !os(watchOS)
        imageView.tintColor = .label
        imageView.contentMode = .scaleAspectFit
        #elseif canImport(AppKit)
        imageView.contentTintColor = .labelColor
        imageView.imageScaling = .scaleProportionallyUpOrDown
        #endif
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
        case .customPath(let d):
            setSVGPath(d)
        }
    }

    deinit { subscriptions.unsubscribeAll() }

    // MARK: - Custom SVG path

    private var svgPath: CGPath?
    private let shapeLayer = CAShapeLayer()

    private func setSVGPath(_ d: String) {
        imageView.image = nil
        svgPath = a2ui_parseSVGPath(d)
        #if canImport(UIKit) && !os(watchOS)
        shapeLayer.fillColor = PlatformColor.label.cgColor
        if shapeLayer.superlayer == nil { layer.addSublayer(shapeLayer) }
        setNeedsLayout()
        #elseif canImport(AppKit)
        wantsLayer = true
        shapeLayer.fillColor = PlatformColor.labelColor.cgColor
        if shapeLayer.superlayer == nil { layer?.addSublayer(shapeLayer) }
        needsLayout = true
        #endif
        layoutShape()
    }

    /// Aspect-fits the parsed path into the view's bounds.
    private func layoutShape() {
        guard let svgPath else { return }
        let box = svgPath.boundingBoxOfPath
        guard box.width > 0, box.height > 0, bounds.width > 0, bounds.height > 0 else {
            shapeLayer.path = svgPath; return
        }
        let scale = min(bounds.width / box.width, bounds.height / box.height)
        let tx = (bounds.width - box.width * scale) / 2 - box.minX * scale
        let ty = (bounds.height - box.height * scale) / 2 - box.minY * scale
        var transform = CGAffineTransform(translationX: tx, y: ty).scaledBy(x: scale, y: scale)
        shapeLayer.frame = bounds
        shapeLayer.path = svgPath.copy(using: &transform)
    }

    #if canImport(UIKit) && !os(watchOS)
    override func layoutSubviews() { super.layoutSubviews(); layoutShape() }
    #elseif canImport(AppKit)
    override func layout() { super.layout(); layoutShape() }
    // NSView is bottom-left origin; flip so SVG paths render right-side up.
    override var isFlipped: Bool { true }
    #endif

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
