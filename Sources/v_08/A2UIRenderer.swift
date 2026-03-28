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

/// The main entry point for rendering A2UI surfaces in SwiftUI.
public struct A2UIRendererView: View {
    private let manager: SurfaceManager
    private let onAction: ((ResolvedAction) -> Void)?

    public init(
        manager: SurfaceManager,
        onAction: ((ResolvedAction) -> Void)? = nil
    ) {
        self.manager = manager
        self.onAction = onAction
    }

    public var body: some View {
        Group {
            if manager.orderedSurfaceIds.isEmpty {
                ContentUnavailableView(
                    "No Surface",
                    systemImage: "rectangle.dashed",
                    description: Text("Waiting for A2UI messages…")
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(manager.orderedSurfaceIds, id: \.self) { surfaceId in
                        if let surface = manager.surfaces[surfaceId] {
                            renderSurface(surface)
                        }
                    }
                }
            }
        }
        .environment(\.a2uiActionHandler, onAction)
    }

    @ViewBuilder
    private func renderSurface(_ surface: VersionedSurface) -> some View {
        switch surface {
        case .v08(let vm):
            if let rootNode = vm.componentTree {
                ScrollView {
                    A2UIComponentView_V08(node: rootNode, viewModel: vm)
                        .padding()
                }
                .tint(vm.a2uiStyle.primaryColor)
                .environment(\.a2uiStyle, vm.a2uiStyle)
            }
        }
    }
}
