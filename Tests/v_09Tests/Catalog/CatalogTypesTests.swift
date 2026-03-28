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

import Testing
import Foundation
@testable import v_09

// MARK: - CatalogTypesTests
//
// Mirrors WebCore catalog/types.test.ts  →  describe("Catalog Types", ...)

@Suite("Catalog Types")
struct CatalogTypesTests {

    // MARK: - Helpers

    /// Returns a minimal DataContext backed by an empty SurfaceModel.
    private func makeContext(catalog: Catalog = Catalog(id: "test-catalog")) -> DataContext {
        let surface = SurfaceModel(id: "s1", catalog: catalog)
        return DataContext(surface: surface, path: "/")
    }

    // MARK: - Tests

    /// Mirrors: it("creates a catalog with functions", ...)
    @Test("creates a catalog with functions")
    func createsCatalogWithFunctions() {
        let mockFunc: FunctionInvoker = { _, _, _ in .string("ok") }

        let catalog = Catalog(
            id: "my-catalog",
            componentNames: ["Button"],
            functions: ["mockFunc": mockFunc]
        )

        #expect(catalog.id == "my-catalog")
        #expect(catalog.componentNames.count == 1)
        #expect(catalog.functions.count == 1)
        #expect(catalog.functions["mockFunc"] != nil)
    }

    /// Mirrors: it("throws A2uiExpressionError when function is not found", ...)
    @Test("throws A2uiExpressionError when function is not found")
    func throwsExpressionErrorWhenFunctionNotFound() throws {
        // Catalog with no registered functions.
        let catalog = Catalog(id: "empty-catalog")
        let ctx = makeContext(catalog: catalog)

        #expect(throws: A2uiExpressionError.self) {
            try catalog.invoker("nonExistent", [:], ctx)
        }
    }

    // NOTE: The WebCore test "throws A2uiExpressionError when zod validation fails" has no Swift
    // equivalent. Zod is a TypeScript-only runtime schema-validation library; Swift uses Codable
    // with compile-time type safety instead. There is no dynamic schema-validation step in the
    // Swift Catalog that could produce an equivalent error, so this test case is intentionally
    // omitted.
}
