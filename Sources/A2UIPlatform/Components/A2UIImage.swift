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
import A2UISwiftCore

#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Spec v0.9 `Image` — loads a remote image and scales it per `fit`.
/// Shared: URL binding/subscription + async load. Per-platform: the content-mode
/// API (`contentMode` vs `imageScaling`) and `image` assignment.
final class A2UIImage: PlatformView, A2UIPlatformComponent {

    private let imageView = PlatformImageView()
    private var subscriptions = DataSubscriptions()
    private var loadTask: URLSessionDataTask?

    override init(frame: CGRect) {
        super.init(frame: frame)
        a2ui_pinEdges(of: imageView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        a2ui_pinEdges(of: imageView)
    }

    private var sizeConstraints: [NSLayoutConstraint] = []

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        subscriptions.unsubscribeAll()
        guard let props = try? node.typedProperties(ImageProperties.self) else { return }
        applyFit(props.fit ?? .contain)
        applyVariant(props.variant)
        let ctx = DataContext(surface: surface, path: node.dataContextPath)
        a2ui_applyAccessibility(node.accessibility, dataContext: ctx)

        load(ctx.resolve(props.url))
        ctx.subscribeString(for: props.url) { [weak self] in self?.load($0) }
            .store(in: &subscriptions)
    }

    deinit {
        subscriptions.unsubscribeAll()
        loadTask?.cancel()
    }

    private func load(_ urlString: String) {
        loadTask?.cancel()
        guard let url = URL(string: urlString), !urlString.isEmpty else { return }
        loadTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = PlatformImage(data: data) else { return }
            DispatchQueue.main.async { self?.imageView.image = image }
        }
        loadTask?.resume()
    }

    /// Maps an image variant to size constraints (and avatar circular clip),
    /// mirroring SwiftUI's `defaultSizing(for:)`.
    private func applyVariant(_ variant: ImageVariant?) {
        sizeConstraints.forEach { $0.isActive = false }
        sizeConstraints = []
        imageView.translatesAutoresizingMaskIntoConstraints = false

        switch variant {
        case .icon:
            sizeConstraints = [imageView.widthAnchor.constraint(equalToConstant: 24),
                               imageView.heightAnchor.constraint(equalToConstant: 24)]
        case .avatar:
            sizeConstraints = [imageView.widthAnchor.constraint(equalToConstant: 40),
                               imageView.heightAnchor.constraint(equalToConstant: 40)]
            imageView.a2ui_setCornerRadius(20)
        case .smallFeature:
            sizeConstraints = [imageView.widthAnchor.constraint(lessThanOrEqualToConstant: 100)]
        case .largeFeature:
            sizeConstraints = [imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 400)]
        case .header:
            sizeConstraints = [imageView.heightAnchor.constraint(equalToConstant: 200)]
        default:
            break // mediumFeature / nil — unconstrained
        }
        sizeConstraints.forEach { $0.isActive = true }
    }

    private func applyFit(_ fit: ImageFit) {
        #if canImport(UIKit) && !os(watchOS)
        switch fit {
        case .contain, .scaleDown: imageView.contentMode = .scaleAspectFit
        case .cover:               imageView.contentMode = .scaleAspectFill
        case .fill:                imageView.contentMode = .scaleToFill
        case .none:                imageView.contentMode = .center
        case .unknown:             imageView.contentMode = .scaleAspectFit
        }
        imageView.clipsToBounds = true
        #elseif canImport(AppKit)
        switch fit {
        case .contain, .scaleDown: imageView.imageScaling = .scaleProportionallyUpOrDown
        case .cover, .fill:        imageView.imageScaling = .scaleAxesIndependently
        case .none:                imageView.imageScaling = .scaleNone
        case .unknown:             imageView.imageScaling = .scaleProportionallyUpOrDown
        }
        #endif
    }
}

#endif
