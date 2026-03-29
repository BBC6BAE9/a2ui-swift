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

// Mirrors WebCore test/test-utils.ts

@testable import A2UISwiftCore
import Foundation

// MARK: - TestSurfaceModel
//
// Mirrors WebCore `TestSurfaceModel`: a SurfaceModel pre-wired with a
// test catalog and an optional action handler subscription.

func makeTestSurface(
    id: String = "test",
    catalogId: String = "test-catalog",
    onAction: ((A2uiClientAction) -> Void)? = nil
) -> SurfaceModel {
    let catalog = Catalog(id: catalogId)
    let surface = SurfaceModel(id: id, catalog: catalog)
    if let handler = onAction {
        surface.onAction.subscribe(handler)
    }
    return surface
}

// MARK: - createTestContext
//
// Mirrors WebCore `createTestContext(properties, actionHandler)`:
// creates a surface, adds a single "TestComponent" with the given properties,
// and returns a ComponentContext scoped to it.

func createTestContext(
    properties: [String: AnyCodable] = [:],
    onAction: ((A2uiClientAction) -> Void)? = nil
) throws -> ComponentContext {
    let surface = makeTestSurface(onAction: onAction)
    let component = ComponentModel(id: "test-id", type: "TestComponent", properties: properties)
    try surface.componentsModel.addComponent(component)
    return try ComponentContext(surface: surface, componentId: "test-id", dataModelBasePath: "/")
}

// MARK: - createTestDataContext
//
// Mirrors the inline `createTestDataContext(model, path, invoker, errorHandler)`
// helper used throughout data-context.test.ts:
// creates a surface with optional catalog functions and pre-loaded data,
// returns a DataContext scoped to the given path.

func createTestDataContext(
    data: [String: AnyCodable] = [:],
    path: String = "/",
    functions: [String: FunctionInvoker] = [:]
) -> DataContext {
    let catalog = Catalog(id: "test-catalog", functions: functions)
    let surface = SurfaceModel(id: "test", catalog: catalog)
    if !data.isEmpty {
        try! surface.dataModel.set("/", value: .dictionary(data))
    }
    return DataContext(surface: surface, path: path)
}

// MARK: - makeSurface
//
// Mirrors the inline `makeSurface(data:)` helper used throughout
// data-context.test.ts: creates a bare SurfaceModel pre-loaded with
// optional data, for direct use in DataContext construction.

func makeSurface(data: [String: AnyCodable] = [:]) -> SurfaceModel {
    let catalog = Catalog(id: "test-catalog")
    let surface = SurfaceModel(id: "test", catalog: catalog)
    if !data.isEmpty {
        try! surface.dataModel.set("/", value: .dictionary(data))
    }
    return surface
}
