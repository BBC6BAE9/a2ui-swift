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

#if (canImport(UIKit) && !os(watchOS)) || canImport(AppKit)
import A2UISwiftCore

// MARK: - A2UIPlatformComponent

/// A `PlatformView` that renders one A2UI component node.
///
/// Lifecycle contract — identical to the UIKit/AppKit stubs:
/// - `configure` is called when the view is (re)bound to a node. Always call
///   `subscriptions.unsubscribeAll()` at the top before establishing new ones.
/// - Container components receive the `factory` so they can build child views
///   for `node.children`; leaf components ignore it.
/// - Reactive reads go through `DataContext.subscribe*`; cleanup happens in
///   `deinit` (the bag drops every token).
public protocol A2UIPlatformComponent: AnyObject {
    /// Binds the view to a resolved component node.
    /// - Parameters:
    ///   - node: The resolved node (type, properties, already-expanded children).
    ///   - surface: The owning surface; `DataContext` is derived from it.
    ///   - factory: Builds child views — used by container components only.
    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory)
}

#endif
