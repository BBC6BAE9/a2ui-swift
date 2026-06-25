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
import JSONSchema

// MARK: - Catalog

/// A function schema definition stored by a catalog before it is converted to
/// the wire-format `FunctionDefinition` used by client capabilities.
public struct CatalogFunctionApi {
    public let name: String
    public let description: String?
    public let parameters: Schema
    public let returnType: FunctionCallReturnType

    public init(
        name: String,
        description: String? = nil,
        parameters: Schema,
        returnType: FunctionCallReturnType
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.returnType = returnType
    }
}

/// A collection of available component type names and optional function implementations.
/// Mirrors WebCore `Catalog` in catalog/types.ts.
public final class Catalog {
    /// The unique identifier for this catalog (e.g. "basic-catalog").
    public let id: String

    /// The set of known component type names (e.g. ["Button", "Text"]).
    public let componentNames: Set<String>

    /// JSON Schemas for component properties, keyed by component name.
    public let componentSchemas: [String: Schema]

    /// Named function implementations, keyed by function name.
    public let functions: [String: FunctionInvoker]

    /// Function schemas and return-type metadata used for inline catalog generation.
    public let functionApis: [CatalogFunctionApi]

    /// JSON Schema for theme parameters used by this catalog.
    public let themeSchema: Schema?

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
        componentSchemas: [String: Schema] = [:],
        functions: [String: FunctionInvoker] = [:],
        functionApis: [CatalogFunctionApi] = [],
        themeSchema: Schema? = nil
    ) {
        self.id = id
        self.componentNames = componentNames.union(componentSchemas.keys)
        self.componentSchemas = componentSchemas
        self.functions = functions
        self.functionApis = functionApis
        self.themeSchema = themeSchema
    }
}
