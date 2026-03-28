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

// MARK: - ListTasksResult

/// Represents the response from the `tasks/list` RPC method.
///
/// Contains a paginated list of tasks matching the request criteria.
///
/// Mirrors Dart `ListTasksResult` in `a2a/core/list_tasks_result.dart`.
public struct ListTasksResult: Codable, Sendable, Equatable {

    /// The list of ``A2ATask`` objects matching the specified filters and pagination.
    public let tasks: [A2ATask]

    /// The total number of tasks available on the server that match the filter
    /// criteria (ignoring pagination).
    public let totalSize: Int

    /// The maximum number of tasks requested per page.
    public let pageSize: Int

    /// An opaque token for retrieving the next page of results.
    /// If this string is empty, there are no more pages.
    public let nextPageToken: String

    public init(
        tasks: [A2ATask],
        totalSize: Int,
        pageSize: Int,
        nextPageToken: String
    ) {
        self.tasks = tasks
        self.totalSize = totalSize
        self.pageSize = pageSize
        self.nextPageToken = nextPageToken
    }
}
