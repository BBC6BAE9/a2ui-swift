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
///
/// Matches SwiftUI: ≤5 tabs render as a full-width segmented control; >5 tabs
/// render as a horizontally-scrolling row of bordered buttons. Selection is
/// persisted on `node.uiState` so it survives rebuilds.
final class A2UITabs: PlatformView, A2UIPlatformComponent {

    private let barHost = PlatformView()
    private let container = PlatformView()
    private var panels: [PlatformView] = []
    private var titles: [String] = []
    private var selectedIndex = 0
    private var uiState: TabsUIState?

    #if canImport(UIKit) && !os(watchOS)
    private let segmented = UISegmentedControl()
    private var tabButtons: [UIButton] = []
    #elseif canImport(AppKit)
    private let segmented = NSSegmentedControl()
    private var tabButtons: [NSButton] = []
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
        uiState = node.uiState as? TabsUIState

        panels = node.children.map { factory.makeView(for: $0, surface: surface) }
        titles = props.tabs.map { ctx.resolve($0.title) }
        a2ui_applyAccessibility(node.accessibility, dataContext: ctx)
        buildBar()
        select(uiState?.selectedIndex ?? 0)
    }

    /// Test hook + selection entry point.
    func select(_ index: Int) {
        guard index >= 0, index < panels.count else { return }
        selectedIndex = index
        uiState?.selectedIndex = index
        container.subviews.forEach { $0.removeFromSuperview() }
        container.a2ui_pinEdges(of: panels[index])
        syncSelectionHighlight(index)
    }

    var currentIndex: Int { selectedIndex }

    // MARK: - Layout

    private func setupLayout() {
        let stack = a2ui_makeStack(vertical: true, spacing: 8)
        stack.addArrangedSubview(barHost)
        stack.addArrangedSubview(container)
        a2ui_pinEdges(of: stack)
    }

    private func buildBar() {
        barHost.subviews.forEach { $0.removeFromSuperview() }
        tabButtons = []
        if titles.count <= 5 {
            buildSegmentedBar()   // full-width
        } else {
            buildScrollableButtonBar()
        }
    }

    private func syncSelectionHighlight(_ index: Int) {
        if titles.count <= 5 {
            syncSegmentSelection(index)
        } else {
            highlightButton(index)
        }
    }

    // MARK: - Segmented bar (≤5, full width)

    private func buildSegmentedBar() {
        #if canImport(UIKit) && !os(watchOS)
        segmented.removeAllSegments()
        segmented.apportionsSegmentWidthsByContent = false // equal, full-width
        for (i, title) in titles.enumerated() {
            segmented.insertSegment(withTitle: title, at: i, animated: false)
        }
        segmented.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        barHost.a2ui_pinEdges(of: segmented) // fills the row width
        #elseif canImport(AppKit)
        segmented.segmentCount = titles.count
        segmented.segmentDistribution = .fillEqually
        for (i, title) in titles.enumerated() { segmented.setLabel(title, forSegment: i) }
        segmented.target = self
        segmented.action = #selector(segmentChanged)
        barHost.a2ui_pinEdges(of: segmented)
        #endif
    }

    @objc private func segmentChanged() {
        #if canImport(UIKit) && !os(watchOS)
        select(segmented.selectedSegmentIndex)
        #elseif canImport(AppKit)
        select(segmented.selectedSegment)
        #endif
    }

    private func syncSegmentSelection(_ index: Int) {
        #if canImport(UIKit) && !os(watchOS)
        segmented.selectedSegmentIndex = index
        #elseif canImport(AppKit)
        segmented.selectedSegment = index
        #endif
    }

    // MARK: - Scrollable button bar (>5)

    private func buildScrollableButtonBar() {
        let row = a2ui_makeStack(vertical: false, spacing: 8)
        for (i, title) in titles.enumerated() {
            let button = makeTabButton(title: title, index: i)
            tabButtons.append(button)
            row.addArrangedSubview(button)
        }
        #if canImport(UIKit) && !os(watchOS)
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
        scroll.heightAnchor.constraint(equalToConstant: 34).isActive = true
        barHost.a2ui_pinEdges(of: scroll)
        #elseif canImport(AppKit)
        barHost.a2ui_pinEdges(of: row) // AppKit: no horizontal scroll for the slice
        #endif
    }

    #if canImport(UIKit) && !os(watchOS)
    private func makeTabButton(title: String, index: Int) -> UIButton {
        var config = UIButton.Configuration.bordered()
        config.title = title
        config.cornerStyle = .capsule
        let button = UIButton(configuration: config)
        button.addAction(UIAction { [weak self] _ in self?.select(index) }, for: .touchUpInside)
        return button
    }
    private func highlightButton(_ index: Int) {
        for (i, button) in tabButtons.enumerated() {
            button.configuration?.baseBackgroundColor = (i == index)
                ? A2UIPlatformStyle.tint : .clear
            button.configuration?.baseForegroundColor = (i == index) ? .white : A2UIPlatformStyle.tint
        }
    }
    #elseif canImport(AppKit)
    private func makeTabButton(title: String, index: Int) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(buttonTapped(_:)))
        button.bezelStyle = .rounded
        button.tag = index
        return button
    }
    @objc private func buttonTapped(_ sender: NSButton) { select(sender.tag) }
    private func highlightButton(_ index: Int) {
        for (i, button) in tabButtons.enumerated() {
            button.contentTintColor = (i == index) ? A2UIPlatformStyle.tint : .labelColor
        }
    }
    #endif
}

#endif
