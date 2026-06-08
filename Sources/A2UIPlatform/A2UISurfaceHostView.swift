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

#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Top-level container that hosts a rendered A2UI surface and keeps it live.
///
/// The imperative counterpart of SwiftUI's `SurfaceViewModel`: builds the node
/// tree, mounts the root view, and **rebuilds automatically** when structure
/// changes (components created/deleted) or when a template's bound data changes.
/// Leaf data bindings update in place via each component's own subscriptions —
/// only template-derived structure needs a rebuild.
public final class A2UISurfaceHostView: PlatformView {

    private let factory = ComponentFactory()
    private var rootView: PlatformView?

    /// Host-app extension point for rendering `custom` component types.
    public var customCatalog: A2UICustomComponentCatalog? {
        get { factory.customCatalog }
        set { factory.customCatalog = newValue }
    }

    private var surface: SurfaceModel?
    private var rootComponentId: String?
    private var currentRoot: ComponentNode?
    private var structureSubscriptions: [Subscription] = []
    private var templateSubscriptions = DataSubscriptions()

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        structureSubscriptions.forEach { $0.unsubscribe() }
        templateSubscriptions.unsubscribeAll()
    }

    /// Mounts the surface rooted at `rootComponentId` and starts tracking it.
    /// Returns the root rendered view, or `nil` if the id cannot be resolved.
    @discardableResult
    public func render(surface: SurfaceModel, rootComponentId: String) -> PlatformView? {
        self.surface = surface
        self.rootComponentId = rootComponentId
        A2UIPlatformStyle.applyTheme(surface.theme?.dictionaryValue?.compactMapValues { $0.stringValue })

        structureSubscriptions.forEach { $0.unsubscribe() }
        structureSubscriptions = [
            surface.componentsModel.onCreated.subscribe { [weak self] _ in self?.rebuild() },
            surface.componentsModel.onDeleted.subscribe { [weak self] _ in self?.rebuild() },
        ]
        return rebuild()
    }

    @discardableResult
    private func rebuild() -> PlatformView? {
        guard let surface, let rootComponentId else { return nil }
        templateSubscriptions.unsubscribeAll()

        let result = ComponentTreeBuilder.buildTree(surface: surface, rootComponentId: rootComponentId)

        // Carry stateful view state (Tabs selection, Modal open) across rebuilds.
        if let old = currentRoot, let new = result.root {
            ComponentTreeBuilder.migrateUIState(from: old, to: new)
        }
        currentRoot = result.root

        rootView?.removeFromSuperview()
        guard let node = result.root else { rootView = nil; return nil }
        let view = factory.makeView(for: node, surface: surface)
        a2ui_pinEdges(of: view)
        rootView = view

        // Watch the data paths that drive template expansion; a change there
        // means rows were added/removed, so the tree must be rebuilt.
        let dc = DataContext(surface: surface, path: "/")
        for path in result.templatePaths {
            dc.subscribeDynamicValue(.dataBinding(path: path)) { [weak self] _ in
                self?.rebuild()
            }.store(in: &templateSubscriptions)
        }
        return view
    }
}

#endif
