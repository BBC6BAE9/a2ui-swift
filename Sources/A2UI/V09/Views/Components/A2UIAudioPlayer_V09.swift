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

/// Spec v0.9 AudioPlayer — audio playback component.
///
/// Spec properties:
/// - `url` (required): DynamicString_V09 — audio URL
/// - `description` (optional): DynamicString_V09 — label above the player
///
/// Uses the shared `AudioPlayerNodeView` infrastructure (defined in V08) for
/// actual playback.
struct A2UIAudioPlayer_V09: View {
    let node: ComponentNode_V09
    var viewModel: SurfaceViewModel_V09

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(AudioPlayerProperties_V09.self) {
            AudioPlayerNodeView(
                url: viewModel.resolveString(props.url, dataContextPath: dataContextPath),
                label: props.description.map {
                    viewModel.resolveString($0, dataContextPath: dataContextPath)
                },
                uiState: node.uiState as? AudioPlayerUIState,
                apStyle: style.audioPlayerStyle
            )
        }
    }
}
