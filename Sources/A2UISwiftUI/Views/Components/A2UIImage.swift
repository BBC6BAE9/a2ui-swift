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

import SwiftUI
import A2UISwiftCore

/// # Image
///
/// Renders an image from a remote URL or local asset path.
///
/// ## Sizing philosophy (aligned with A2UI spec + React v0.9 reference)
///
/// The Image component uses **flexible** sizing so that parent components can
/// control the image's dimensions. Only `icon` and `avatar` variants use fixed
/// dimensions; all others adapt to their container.
///
/// - `fit` controls **how pixels fill the box** (maps to `contentMode`).
/// - `variant` provides **suggested** sizing as flexible constraints
///   (`maxWidth`/`maxHeight`), not hard-coded frames.
/// - Parent components can override sizing by applying their own `.frame()`.
///
/// This matches the A2UI spec implementation guide: "Ensure the component
/// defaults to a flexible width so it fills its container."
struct A2UIImage: View {
    let node: ComponentNode
    let surface: SurfaceModel

    @Environment(\.a2uiStyle) private var style
    @Environment(\.a2uiImageResolver) private var imageResolver

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(ImageProperties.self) {
            let dc = DataContext(surface: surface, path: dataContextPath)
            let variant = props.variant
            let sizing = resolvedSizing(for: variant)
            let radius = style.imageStyles[variant?.rawValue ?? ""]?.cornerRadius
                ?? defaultCornerRadius(for: variant)

            Group {
                if dc.isUnresolvedBinding(props.url) {
                    variantContainer(variant: variant, radius: radius, sizing: sizing) {
                        imagePlaceholder(sizing)
                    }
                } else {
                    let urlString = dc.resolve(props.url)
                    if let url = URL(string: urlString),
                       let scheme = url.scheme, ["http", "https"].contains(scheme) {
                        variantContainer(variant: variant, radius: radius, sizing: sizing) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    fitImage(image, fit: effectiveFit(props.fit, variant: variant))
                                case .failure:
                                    imagePlaceholder(sizing)
                                default:
                                    placeholderFrame(sizing) {
                                        ProgressView()
                                    }
                                }
                            }
                        }
                    } else if let resolver = imageResolver,
                              let image = resolver(urlString) {
                        variantContainer(variant: variant, radius: radius, sizing: sizing) {
                            fitImage(image, fit: effectiveFit(props.fit, variant: variant))
                        }
                    } else {
                        imagePlaceholder(sizing)
                    }
                }
            }
            .a2uiAccessibility(node.accessibility, dataContext: dc)
            .padding(style.leafMargin)
        }
    }

    // MARK: - Sizing Model

    /// Flexible sizing constraints. Uses optional values — `nil` means
    /// "no constraint on this axis, let the parent decide."
    struct FlexibleSizing {
        var fixedWidth: CGFloat?
        var fixedHeight: CGFloat?
        var maxWidth: CGFloat?
        var maxHeight: CGFloat?

        var isFixedSize: Bool { fixedWidth != nil && fixedHeight != nil }
    }

    /// Resolves the effective sizing by merging style overrides with defaults.
    private func resolvedSizing(for variant: ImageVariant?) -> FlexibleSizing {
        let defaults = defaultSizing(for: variant)
        guard let override = style.imageStyles[variant?.rawValue ?? ""] else {
            return defaults
        }
        return FlexibleSizing(
            fixedWidth: override.width ?? defaults.fixedWidth,
            fixedHeight: override.height ?? defaults.fixedHeight,
            maxWidth: override.maxWidth ?? defaults.maxWidth,
            maxHeight: override.maxHeight ?? defaults.maxHeight
        )
    }

    /// Default sizing per variant, aligned with A2UI spec implementation guide
    /// and React v0.9 reference renderer.
    private func defaultSizing(for variant: ImageVariant?) -> FlexibleSizing {
        switch variant {
        case .icon:
            return FlexibleSizing(fixedWidth: 24, fixedHeight: 24)
        case .avatar:
            return FlexibleSizing(fixedWidth: 40, fixedHeight: 40)
        case .smallFeature:
            return FlexibleSizing(maxWidth: 100)
        case .largeFeature:
            return FlexibleSizing(maxHeight: 400)
        case .header:
            return FlexibleSizing(fixedHeight: 200)
        case .mediumFeature, .none, .some(.unknown):
            return FlexibleSizing()
        }
    }

    private func defaultCornerRadius(for variant: ImageVariant?) -> CGFloat {
        variant == .avatar ? 0 : 4
    }

    // MARK: - Variant Container

    /// Applies sizing constraints and clip shape based on variant.
    /// Uses flexible constraints so parent components can override sizing.
    @ViewBuilder
    private func variantContainer(
        variant: ImageVariant?,
        radius: CGFloat,
        sizing: FlexibleSizing,
        @ViewBuilder content: () -> some View
    ) -> some View {
        let clipShape: AnyShape = variant == .avatar
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: radius))

        if sizing.isFixedSize {
            content()
                .frame(width: sizing.fixedWidth, height: sizing.fixedHeight)
                .clipped()
                .clipShape(clipShape)
        } else {
            content()
                .frame(maxWidth: sizing.maxWidth ?? .infinity,
                       maxHeight: sizing.maxHeight)
                .frame(height: sizing.fixedHeight)
                .clipped()
                .clipShape(clipShape)
        }
    }

    // MARK: - Fit

    /// Maps `fit` to SwiftUI's resizable + contentMode.
    /// Header variant forces `cover` per spec.
    private func effectiveFit(_ fit: ImageFit?, variant: ImageVariant?) -> ImageFit {
        if variant == .header { return .cover }
        return fit ?? .fill
    }

    @ViewBuilder
    private func fitImage(_ image: SwiftUI.Image, fit: ImageFit) -> some View {
        switch fit {
        case .cover:
            image.resizable().aspectRatio(contentMode: .fill)
        case .fill:
            image.resizable()
        case .contain:
            image.resizable().aspectRatio(contentMode: .fit)
        case .scaleDown:
            image.resizable().aspectRatio(contentMode: .fit)
        case .none:
            image
        case .unknown:
            image.resizable().aspectRatio(contentMode: .fit)
        }
    }

    // MARK: - Placeholder

    /// Provides a reasonable frame for placeholder/loading states.
    /// Uses fixed dimensions for fixed-size variants, otherwise a sensible
    /// default height so the placeholder doesn't collapse to zero.
    @ViewBuilder
    private func placeholderFrame(
        _ sizing: FlexibleSizing,
        @ViewBuilder content: () -> some View
    ) -> some View {
        if sizing.isFixedSize {
            content()
                .frame(width: sizing.fixedWidth, height: sizing.fixedHeight)
        } else {
            content()
                .frame(maxWidth: sizing.maxWidth ?? .infinity)
                .frame(height: sizing.fixedHeight ?? min(sizing.maxHeight ?? 150, 150))
        }
    }

    private func imagePlaceholder(_ sizing: FlexibleSizing) -> some View {
        let isSmall = (sizing.fixedWidth ?? sizing.maxWidth ?? .infinity) < 50
        return RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.15))
            .overlay {
                Image(systemName: "photo")
                    .font(isSmall ? .caption : .largeTitle)
                    .foregroundStyle(.tertiary)
            }
    }
}
