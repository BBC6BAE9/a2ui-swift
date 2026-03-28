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

// MARK: - ListTasksParams

/// Defines the parameters for the `tasks/list` RPC method.
///
/// These parameters allow clients to filter, paginate, and control the scope
/// of the task list returned by the server.
///
/// Mirrors Dart `ListTasksParams` in `a2a/core/list_tasks_params.dart`.
public struct ListTasksParams: Codable, Sendable, Equatable {

    /// Optional. Filter tasks by context ID.
    public let contextId: String?

    /// Optional. Filter tasks by their current ``TaskState``.
    public let status: TaskState?

    /// The maximum number of tasks to return in a single response.
    /// Defaults to 50.
    public let pageSize: Int

    /// An opaque token used to retrieve the next page of results.
    public let pageToken: String?

    /// The number of recent messages to include in each task's history.
    /// Defaults to 0.
    public let historyLength: Int

    /// Optional. Filter tasks updated at or after this timestamp (ms since epoch).
    public let lastUpdatedAfter: Int?

    /// Whether to include associated artifacts in the returned tasks.
    /// Defaults to `false`.
    public let includeArtifacts: Bool

    /// Optional. Request-specific metadata for extensions.
    public let metadata: JSONObject?

    public init(
        contextId: String? = nil,
        status: TaskState? = nil,
        pageSize: Int = 50,
        pageToken: String? = nil,
        historyLength: Int = 0,
        lastUpdatedAfter: Int? = nil,
        includeArtifacts: Bool = false,
        metadata: JSONObject? = nil
    ) {
        self.contextId = contextId
        self.status = status
        self.pageSize = pageSize
        self.pageToken = pageToken
        self.historyLength = historyLength
        self.lastUpdatedAfter = lastUpdatedAfter
        self.includeArtifacts = includeArtifacts
        self.metadata = metadata
    }
}
