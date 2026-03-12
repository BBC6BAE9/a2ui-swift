import SwiftUI
import A2UI
import os

private let rendererLogger = Logger(subsystem: "com.a2ui.demo", category: "RizzchartsRenderer")

/// Rizzcharts custom component renderer.
/// Dispatches Canvas, Chart, and GoogleMap to their SwiftUI implementations.
func rizzchartsRenderer(
    typeName: String,
    node: ComponentNode,
    children: [ComponentNode],
    viewModel: SurfaceViewModel
) -> AnyView? {
    rendererLogger.info("rizzchartsRenderer called: typeName=\(typeName) nodeId=\(node.id) children=\(children.count)")
    switch typeName {
    case "Canvas":
        // Canvas is a simple container — render children in a VStack
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                ForEach(children) { child in
                    A2UIComponentView(node: child, viewModel: viewModel)
                }
            }
        )
    case "Chart":
        return AnyView(
            RizzchartChartView(node: node, viewModel: viewModel)
        )
    case "GoogleMap":
        return AnyView(
            RizzchartMapView(node: node, viewModel: viewModel)
        )
    default:
        return nil
    }
}
