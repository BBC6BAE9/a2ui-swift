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

/// Spec v0.9 AudioPlayer — audio playback component.
///
/// Spec properties:
/// - `url` (required): DynamicString — audio URL
/// - `description` (optional): DynamicString — label above the player
///
/// Uses the shared `AudioPlayerNodeView` infrastructure (defined in V08) for
/// actual playback.
struct A2UIAudioPlayer: View {
    let node: ComponentNode
    let surface: SurfaceModel

    @Environment(\.a2uiStyle) private var style

    private var dataContextPath: String { node.dataContextPath }

    var body: some View {
        if let props = try? node.typedProperties(AudioPlayerProperties.self) {
            let dc = DataContext(surface: surface, path: dataContextPath)
            AudioPlayerNodeView(
                url: dc.resolve(props.url),
                label: props.description.map { dc.resolve($0) },
                uiState: node.uiState as? AudioPlayerUIState,
                apStyle: style.audioPlayerStyle
            )
            .a2uiAccessibility(node.accessibility, dataContext: dc)
            .padding(style.leafMargin)
        }
    }
}
