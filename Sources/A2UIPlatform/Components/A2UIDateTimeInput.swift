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
import Foundation
import A2UISwiftCore

#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Spec v0.9 `DateTimeInput` — date/time picker with two-way binding.
/// Value is an ISO-8601 string. Baseline: date and/or time mode from flags;
/// min/max bounds are a later refinement.
final class A2UIDateTimeInput: PlatformView, A2UIPlatformComponent {

    private var subscriptions = DataSubscriptions()
    private var valueBindingPath: String?
    private var dataContext: DataContext?
    private let iso = ISO8601DateFormatter()

    #if canImport(UIKit) && !os(watchOS)
    private let picker = UIDatePicker()
    #elseif canImport(AppKit)
    private let picker = NSDatePicker()
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPicker()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPicker()
    }

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        subscriptions.unsubscribeAll()
        guard let props = try? node.typedProperties(DateTimeInputProperties.self) else { return }
        let ctx = DataContext(surface: surface, path: node.dataContextPath)
        dataContext = ctx
        valueBindingPath = a2ui_bindingPath(props.value)
        setMode(date: props.enableDate ?? true, time: props.enableTime ?? false)
        a2ui_applyAccessibility(node.accessibility, dataContext: ctx)
        setBounds(min: props.min.flatMap { iso.date(from: ctx.resolve($0)) },
                  max: props.max.flatMap { iso.date(from: ctx.resolve($0)) })

        setDate(iso.date(from: ctx.resolve(props.value)) ?? Date())
        ctx.subscribeString(for: props.value) { [weak self] in
            guard let self, let d = self.iso.date(from: $0) else { return }
            self.setDate(d)
        }.store(in: &subscriptions)
    }

    deinit { subscriptions.unsubscribeAll() }

    @objc private func dateChanged() {
        guard let path = valueBindingPath else { return }
        try? dataContext?.set(path, value: .string(iso.string(from: currentDate)))
    }

    // MARK: - Platform shell

    private func setupPicker() {
        a2ui_pinEdges(of: picker)
        #if canImport(UIKit) && !os(watchOS)
        picker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        #elseif canImport(AppKit)
        picker.target = self
        picker.action = #selector(dateChanged)
        #endif
    }

    #if canImport(UIKit) && !os(watchOS)
    private var currentDate: Date { picker.date }
    private func setDate(_ d: Date) { picker.date = d }
    private func setBounds(min: Date?, max: Date?) {
        picker.minimumDate = min; picker.maximumDate = max
    }
    private func setMode(date: Bool, time: Bool) {
        picker.datePickerMode = date && time ? .dateAndTime : (time ? .time : .date)
    }
    #elseif canImport(AppKit)
    private var currentDate: Date { picker.dateValue }
    private func setDate(_ d: Date) { picker.dateValue = d }
    private func setBounds(min: Date?, max: Date?) {
        if let min { picker.minDate = min }
        if let max { picker.maxDate = max }
    }
    private func setMode(date: Bool, time: Bool) {
        var elements = NSDatePicker.ElementFlags()
        if date { elements.insert(.yearMonthDay) }
        if time { elements.insert(.hourMinuteSecond) }
        picker.datePickerElements = elements.isEmpty ? .yearMonthDay : elements
    }
    #endif
}

#endif
