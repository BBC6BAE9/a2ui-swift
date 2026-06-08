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

/// Spec v0.9 `Slider` — numeric value in [min, max] with two-way binding.
/// Per-platform control: `UISlider` (Float) vs `NSSlider` (Double).
final class A2UISlider: PlatformView, A2UIPlatformComponent {

    private var subscriptions = DataSubscriptions()
    private var valueBindingPath: String?
    private var dataContext: DataContext?
    private var checks: [CheckRule]?
    private let titleLabel = A2UILabelView.makeFieldLabel()
    private let errorLabel = A2UILabelView.makeError()

    #if canImport(UIKit) && !os(watchOS)
    private let slider = UISlider()
    #elseif canImport(AppKit)
    private let slider = NSSlider()
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
        guard let props = try? node.typedProperties(SliderProperties.self) else { return }
        let ctx = DataContext(surface: surface, path: node.dataContextPath)
        dataContext = ctx
        valueBindingPath = a2ui_bindingPath(props.value)
        checks = props.checks
        a2ui_applyAccessibility(node.accessibility, dataContext: ctx)

        if let label = props.label {
            titleLabel.isHidden = false
            titleLabel.text = ctx.resolve(label)
            ctx.subscribeString(for: label) { [weak self] in self?.titleLabel.text = $0 }
                .store(in: &subscriptions)
        } else {
            titleLabel.isHidden = true
        }

        setRange(min: props.min ?? 0, max: props.max)
        setValue(ctx.resolve(props.value) ?? props.min ?? 0)
        ctx.subscribeDouble(for: props.value) { [weak self] in
            self?.setValue($0 ?? 0); self?.updateValidation()
        }.store(in: &subscriptions)
        updateValidation()
    }

    deinit { subscriptions.unsubscribeAll() }

    private func updateValidation() {
        let message = dataContext?.firstFailingCheckMessage(checks)
        errorLabel.text = message ?? ""
        errorLabel.isHidden = (message == nil)
    }

    @objc private func valueChanged() {
        guard let path = valueBindingPath else { return }
        try? dataContext?.set(path, value: .number(currentValue))
        updateValidation()
    }

    // MARK: - Platform shell

    private func setupControl() {
        let column = a2ui_makeStack(vertical: true, spacing: 4)
        column.addArrangedSubview(titleLabel)
        column.addArrangedSubview(slider)
        column.addArrangedSubview(errorLabel)
        errorLabel.isHidden = true
        a2ui_pinEdges(of: column)
        #if canImport(UIKit) && !os(watchOS)
        slider.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        #elseif canImport(AppKit)
        slider.target = self
        slider.action = #selector(valueChanged)
        #endif
    }

    #if canImport(UIKit) && !os(watchOS)
    private var currentValue: Double { Double(slider.value) }
    private func setValue(_ v: Double) { slider.value = Float(v) }
    private func setRange(min: Double, max: Double) {
        slider.minimumValue = Float(min); slider.maximumValue = Float(max)
    }
    #elseif canImport(AppKit)
    private var currentValue: Double { slider.doubleValue }
    private func setValue(_ v: Double) { slider.doubleValue = v }
    private func setRange(min: Double, max: Double) {
        slider.minValue = min; slider.maxValue = max
    }
    #endif
}

#endif
