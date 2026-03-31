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

// MARK: - A2UIAppKit
//
// AppKit renderer target for A2UI v0.9.
// Platform: macOS only.
//
// Architecture
// ------------
//
//   A2UISwiftCore          ← shared protocol layer (DataModel, DataContext, schema)
//        ↑
//   A2UIAppKit             ← this target (AppKit views, cells, view controllers)
//
// This target does NOT depend on A2UISwiftUI or A2UIUIKit.  AppKit is an
// independent consumer of A2UISwiftCore, parallel to the UIKit renderer.
//
// DataContext usage is identical to A2UIUIKit — the only difference is the
// view framework (`NSView` / `NSTextField.stringValue` vs `UIView` / `UITextField.text`).
//
// How to implement an AppKit component
// --------------------------------------
// 1. Create an NSView / NSTableCellView subclass.
// 2. Conform to A2UIAppKitComponent (optional but recommended).
// 3. In configure(node:dataContext:), call DataContext typed subscribe helpers
//    and store tokens in a DataSubscriptions bag.
// 4. Call subscriptions.unsubscribeAll() when the view is reused or deallocated.
//
// Example — TextField view
// -------------------------
//
//   import AppKit
//   import A2UISwiftCore
//   import A2UIAppKit
//
//   final class A2UITextFieldView: NSView, A2UIAppKitComponent {
//       let textField = NSTextField()
//       private var subscriptions = DataSubscriptions()
//
//       func configure(node: ComponentNode, dataContext: DataContext) {
//           subscriptions.unsubscribeAll()
//           guard let props = try? node.typedProperties(TextFieldProperties.self) else { return }
//           let ctx = dataContext.nested(node.dataContextPath)
//
//           // Reactive read: label (shown as placeholder)
//           ctx.subscribeString(for: props.label) { [weak self] in
//               self?.textField.placeholderString = $0
//           }.store(in: &subscriptions)
//
//           // Reactive read: value
//           if let value = props.value {
//               ctx.subscribeString(for: value) { [weak self] in
//                   guard self?.textField.currentEditor() == nil else { return }
//                   self?.textField.stringValue = $0
//               }.store(in: &subscriptions)
//           }
//
//           // Write-back via NSTextFieldDelegate.controlTextDidChange
//       }
//
//       deinit {
//           subscriptions.unsubscribeAll()
//       }
//   }

#if canImport(AppKit)
import AppKit
import A2UISwiftCore

// MARK: - A2UIAppKitComponent

/// Protocol for AppKit views that render an A2UI component node.
///
/// Conformance is optional — it exists to document the expected interface
/// and provide a consistent pattern for community-contributed AppKit components.
///
/// Lifecycle contract
/// ------------------
/// - `configure` is called when the view is (re)bound to a node.
///   Always call `subscriptions.unsubscribeAll()` at the top of configure
///   before establishing new subscriptions.
/// - Clean up in `deinit` (plain views) or when the view is recycled.
public protocol A2UIAppKitComponent: AnyObject {
    /// Binds the view to the given component node and data context.
    /// - Parameter node: The component node describing type and properties.
    /// - Parameter dataContext: The surface-scoped data context. Use
    ///   `dataContext.nested(node.dataContextPath)` to scope it to this node.
    func configure(node: ComponentNode, dataContext: DataContext)
}

#endif
