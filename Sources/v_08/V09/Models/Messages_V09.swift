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

/// A single v0.9 message from the A2UI server to the client.
/// Each message contains `"version": "v0.9"` and exactly one of four payloads.
public struct ServerToClientMessage_V09: Codable {
    public var version: String?
    public var createSurface: CreateSurfaceMessage_V09?
    public var updateComponents: UpdateComponentsMessage_V09?
    public var updateDataModel: UpdateDataModelMessage_V09?
    public var deleteSurface: DeleteSurfaceMessage_V09?
}

/// Signals the client to create a new surface and begin rendering it.
public struct CreateSurfaceMessage_V09: Codable {
    public var surfaceId: String
    public var catalogId: String
    public var theme: AnyCodable?
    public var sendDataModel: Bool?
}

/// Adds or updates components in a surface's component buffer (flat format).
public struct UpdateComponentsMessage_V09: Codable {
    public var surfaceId: String
    public var components: [RawComponentInstance_V09]
}

/// Updates the data model for a surface using JSON Pointer path + standard JSON value.
public struct UpdateDataModelMessage_V09: Codable {
    public var surfaceId: String
    public var path: String?
    public var value: AnyCodable?
}

/// Removes a surface and all its associated data.
public struct DeleteSurfaceMessage_V09: Codable {
    public var surfaceId: String
}
