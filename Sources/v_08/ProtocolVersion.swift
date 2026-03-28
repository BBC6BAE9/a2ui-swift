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

// MARK: - Protocol Version

/// Supported A2UI protocol versions.
public enum A2UIProtocolVersion: String, Sendable {
    case v08 = "v0.8"
    case v09 = "v0.9"

    /// Detect protocol version from raw JSON data.
    ///
    /// Detection strategy (in priority order):
    /// 1. Explicit `"version": "v0.9"` field (spec-required for v0.9)
    /// 2. v0.9-only message keys: `createSurface`, `updateComponents`, `updateDataModel`
    /// 3. v0.8-only message keys: `beginRendering`, `surfaceUpdate`, `dataModelUpdate`
    /// 4. Falls back to v0.8 if undetermined
    /// Fast byte-scan markers for version detection (avoids full JSON parse).
    private static let v09Markers: [Data] = [
        Data("\"createSurface\"".utf8),
        Data("\"updateComponents\"".utf8),
        Data("\"updateDataModel\"".utf8),
        Data("\"version\":\"v0.9\"".utf8),
        Data("\"version\": \"v0.9\"".utf8),
    ]

    private static let v08Markers: [Data] = [
        Data("\"beginRendering\"".utf8),
        Data("\"surfaceUpdate\"".utf8),
        Data("\"dataModelUpdate\"".utf8),
    ]

    public static func detect(from data: Data) -> A2UIProtocolVersion {
        // Fast path: scan raw bytes for version-specific markers.
        // Avoids JSONSerialization overhead on every message.
        for marker in v09Markers {
            if data.range(of: marker) != nil { return .v09 }
        }
        for marker in v08Markers {
            if data.range(of: marker) != nil { return .v08 }
        }
        // deleteSurface exists in both versions — default to v0.8
        return .v08
    }
}

// MARK: - VersionedMessage

/// A protocol message tagged with its version, used by version-aware dispatch layers.
public enum VersionedMessage {
    case v08(ServerToClientMessage_V08)
    case v09(ServerToClientMessage_V09)

    public var protocolVersion: A2UIProtocolVersion {
        switch self {
        case .v08: return .v08
        case .v09: return .v09
        }
    }

    /// Extract the surfaceId from any versioned message.
    public var surfaceId: String? {
        switch self {
        case .v08(let msg):
            return msg.beginRendering?.surfaceId
                ?? msg.surfaceUpdate?.surfaceId
                ?? msg.dataModelUpdate?.surfaceId
                ?? msg.deleteSurface?.surfaceId
        case .v09(let msg):
            return msg.createSurface?.surfaceId
                ?? msg.updateComponents?.surfaceId
                ?? msg.updateDataModel?.surfaceId
                ?? msg.deleteSurface?.surfaceId
        }
    }

    /// Whether this is a delete surface message.
    public var isDeleteSurface: Bool {
        switch self {
        case .v08(let msg): return msg.deleteSurface != nil
        case .v09(let msg): return msg.deleteSurface != nil
        }
    }
}
