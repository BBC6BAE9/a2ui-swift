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

/// A single message from the A2UI server to the client.
/// Each message contains exactly one of the four possible v0.8 payloads.
public struct ServerToClientMessage_V08: Codable {
    public var beginRendering: BeginRenderingMessage_V08?
    public var surfaceUpdate: SurfaceUpdateMessage_V08?
    public var dataModelUpdate: DataModelUpdateMessage_V08?
    public var deleteSurface: DeleteSurfaceMessage_V08?
}

/// Signals the client to begin rendering a surface.
public struct BeginRenderingMessage_V08: Codable {
    public var surfaceId: String
    public var root: String
    public var styles: [String: String]?
}

/// Adds or updates components in a surface's component buffer.
public struct SurfaceUpdateMessage_V08: Codable {
    public var surfaceId: String
    public var components: [RawComponentInstance_V08]
}

/// Updates the data model for a surface (v0.8 format with `contents` array).
public struct DataModelUpdateMessage_V08: Codable {
    public var surfaceId: String
    public var path: String?
    public var contents: [ValueMapEntry_V08]
}

/// Removes a surface and all its associated data.
public struct DeleteSurfaceMessage_V08: Codable {
    public var surfaceId: String
}
