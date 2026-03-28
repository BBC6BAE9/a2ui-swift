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

// MARK: - ResolvedAction

/// An action whose context paths have been resolved to actual values.
/// Shared across protocol versions — both v0.8 and v0.9 produce this type.
public struct ResolvedAction: Sendable {
    public let name: String
    public let sourceComponentId: String
    public let context: [String: AnyCodable]

    public init(name: String, sourceComponentId: String, context: [String: AnyCodable]) {
        self.name = name
        self.sourceComponentId = sourceComponentId
        self.context = context
    }
}
