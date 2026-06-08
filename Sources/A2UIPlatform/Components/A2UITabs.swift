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

/// Spec v0.9 `Tabs` — a segmented selector over child panels.
/// Children (one per tab) are pre-resolved into `node.children`; titles come
/// from `props.tabs`. Per-platform: the segmented control.
final class A2UITabs: PlatformView, A2UIPlatformComponent {

    private let container = PlatformView()
    private var panels: [PlatformView] = []
    private var selectedIndex = 0

    #if canImport(UIKit) && !os(watchOS)
    private let segmented = UISegmentedControl()
    #elseif canImport(AppKit)
    private let segmented = NSSegmentedControl()
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }

    func configure(node: ComponentNode, surface: SurfaceModel, factory: ComponentFactory) {
        guard let props = try? node.typedProperties(TabsProperties.self) else { return }
        let ctx = DataContext(surface: surface, path: node.dataContextPath)

        panels = node.children.map { factory.makeView(for: $0, surface: surface) }
        setTitles(props.tabs.map { ctx.resolve($0.title) })
        select(0)
    }

    /// Test hook + selection entry point.
    func select(_ index: Int) {
        guard index >= 0, index < panels.count else { return }
        selectedIndex = index
        container.subviews.forEach { $0.removeFromSuperview() }
        container.a2ui_pinEdges(of: panels[index])
        syncSegmentSelection(index)
    }

    var currentIndex: Int { selectedIndex }

    // MARK: - Platform shell

    private func setupLayout() {
        let stack = a2ui_makeStack(vertical: true, spacing: 8)
        stack.addArrangedSubview(segmented)
        stack.addArrangedSubview(container)
        a2ui_pinEdges(of: stack)
        #if canImport(UIKit) && !os(watchOS)
        segmented.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        #elseif canImport(AppKit)
        segmented.target = self
        segmented.action = #selector(segmentChanged)
        #endif
    }

    @objc private func segmentChanged() {
        #if canImport(UIKit) && !os(watchOS)
        select(segmented.selectedSegmentIndex)
        #elseif canImport(AppKit)
        select(segmented.selectedSegment)
        #endif
    }

    private func setTitles(_ titles: [String]) {
        #if canImport(UIKit) && !os(watchOS)
        segmented.removeAllSegments()
        for (i, title) in titles.enumerated() {
            segmented.insertSegment(withTitle: title, at: i, animated: false)
        }
        #elseif canImport(AppKit)
        segmented.segmentCount = titles.count
        for (i, title) in titles.enumerated() { segmented.setLabel(title, forSegment: i) }
        #endif
    }

    private func syncSegmentSelection(_ index: Int) {
        #if canImport(UIKit) && !os(watchOS)
        segmented.selectedSegmentIndex = index
        #elseif canImport(AppKit)
        segmented.selectedSegment = index
        #endif
    }
}

#endif
