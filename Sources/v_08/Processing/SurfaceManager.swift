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

// MARK: - VersionedSurface

/// Wraps either a v0.8 or v0.9 surface view model.
public enum VersionedSurface {
    case v08(SurfaceViewModel_V08)
    case v09(SurfaceViewModel_V09)

    public var a2uiStyle: A2UIStyle {
        switch self {
        case .v08(let vm): return vm.a2uiStyle
        case .v09(let vm): return vm.a2uiStyle
        }
    }

    /// Unwrap as v0.8 view model (returns nil if v0.9).
    public var asV08: SurfaceViewModel_V08? {
        if case .v08(let vm) = self { return vm }
        return nil
    }

    /// Unwrap as v0.9 view model (returns nil if v0.8).
    public var asV09: SurfaceViewModel_V09? {
        if case .v09(let vm) = self { return vm }
        return nil
    }

    // MARK: - Common Accessors (version-agnostic)

    public var rootComponentId: String? {
        switch self {
        case .v08(let vm): return vm.rootComponentId
        case .v09(let vm): return vm.rootComponentId
        }
    }

    public var components: [String: Any] {
        switch self {
        case .v08(let vm): return vm.components
        case .v09(let vm): return vm.components
        }
    }

    public var dataModel: [String: AnyCodable] {
        switch self {
        case .v08(let vm): return vm.dataModel
        case .v09(let vm): return vm.dataModel
        }
    }

    public var styles: [String: String] {
        switch self {
        case .v08(let vm): return vm.styles
        case .v09: return [:]  // v0.9 uses structured theme, not string map
        }
    }

    public func getDataByPath(_ path: String) -> AnyCodable? {
        switch self {
        case .v08(let vm): return vm.getDataByPath(path)
        case .v09(let vm): return vm.dataStore.getDataByPath(path)
        }
    }
}

// MARK: - SurfaceManager

/// Manages multiple A2UI surfaces, supporting both v0.8 and v0.9 protocols.
/// Routes incoming messages to the correct versioned SurfaceViewModel.
@Observable
public final class SurfaceManager {
    /// All active surfaces, keyed by surfaceId.
    public private(set) var surfaces: [String: VersionedSurface] = [:]

    /// Ordered list of surface IDs, preserving creation order.
    public private(set) var orderedSurfaceIds: [String] = []

    private let decoder = JSONDecoder()

    public init() {}

    /// Remove all surfaces.
    public func clearAll() {
        surfaces.removeAll()
        orderedSurfaceIds.removeAll()
    }

    // MARK: - Version-Aware Processing

    /// Process a versioned message, routing to the correct surface.
    public func processMessage(_ message: VersionedMessage) throws {
        if message.isDeleteSurface, let sid = message.surfaceId {
            surfaces.removeValue(forKey: sid)
            orderedSurfaceIds.removeAll { $0 == sid }
            return
        }

        guard let surfaceId = message.surfaceId else { return }

        switch message {
        case .v08(let msg):
            let vm: SurfaceViewModel_V08
            if case .v08(let existing) = surfaces[surfaceId] {
                vm = existing
            } else {
                vm = SurfaceViewModel_V08()
                surfaces[surfaceId] = .v08(vm)
                orderedSurfaceIds.append(surfaceId)
            }
            try vm.processMessage(msg)

        case .v09(let msg):
            let vm: SurfaceViewModel_V09
            if case .v09(let existing) = surfaces[surfaceId] {
                vm = existing
            } else {
                vm = SurfaceViewModel_V09()
                surfaces[surfaceId] = .v09(vm)
                orderedSurfaceIds.append(surfaceId)
            }
            try vm.processMessage(msg)
        }
    }

    /// Process raw JSON data with auto version detection.
    public func processRawMessage(_ data: Data) throws {
        let version = A2UIProtocolVersion.detect(from: data)
        switch version {
        case .v08:
            let msg = try decoder.decode(ServerToClientMessage_V08.self, from: data)
            try processMessage(.v08(msg))
        case .v09:
            let msg = try decoder.decode(ServerToClientMessage_V09.self, from: data)
            try processMessage(.v09(msg))
        }
    }

    // MARK: - v0.8 Backward Compatibility

    /// Process v0.8 messages directly (backward compatible).
    public func processMessages(_ messages: [ServerToClientMessage_V08]) throws {
        for message in messages {
            try processMessage(.v08(message))
        }
    }

    /// Process a single v0.8 message (backward compatible).
    public func processMessage(_ message: ServerToClientMessage_V08) throws {
        try processMessage(.v08(message))
    }
}
