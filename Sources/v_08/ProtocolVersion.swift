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

// MARK: - VersionedMessage

/// A protocol message wrapper for v0.8 dispatch.
public enum VersionedMessage {
    case v08(ServerToClientMessage_V08)

    /// Extract the surfaceId from the message.
    public var surfaceId: String? {
        switch self {
        case .v08(let msg):
            return msg.beginRendering?.surfaceId
                ?? msg.surfaceUpdate?.surfaceId
                ?? msg.dataModelUpdate?.surfaceId
                ?? msg.deleteSurface?.surfaceId
        }
    }

    /// Whether this is a delete surface message.
    public var isDeleteSurface: Bool {
        switch self {
        case .v08(let msg): return msg.deleteSurface != nil
        }
    }
}
