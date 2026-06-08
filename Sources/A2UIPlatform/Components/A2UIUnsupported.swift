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

/// Inert placeholder for component types not yet implemented in this slice.
/// Keeps a partial tree laying out instead of crashing on an unknown type.
final class A2UIUnsupported: PlatformView, A2UIPlatformComponent {

    let componentType: ComponentType

    init(type: ComponentType) {
        self.componentType = type
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        self.componentType = .custom("unknown")
        super.init(coder: coder)
    }

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        // No-op: nothing to render yet for this type.
    }
}

#endif
