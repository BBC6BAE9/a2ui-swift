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

// MARK: - A2UICustomComponentCatalog
//
// Host-app extension point for rendering `custom` component types — the
// imperative counterpart of SwiftUI's `CustomComponentCatalog`. Register one on
// `A2UISurfaceHostView`; the factory consults it for `ComponentType.custom`.

public protocol A2UICustomComponentCatalog: AnyObject {
    /// Returns a view for a custom component type, or `nil` to fall through to
    /// the built-in (inert placeholder) handling. The returned view is
    /// `configure`d by the factory just like a built-in component.
    func makeView(
        typeName: String,
        node: ComponentNode,
        surface: SurfaceModel
    ) -> (PlatformView & A2UIPlatformComponent)?
}

#endif
