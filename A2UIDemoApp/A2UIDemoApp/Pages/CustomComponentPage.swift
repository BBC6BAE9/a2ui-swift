import SwiftUI
import A2UI

struct CustomComponentPage: View {
    private static let jsonl = """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["name","bio","slider"]}}}},{"id":"name","component":{"Text":{"text":{"path":"/name"},"usageHint":"h3"}}},{"id":"bio","component":{"Text":{"text":{"path":"/bio"}}}},{"id":"slider","component":{"Slider":{"label":{"literalString":"Rating"},"value":{"path":"/rating"},"minValue":0,"maxValue":5}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"name","valueString":"Alice Johnson"},{"key":"bio","valueString":"iOS developer & SwiftUI enthusiast."},{"key":"rating","valueNumber":3}]}}
    """

    private static func makeViewModel() -> SurfaceViewModel {
        let vm = SurfaceViewModel()
        let decoder = JSONDecoder()
        for line in jsonl.components(separatedBy: "\n")
        where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            if let data = line.data(using: .utf8),
               let msg = try? decoder.decode(ServerToClientMessage.self, from: data) {
                try? vm.processMessage(msg)
            }
        }
        return vm
    }

    @State private var viewModel = makeViewModel()
    @State private var showingInspector = false

    var body: some View {
        List {
            if let root = viewModel.componentTree {
                Section("A2UI Components") {
                    A2UIComponentView(node: root, viewModel: viewModel)
                }
            }

            Section("Custom Native Component") {
                StarRatingView(viewModel: viewModel, path: "/rating")
            }
        }
        .navigationTitle("Custom Component")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingInspector.toggle()
                } label: {
                    Label("About", systemImage: "info.circle")
                }
            }
        }
#if !os(visionOS) && !os(tvOS)
        .inspector(isPresented: $showingInspector) {
            ScrollView {
                Text("Demonstrates a custom native SwiftUI view (star rating) that reads and writes the same A2UI data model as standard components. Drag the slider or tap a star — both update the /rating path.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .inspectorColumnWidth(min: 260, ideal: 300, max: 400)

        }
#endif
        .environment(\.a2uiStyle, viewModel.a2uiStyle)
    }
}

/// A fully native SwiftUI view that reads and writes the A2UI data model.
/// Drag the slider above or tap a star — both update the same `/rating` path.
private struct StarRatingView: View {
    var viewModel: SurfaceViewModel
    let path: String

    private var rating: Int {
        if case .number(let n) = viewModel.getDataByPath(path) {
            return max(0, min(5, Int(n.rounded())))
        }
        return 0
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundStyle(star <= rating ? .yellow : .gray.opacity(0.4))
                    .onTapGesture {
                        viewModel.setData(path: path, value: .number(Double(star)))
                    }
            }
        }
        .font(.title2)
        .accessibilityElement()
        .accessibilityLabel("Rating: \(rating) of 5")
    }
}
