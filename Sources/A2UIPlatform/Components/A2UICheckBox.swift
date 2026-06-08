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

/// Spec v0.9 `CheckBox` — boolean toggle with two-way binding.
/// Per-platform control: `UISwitch` (+ a label) vs `NSButton` of type `.switch`.
final class A2UICheckBox: PlatformView, A2UIPlatformComponent {

    private var subscriptions = DataSubscriptions()
    private var valueBindingPath: String?
    private var dataContext: DataContext?

    #if canImport(UIKit) && !os(watchOS)
    private let toggle = UISwitch()
    private let label = UILabel()
    #elseif canImport(AppKit)
    private let toggle = NSButton()
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupControl()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupControl()
    }

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        subscriptions.unsubscribeAll()
        guard let props = try? node.typedProperties(CheckBoxProperties.self) else { return }
        let ctx = DataContext(surface: surface, path: node.dataContextPath)
        dataContext = ctx
        valueBindingPath = a2ui_bindingPath(props.value)

        setLabel(ctx.resolve(props.label))
        ctx.subscribeString(for: props.label) { [weak self] in self?.setLabel($0) }
            .store(in: &subscriptions)

        setOn(ctx.resolve(props.value))
        ctx.subscribeBool(for: props.value) { [weak self] in self?.setOn($0) }
            .store(in: &subscriptions)
    }

    deinit { subscriptions.unsubscribeAll() }

    @objc private func toggled() {
        guard let path = valueBindingPath else { return }
        try? dataContext?.set(path, value: .bool(isOn))
    }

    // MARK: - Platform shell

    #if canImport(UIKit) && !os(watchOS)
    private func setupControl() {
        let stack = a2ui_makeStack(vertical: false, spacing: 8)
        stack.addArrangedSubview(toggle)
        stack.addArrangedSubview(label)
        a2ui_pinEdges(of: stack)
        toggle.addTarget(self, action: #selector(toggled), for: .valueChanged)
    }
    private var isOn: Bool { toggle.isOn }
    private func setOn(_ v: Bool) { toggle.setOn(v, animated: false) }
    private func setLabel(_ s: String) { label.text = s }
    #elseif canImport(AppKit)
    private func setupControl() {
        toggle.setButtonType(.switch)
        toggle.target = self
        toggle.action = #selector(toggled)
        a2ui_pinEdges(of: toggle)
    }
    private var isOn: Bool { toggle.state == .on }
    private func setOn(_ v: Bool) { toggle.state = v ? .on : .off }
    private func setLabel(_ s: String) { toggle.title = s }
    #endif
}

#endif
