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

// Mirrors WebCore schema/client-capabilities.ts

// MARK: - FunctionDefinition

/// Describes a function's interface within an inline catalog.
/// Mirrors WebCore `FunctionDefinition`.
public struct FunctionDefinition: Codable {
    public let name: String
    public let description: String?
    /// JSON Schema object describing the function's parameters.
    public let parameters: AnyCodable
    public let returnType: FunctionCallReturnType

    public init(
        name: String,
        description: String? = nil,
        parameters: AnyCodable = .dictionary([:]),
        returnType: FunctionCallReturnType
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.returnType = returnType
    }
}

// MARK: - InlineCatalog

/// Defines a catalog inline for the A2uiClientCapabilities object.
/// Mirrors WebCore `InlineCatalog`.
public struct InlineCatalog: Codable {
    public let catalogId: String
    /// Map of component names to their JSON Schema definitions.
    public let components: [String: AnyCodable]?
    public let functions: [FunctionDefinition]?
    /// Map of theme parameter names to their JSON Schema definitions.
    public let theme: [String: AnyCodable]?

    public init(
        catalogId: String,
        components: [String: AnyCodable]? = nil,
        functions: [FunctionDefinition]? = nil,
        theme: [String: AnyCodable]? = nil
    ) {
        self.catalogId = catalogId
        self.components = components
        self.functions = functions
        self.theme = theme
    }
}

// MARK: - A2uiClientCapabilities

/// The capabilities structure sent from the client to the server as part of transport metadata.
/// Mirrors WebCore `A2uiClientCapabilities`.
public struct A2uiClientCapabilities: Codable {

    public struct V09Capabilities: Codable {
        public let supportedCatalogIds: [String]
        public let inlineCatalogs: [InlineCatalog]?

        public init(supportedCatalogIds: [String], inlineCatalogs: [InlineCatalog]? = nil) {
            self.supportedCatalogIds = supportedCatalogIds
            self.inlineCatalogs = inlineCatalogs
        }
    }

    public let v09: V09Capabilities

    private enum CodingKeys: String, CodingKey {
        case v09 = "v0.9"
    }

    public init(v09: V09Capabilities) {
        self.v09 = v09
    }

    /// Creates a capabilities object from an array of catalogs.
    /// Use this to auto-populate `supportedCatalogIds` from the catalogs
    /// passed to `MessageProcessor` or `SurfaceViewModel`.
    ///
    /// Example:
    /// ```swift
    /// let capabilities = A2uiClientCapabilities.make(from: [basicCatalog])
    /// ```
    public static func make(
        from catalogs: [Catalog],
        inlineCatalogs: [InlineCatalog]? = nil
    ) -> A2uiClientCapabilities {
        A2uiClientCapabilities(
            v09: V09Capabilities(
                supportedCatalogIds: catalogs.map(\.id),
                inlineCatalogs: inlineCatalogs
            )
        )
    }
}
