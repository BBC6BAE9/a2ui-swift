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

/// Spec v0.9 `ChoicePicker` — single- or multi-select over a set of options.
///
/// Baseline: a vertical list of tappable option rows; selection writes the value
/// list back to the bound path. The list binding is resolved once (there is no
/// `subscribeStringList` helper yet — reactive list reads are a later refinement).
final class A2UIChoicePicker: PlatformView, A2UIPlatformComponent {

    private let stack = a2ui_makeStack(vertical: true, spacing: 4)
    private var dataContext: DataContext?
    private var valueBindingPath: String?
    private var multiSelect = false
    private var chips = false
    private var options: [(label: String, value: String)] = []
    private var selected: Set<String> = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        a2ui_pinEdges(of: stack)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        a2ui_pinEdges(of: stack)
    }

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        guard let props = try? node.typedProperties(ChoicePickerProperties.self) else { return }
        let ctx = DataContext(surface: surface, path: node.dataContextPath)
        dataContext = ctx
        valueBindingPath = a2ui_bindingPath(props.value)
        multiSelect = (props.variant ?? .mutuallyExclusive) == .multipleSelection
        chips = (props.displayStyle ?? .checkbox) == .chips
        a2ui_applyAccessibility(node.accessibility, dataContext: ctx)
        options = props.options.map { (ctx.resolve($0.label), $0.value) }
        selected = Set(props.value.map { ctx.resolve($0) } ?? [])
        rebuildRows()
    }

    /// Test hook + row tap entry point.
    func toggle(_ value: String) {
        if multiSelect {
            if selected.contains(value) { selected.remove(value) } else { selected.insert(value) }
        } else {
            selected = [value]
        }
        writeBack()
        rebuildRows()
    }

    var selectedValues: Set<String> { selected }

    private func writeBack() {
        guard let path = valueBindingPath else { return }
        try? dataContext?.set(path, value: .array(selected.sorted().map { .string($0) }))
    }

    private func rebuildRows() {
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        for option in options {
            let row = A2UIChoiceRow(
                label: option.label,
                isSelected: selected.contains(option.value),
                chip: chips
            ) { [weak self] in self?.toggle(option.value) }
            stack.addArrangedSubview(row)
        }
    }
}

/// A single tappable option row showing a checkmark when selected.
private final class A2UIChoiceRow: PlatformView {
    private let action: () -> Void

    init(label: String, isSelected: Bool, chip: Bool, action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)

        let text = chip ? label : (isSelected ? "\u{2713} " : "\u{2007} ") + label
        #if canImport(UIKit) && !os(watchOS)
        let field = UILabel()
        field.text = text
        if chip { field.textColor = isSelected ? .white : .label }
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        #elseif canImport(AppKit)
        let field = NSTextField(labelWithString: text)
        if chip { field.textColor = isSelected ? .white : .labelColor }
        addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(tapped)))
        #endif
        a2ui_pinEdges(of: field, inset: chip ? 8 : 4)

        if chip {
            // Capsule: filled tint when selected, outlined otherwise.
            a2ui_setCornerRadius(14)
            if isSelected {
                a2ui_setBackground(A2UIPlatformStyle.tint)
            } else {
                a2ui_setBackground(.clear)
                setBorder()
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    private func setBorder() {
        #if canImport(UIKit) && !os(watchOS)
        layer.borderWidth = 1; layer.borderColor = A2UIPlatformStyle.tint.cgColor
        #elseif canImport(AppKit)
        wantsLayer = true; layer?.borderWidth = 1; layer?.borderColor = A2UIPlatformStyle.tint.cgColor
        #endif
    }

    @objc private func tapped() { action() }
}

#endif
