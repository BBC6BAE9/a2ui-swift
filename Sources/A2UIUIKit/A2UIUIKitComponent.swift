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

// MARK: - A2UIUIKit
//
// UIKit renderer target for A2UI v0.9.
// Platforms: iOS, tvOS, visionOS.
//
// Architecture
// ------------
//
//   A2UISwiftCore          ← shared protocol layer (DataModel, DataContext, schema)
//        ↑
//   A2UIUIKit              ← this target (UIKit views, cells, controllers)
//
// This target does NOT depend on A2UISwiftUI.  UIKit and SwiftUI renderers
// are independent consumers of A2UISwiftCore.
//
// How to implement a UIKit component
// -----------------------------------
// 1. Create a UIView / UITableViewCell subclass.
// 2. Conform to A2UIUIKitComponent (optional but recommended).
// 3. In configure(node:dataContext:), call DataContext typed subscribe helpers
//    and store tokens in a DataSubscriptions bag.
// 4. In prepareForReuse() / deinit, call subscriptions.unsubscribeAll().
//
// Example — TextField cell
// -------------------------
//
//   import UIKit
//   import A2UISwiftCore
//   import A2UIUIKit
//
//   final class A2UITextFieldCell: UITableViewCell, A2UIUIKitComponent {
//       let textField = UITextField()
//       private var subscriptions = DataSubscriptions()
//
//       func configure(node: ComponentNode, dataContext: DataContext) {
//           subscriptions.unsubscribeAll()
//           guard let props = try? node.typedProperties(TextFieldProperties.self) else { return }
//           let ctx = dataContext.nested(node.dataContextPath)
//
//           // Reactive read: label
//           ctx.subscribeString(for: props.label) { [weak self] in
//               self?.textField.placeholder = $0
//           }.store(in: &subscriptions)
//
//           // Reactive read: value
//           if let value = props.value {
//               ctx.subscribeString(for: value) { [weak self] in
//                   if self?.textField.isEditing == false { self?.textField.text = $0 }
//               }.store(in: &subscriptions)
//           }
//
//           // Write-back: value
//           textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
//       }
//
//       @objc private func textChanged() {
//           // dataContext.set("value", value: .string(textField.text ?? ""))
//       }
//
//       override func prepareForReuse() {
//           super.prepareForReuse()
//           subscriptions.unsubscribeAll()
//       }
//   }

#if canImport(UIKit) && !os(watchOS)
import UIKit
import A2UISwiftCore

// MARK: - A2UIUIKitComponent

/// Protocol for UIKit views that render an A2UI component node.
///
/// Conformance is optional — it exists to document the expected interface
/// and provide a consistent pattern for community-contributed UIKit components.
///
/// Lifecycle contract
/// ------------------
/// - `configure` is called when the view is (re)bound to a node.
///   Always call `subscriptions.unsubscribeAll()` at the top of configure
///   before establishing new subscriptions.
/// - Clean up in `prepareForReuse()` (cells) or `deinit` (plain views).
public protocol A2UIUIKitComponent: AnyObject {
    /// Binds the view to the given component node and data context.
    /// - Parameter node: The component node describing type and properties.
    /// - Parameter dataContext: The surface-scoped data context. Use
    ///   `dataContext.nested(node.dataContextPath)` to scope it to this node.
    func configure(node: ComponentNode, dataContext: DataContext)
}

#endif
