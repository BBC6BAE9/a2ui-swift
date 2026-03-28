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

// MARK: - Catalog

/// A collection of available component type names and optional function implementations.
/// Mirrors WebCore `Catalog` in catalog/types.ts.
public final class Catalog {
    /// The unique identifier for this catalog (e.g. "basic-catalog").
    public let id: String

    /// The set of known component type names (e.g. ["Button", "Text"]).
    public let componentNames: Set<String>

    /// Named function implementations, keyed by function name.
    public let functions: [String: FunctionInvoker]

    /// A ready-to-use FunctionInvoker that delegates to this catalog's registered functions.
    /// Mirrors WebCore `Catalog.invoker`.
    public var invoker: FunctionInvoker {
        return { [weak self] name, args, ctx in
            guard let self = self else { return nil }
            guard let fn = self.functions[name] else {
                throw A2uiExpressionError("Function not found in catalog '\(self.id)': \(name)", expression: name)
            }
            return try fn(name, args, ctx)
        }
    }

    public init(
        id: String,
        componentNames: Set<String> = [],
        functions: [String: FunctionInvoker] = [:]
    ) {
        self.id = id
        self.componentNames = componentNames
        self.functions = functions
    }
}
