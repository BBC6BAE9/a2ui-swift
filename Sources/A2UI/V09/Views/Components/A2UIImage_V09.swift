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

/// # Image
/// Uses `AsyncImage` for remote URLs. Sizing is driven by `variant` (avatar/icon/header/etc.)
/// with sensible defaults, overridable via `A2UIStyle.imageStyles`. The `fit` property maps to
/// `contentMode` (.fit/.fill) plus `clipped()`. Avatar uses `Circle()` clip; others use
/// `RoundedRectangle`. Placeholder shown on failure or invalid URL.
struct A2UIImage_V09: View {
    let node: ComponentNode_V09
    var viewModel: SurfaceViewModel_V09

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(ImageProperties_V09.self) {
            let urlString = viewModel.resolveString(
                props.url, dataContextPath: dataContextPath
            )
            let variant = props.variant
            let defaults = defaultImageSizing(for: variant)
            let override = style.imageStyles[variant?.rawValue ?? ""]
            let sizing = ImageSizing(
                width: override?.width ?? defaults.width,
                height: override?.height ?? defaults.height
            )
            let radius = override?.cornerRadius ?? defaultCornerRadius(for: variant)

            if let url = URL(string: urlString),
               let scheme = url.scheme, ["http", "https"].contains(scheme) {
                clippedImage(variant: variant, radius: radius, sizing: sizing) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            fitImage(image, fit: props.fit, sizing: sizing)
                        case .failure:
                            imagePlaceholder(sizing)
                        default:
                            ProgressView()
                                .frame(width: sizing.width, height: sizing.height)
                        }
                    }
                }
            } else {
                imagePlaceholder(sizing)
            }
        }
    }

    private struct ImageSizing {
        var width: CGFloat?
        var height: CGFloat
    }

    private func defaultImageSizing(for variant: ImageVariant_V09?) -> ImageSizing {
        switch variant {
        case .icon:          return ImageSizing(width: 32, height: 32)
        case .avatar:        return ImageSizing(width: 32, height: 32)
        case .smallFeature:  return ImageSizing(width: 50, height: 50)
        case .mediumFeature: return ImageSizing(width: nil, height: 150)
        case .largeFeature:  return ImageSizing(width: nil, height: 400)
        case .header:        return ImageSizing(width: nil, height: 240)
        default:             return ImageSizing(width: nil, height: 150)
        }
    }

    private func defaultCornerRadius(for variant: ImageVariant_V09?) -> CGFloat {
        variant == .avatar ? 0 : 4  // avatar uses Circle clip; radius unused
    }

    private func clippedImage(
        variant: ImageVariant_V09?,
        radius: CGFloat,
        sizing: ImageSizing,
        @ViewBuilder content: () -> some View
    ) -> some View {
        content()
            .frame(width: sizing.width, height: sizing.height)
            .frame(maxWidth: sizing.width == nil ? .infinity : nil)
            .clipped()
            .clipShape(variant == .avatar
                ? AnyShape(Circle())
                : AnyShape(RoundedRectangle(cornerRadius: radius)))
    }

    @ViewBuilder
    private func fitImage(_ image: SwiftUI.Image, fit: ImageFit_V09?, sizing: ImageSizing) -> some View {
        switch fit {
        case .cover:
            image.resizable().aspectRatio(contentMode: .fill)
        case .fill:
            image.resizable()
        case .some(.none):
            image
        case .scaleDown:
            image.resizable().aspectRatio(contentMode: .fit)
                .frame(maxWidth: sizing.width, maxHeight: sizing.height)
        default:
            image.resizable().aspectRatio(contentMode: .fit)
        }
    }

    private func imagePlaceholder(_ sizing: ImageSizing) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.15))
            .frame(width: sizing.width, height: sizing.height)
            .frame(maxWidth: sizing.width == nil ? .infinity : nil)
            .overlay {
                Image(systemName: "photo")
                    .font((sizing.width ?? .infinity) < 50 ? .caption : .largeTitle)
                    .foregroundStyle(.tertiary)
            }
    }
}
