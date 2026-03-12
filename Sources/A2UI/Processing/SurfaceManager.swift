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

import Foundation
import Observation

/// Manages multiple A2UI surfaces, each keyed by its `surfaceId`.
///
/// The A2UI protocol supports rendering multiple independent surfaces
/// simultaneously (e.g., a contact card and an org chart side by side).
/// `SurfaceManager` routes incoming messages to the correct
/// `SurfaceViewModel` based on each message's `surfaceId`.
@Observable
public final class SurfaceManager {
    /// All active surfaces, keyed by surfaceId.
    public private(set) var surfaces: [String: SurfaceViewModel] = [:]

    /// Ordered list of surface IDs, preserving the order in which they were created.
    public private(set) var orderedSurfaceIds: [String] = []

    public init() {}

    /// Remove all surfaces — matching the Angular renderer's `clearSurfaces()`.
    /// Called before processing a fresh response so old surfaces don't accumulate.
    public func clearAll() {
        surfaces.removeAll()
        orderedSurfaceIds.removeAll()
    }

    /// Process an array of messages, routing each to the correct surface.
    public func processMessages(_ messages: [ServerToClientMessage]) throws {
        for message in messages {
            try processMessage(message)
        }
    }

    /// Process a single message, routing it to the correct surface by surfaceId.
    public func processMessage(_ message: ServerToClientMessage) throws {
        if let ds = message.deleteSurface {
            surfaces.removeValue(forKey: ds.surfaceId)
            orderedSurfaceIds.removeAll { $0 == ds.surfaceId }
            return
        }

        guard let surfaceId = extractSurfaceId(from: message) else { return }

        let vm = surfaces[surfaceId] ?? {
            let new = SurfaceViewModel()
            surfaces[surfaceId] = new
            orderedSurfaceIds.append(surfaceId)
            return new
        }()

        try vm.processMessage(message)
    }

    /// Extract the surfaceId from any message type.
    private func extractSurfaceId(from message: ServerToClientMessage) -> String? {
        message.beginRendering?.surfaceId
            ?? message.surfaceUpdate?.surfaceId
            ?? message.dataModelUpdate?.surfaceId
    }
}
