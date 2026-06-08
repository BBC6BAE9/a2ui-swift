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

/// Spec v0.9 `TextField` — single-line text input with two-way data binding.
/// Shared: value/label subscription + write-back. Per-platform: the control
/// (`UITextField` target-action vs `NSTextField` delegate).
final class A2UITextField: PlatformView, A2UIPlatformComponent {

    private var subscriptions = DataSubscriptions()
    private var valueBindingPath: String?
    private var dataContext: DataContext?

    #if canImport(UIKit) && !os(watchOS)
    private let field = UITextField()
    #elseif canImport(AppKit)
    private let field = NSTextField()
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupField()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupField()
    }

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        subscriptions.unsubscribeAll()
        guard let props = try? node.typedProperties(TextFieldProperties.self) else { return }
        let ctx = DataContext(surface: surface, path: node.dataContextPath)
        dataContext = ctx
        valueBindingPath = a2ui_bindingPath(props.value)
        applyVariant(props.variant)
        a2ui_applyAccessibility(node.accessibility, dataContext: ctx)

        if let label = props.label {
            setPlaceholder(ctx.resolve(label))
            ctx.subscribeString(for: label) { [weak self] in self?.setPlaceholder($0) }
                .store(in: &subscriptions)
        }
        setText(ctx.resolve(props.value))
        ctx.subscribeString(for: props.value) { [weak self] in
            // Don't clobber the user mid-edit.
            guard let self, !self.isEditing else { return }
            self.setText($0)
        }.store(in: &subscriptions)
    }

    deinit { subscriptions.unsubscribeAll() }

    /// Test hook: simulate a user edit (set text + fire write-back).
    func simulateEditForTesting(_ text: String) {
        setText(text)
        writeBack()
    }

    private func writeBack() {
        guard let path = valueBindingPath else { return }
        try? dataContext?.set(path, value: .string(currentText))
    }

    // MARK: - Platform shell

    private func setupField() {
        a2ui_pinEdges(of: field)
        #if canImport(UIKit) && !os(watchOS)
        field.borderStyle = .roundedRect
        field.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        #elseif canImport(AppKit)
        field.delegate = self
        #endif
    }

    /// Applies the text-field variant (obscured = secure, number = numeric input).
    /// `longText` multi-line is a later refinement; AppKit secure entry needs an
    /// NSSecureTextField swap (deferred).
    private func applyVariant(_ variant: TextFieldVariant?) {
        #if canImport(UIKit) && !os(watchOS)
        switch variant {
        case .obscured: field.isSecureTextEntry = true
        case .number:   field.keyboardType = .decimalPad
        default:        field.isSecureTextEntry = false
        }
        #endif
    }

    #if canImport(UIKit) && !os(watchOS)
    @objc private func editingChanged() { writeBack() }
    private var isEditing: Bool { field.isEditing }
    private var currentText: String { field.text ?? "" }
    private func setText(_ s: String) { field.text = s }
    private func setPlaceholder(_ s: String) { field.placeholder = s }
    #elseif canImport(AppKit)
    private var isEditing: Bool { field.currentEditor() != nil }
    private var currentText: String { field.stringValue }
    private func setText(_ s: String) { field.stringValue = s }
    private func setPlaceholder(_ s: String) { field.placeholderString = s }
    #endif
}

#if canImport(AppKit) && !(canImport(UIKit) && !os(watchOS))
extension A2UITextField: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) { writeBack() }
}
#endif

#endif
