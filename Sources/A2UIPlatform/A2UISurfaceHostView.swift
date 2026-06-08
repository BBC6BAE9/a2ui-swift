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

/// Top-level container that hosts a rendered A2UI surface.
///
/// Slice scope: given a `SurfaceModel` and a root component id, it builds the
/// node tree (static children only) and mounts the root view. The full version
/// will own the message pipeline and reconcile on data/structure changes — the
/// imperative counterpart of SwiftUI's `SurfaceViewModel`.
public final class A2UISurfaceHostView: PlatformView {

    private let factory = ComponentFactory()
    private var rootView: PlatformView?

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    /// Mounts the component tree rooted at `rootComponentId` from `surface`.
    /// Returns the root rendered view (also retained as a subview), or `nil` if
    /// the id cannot be resolved.
    @discardableResult
    public func render(surface: SurfaceModel, rootComponentId: String) -> PlatformView? {
        rootView?.removeFromSuperview()
        guard let node = ComponentTreeBuilder.build(surface: surface, componentId: rootComponentId) else {
            rootView = nil
            return nil
        }
        let view = factory.makeView(for: node, surface: surface)
        a2ui_pinEdges(of: view)
        rootView = view
        return view
    }
}

#endif
