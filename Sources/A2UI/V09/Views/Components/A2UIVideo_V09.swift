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

/// Spec v0.9 Video — video player component.
///
/// Spec properties:
/// - `url` (required): DynamicString_V09 — video URL
///
/// Uses the shared `VideoNodeView` / `SharedPlayerController` infrastructure
/// (defined in V08) for actual playback.
struct A2UIVideo_V09: View {
    let node: ComponentNode_V09
    var viewModel: SurfaceViewModel_V09

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(VideoProperties_V09.self) {
            let urlString = viewModel.resolveString(
                props.url, dataContextPath: dataContextPath
            )
            let cr = style.videoStyle.cornerRadius ?? 10
            if !urlString.isEmpty, URL(string: urlString) != nil {
                VideoNodeView(
                    urlString: urlString,
                    uiState: node.uiState as? VideoUIState,
                    nodeId: node.id,
                    cornerRadius: cr
                )
            } else {
                RoundedRectangle(cornerRadius: cr)
                    .fill(Color.gray.opacity(0.15))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                    }
            }
        }
    }
}
