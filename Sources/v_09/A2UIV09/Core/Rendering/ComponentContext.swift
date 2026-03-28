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

// MARK: - Errors

public enum ComponentContextError: Error, LocalizedError {
    case componentNotFound(id: String)

    public var errorDescription: String? {
        switch self {
        case .componentNotFound(let id):
            return "Component not found: \(id)"
        }
    }
}

// MARK: - ComponentContext

/// Context provided to a component during rendering.
/// Gives access to the component's model, the scoped data context,
/// the surface's component collection, and action dispatching.
/// Mirrors WebCore `ComponentContext`.
public final class ComponentContext {
    /// The state model for this specific component.
    public let componentModel: ComponentModel
    /// The data context scoped to this component's position in the hierarchy.
    public let dataContext: DataContext
    /// The collection of all component models for the current surface.
    public let surfaceComponents: SurfaceComponentsModel

    private let surface: SurfaceModel

    /// Creates a new component context.
    /// - Parameters:
    ///   - surface: The surface this component belongs to.
    ///   - componentId: The ID of the component.
    ///   - dataModelBasePath: The base path for data model access (default: "/").
    /// - Throws: `ComponentContextError.componentNotFound` if the component doesn't exist.
    public init(
        surface: SurfaceModel,
        componentId: String,
        dataModelBasePath: String = "/"
    ) throws {
        guard let model = surface.componentsModel.get(componentId) else {
            throw ComponentContextError.componentNotFound(id: componentId)
        }
        self.componentModel = model
        self.surfaceComponents = surface.componentsModel
        self.surface = surface
        self.dataContext = DataContext(surface: surface, path: dataModelBasePath)
    }

    /// Dispatches an action from this component.
    /// For event actions: resolves the action via dataContext.resolveAction() first,
    /// then forwards resolved name + context to surface.dispatchAction().
    /// For functionCall actions: executed locally by the renderer, not dispatched to the server.
    /// Mirrors WebCore `ComponentContext.dispatchAction(action)`.
    public func dispatchAction(_ action: Action) {
        guard case .event(let name, _) = action else { return }
        let resolved = dataContext.resolveAction(action)
        // Extract resolved context from the returned dictionary
        var resolvedContext: [String: AnyCodable] = [:]
        if case .dictionary(let outer) = resolved,
           case .dictionary(let event) = outer["event"],
           case .dictionary(let ctx) = event["context"] {
            resolvedContext = ctx
        }
        surface.dispatchAction(
            name: name,
            sourceComponentId: componentModel.id,
            context: resolvedContext
        )
    }

    /// Convenience overload — dispatches by explicit name + already-resolved context.
    public func dispatchAction(name: String, context: [String: AnyCodable] = [:]) {
        surface.dispatchAction(
            name: name,
            sourceComponentId: componentModel.id,
            context: context
        )
    }
}
