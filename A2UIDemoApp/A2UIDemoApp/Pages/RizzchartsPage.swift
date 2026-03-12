import SwiftUI
import A2UI

/// Static demo page for Rizzcharts custom components (Chart + Map).
struct RizzchartsPage: View {
    @State private var selectedTab = 0
    @State private var chartManager = SurfaceManager()
    @State private var mapManager = SurfaceManager()
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedTab) {
                Text("Chart").tag(0)
                Text("Map").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            if let error = loadError {
                ContentUnavailableView(
                    "Load Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                ScrollView {
                    if selectedTab == 0 {
                        surfaceContent(manager: chartManager)
                    } else {
                        surfaceContent(manager: mapManager)
                    }
                }
            }
        }
        .navigationTitle("Rizzcharts")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            loadData()
        }
    }

    @ViewBuilder
    private func surfaceContent(manager: SurfaceManager) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(manager.orderedSurfaceIds, id: \.self) { surfaceId in
                if let vm = manager.surfaces[surfaceId],
                   let rootNode = vm.componentTree {
                    A2UIComponentView(node: rootNode, viewModel: vm)
                        .tint(vm.a2uiStyle.primaryColor)
                        .environment(\.a2uiStyle, vm.a2uiStyle)
                        .environment(\.a2uiCustomComponentRenderer, rizzchartsRenderer)
                        .padding()
                }
            }
        }
    }

    private func loadData() {
        loadBundle(filename: "rizzcharts_chart", into: chartManager)
        loadBundle(filename: "rizzcharts_map", into: mapManager)
    }

    private func loadBundle(filename: String, into manager: SurfaceManager) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            loadError = "Could not load \(filename).json"
            return
        }

        let decoder = JSONDecoder()
        for line in text.components(separatedBy: "\n")
        where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            if let lineData = line.data(using: .utf8),
               let msg = try? decoder.decode(ServerToClientMessage.self, from: lineData) {
                try? manager.processMessage(msg)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RizzchartsPage()
    }
}
