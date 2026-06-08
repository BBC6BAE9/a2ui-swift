import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

/// Static demo page for Rizzcharts custom components (Chart + Map).
struct RizzchartsPage: View {
    @State private var selectedTab = 0
    @State private var chartStore = SurfaceStore()
    @State private var mapStore = SurfaceStore()
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
                    surfaceContent(store: selectedTab == 0 ? chartStore : mapStore)
                }
            }
        }
        .navigationTitle("Rizzcharts")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { loadData() }
    }

    @ViewBuilder
    private func surfaceContent(store: SurfaceStore) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(store.orderedSurfaceIds, id: \.self) { surfaceId in
                if let vm = store.viewModels[surfaceId] {
                    A2UISurfaceView(viewModel: vm, catalog: RizzCustomCatalog(), scrolls: false)
                        .padding()
                }
            }
        }
    }

    private func loadData() {
        loadBundle(filename: "rizzcharts_chart", into: chartStore)
        loadBundle(filename: "rizzcharts_map", into: mapStore)
    }

    private func loadBundle(filename: String, into store: SurfaceStore) {
        do {
            let messages = try DemoMessages.load(filename)
            store.process(messages)
        } catch {
            loadError = "Could not load \(filename).json"
        }
    }
}

#Preview {
    NavigationStack {
        RizzchartsPage()
    }
}
