import SwiftUI
import Charts
import A2UI
import os

private let logger = Logger(subsystem: "com.a2ui.demo", category: "RizzchartChart")

/// Swift Charts implementation of the Rizzcharts doughnut/pie chart with drill-down.
struct RizzchartChartView: View {
    let node: ComponentNode
    let viewModel: SurfaceViewModel

    @State private var selectedCategory: String?

    private var chartType: String {
        node.payload.properties["type"]?.stringValue ?? "doughnut"
    }

    private var title: String {
        if let titleProp = node.payload.properties["title"] {
            if let path = titleProp.dictionaryValue?["path"]?.stringValue {
                let fullPath = viewModel.resolvePath(
                    viewModel.normalizePath(path), context: node.dataContextPath
                )
                let result = viewModel.getDataByPath(fullPath)?.stringValue ?? ""
                logger.info("title: path=\(path) fullPath=\(fullPath) result=\(result)")
                return result
            }
            return titleProp.stringValue ?? ""
        }
        return ""
    }

    private var chartItems: [ChartItem] {
        logger.info("properties keys: \(node.payload.properties.keys.sorted().joined(separator: ", "))")
        guard let dataProp = node.payload.properties["chartData"] else {
            logger.warning("chartData property not found")
            return []
        }
        logger.info("chartData raw: \(String(describing: dataProp))")
        guard let path = dataProp.dictionaryValue?["path"]?.stringValue else {
            logger.warning("chartData has no path key, dictionaryValue=\(String(describing: dataProp.dictionaryValue))")
            return []
        }
        let normalized = viewModel.normalizePath(path)
        let fullPath = viewModel.resolvePath(normalized, context: node.dataContextPath)
        logger.info("chartData: path=\(path) normalized=\(normalized) fullPath=\(fullPath)")

        let data = viewModel.getDataByPath(fullPath)
        logger.info("chartData resolved: \(String(describing: data))")

        guard let data, case .array(let items) = data else {
            // Try logging the whole data model
            let keys = viewModel.dataStoreKeys
            logger.info("data model keys: \(keys.joined(separator: ", "))")
            return []
        }
        return items.compactMap { item -> ChartItem? in
            guard case .dictionary(let dict) = item,
                  let label = dict["label"]?.stringValue,
                  let value = dict["value"]?.numberValue else { return nil }
            var drillDown: [ChartItem] = []
            if case .array(let subs) = dict["drillDown"] {
                drillDown = subs.compactMap { sub -> ChartItem? in
                    guard case .dictionary(let d) = sub,
                          let l = d["label"]?.stringValue,
                          let v = d["value"]?.numberValue else { return nil }
                    return ChartItem(label: l, value: v, drillDown: [])
                }
            }
            return ChartItem(label: label, value: value, drillDown: drillDown)
        }
    }

    private var displayItems: [ChartItem] {
        if let cat = selectedCategory,
           let parent = chartItems.first(where: { $0.label == cat }),
           !parent.drillDown.isEmpty {
            return parent.drillDown
        }
        return chartItems
    }

    private var displayTitle: String {
        if let cat = selectedCategory { return cat }
        return title
    }

    private var total: Double {
        displayItems.reduce(0) { $0 + $1.value }
    }

    private static let palette: [Color] = [
        .blue, .green, .orange, .purple, .red,
        .cyan, .pink, .yellow, .mint, .indigo
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                if selectedCategory != nil {
                    Button {
                        withAnimation { selectedCategory = nil }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.subheadline)
                    }
                }
                Spacer()
                Text(displayTitle)
                    .font(.headline)
                Spacer()
                // Balance the back button
                if selectedCategory != nil {
                    Color.clear.frame(width: 50, height: 1)
                }
            }

            Chart(displayItems) { item in
                SectorMark(
                    angle: .value("Value", item.value),
                    innerRadius: .ratio(chartType == "doughnut" ? 0.5 : 0),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Category", item.label))
                .annotation(position: .overlay) {
                    let pct = total > 0 ? item.value / total * 100 : 0
                    if pct >= 5 {
                        Text("\(Int(pct.rounded()))%")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
            .chartForegroundStyleScale(domain: displayItems.map(\.label), range: colorRange)
            .frame(height: 260)

            // Legend buttons
            legendView
        }
        .padding()
    }

    private var colorRange: [Color] {
        displayItems.indices.map { Self.palette[$0 % Self.palette.count] }
    }

    @ViewBuilder
    private var legendView: some View {
        let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(displayItems) { item in
                let idx = displayItems.firstIndex(where: { $0.id == item.id }) ?? 0
                let color = Self.palette[idx % Self.palette.count]
                let hasDrill = !item.drillDown.isEmpty && selectedCategory == nil

                Button {
                    if hasDrill {
                        withAnimation { selectedCategory = item.label }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(color)
                            .frame(width: 10, height: 10)
                        Text(item.label)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "%.0f", item.value))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if hasDrill {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Data Model

struct ChartItem: Identifiable {
    let label: String
    let value: Double
    let drillDown: [ChartItem]
    var id: String { label }
}
