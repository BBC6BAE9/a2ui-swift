import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

struct CustomComponentPage: View {
    private static let json = """
    [
      { "version": "v0.9", "createSurface": { "surfaceId": "main", "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json", "sendDataModel": true } },
      { "version": "v0.9", "updateComponents": { "surfaceId": "main", "components": [
        { "id": "root", "component": "Column", "children": ["name", "bio", "slider"], "align": "stretch" },
        { "id": "name", "component": "Text", "text": { "path": "/name" }, "variant": "h3" },
        { "id": "bio", "component": "Text", "text": { "path": "/bio" } },
        { "id": "slider", "component": "Slider", "label": "Rating", "value": { "path": "/rating" }, "min": 0, "max": 5 }
      ] } },
      { "version": "v0.9", "updateDataModel": { "surfaceId": "main", "value": { "name": "Alice Johnson", "bio": "iOS developer & SwiftUI enthusiast.", "rating": 3 } } }
    ]
    """

    private static func makeViewModel() -> SurfaceViewModel {
        let messages = (try? DemoMessages.decode(Data(json.utf8))) ?? []
        return makeSurfaceViewModel(from: messages)
    }

    @State private var viewModel = makeViewModel()
    @State private var showingInspector = false

    var body: some View {
        List {
            Section("A2UI Components") {
                A2UISurfaceView(viewModel: viewModel, scrolls: false)
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
    }
}

/// A fully native SwiftUI view that reads and writes the A2UI data model.
/// Drag the slider above or tap a star — both update the same `/rating` path.
private struct StarRatingView: View {
    let viewModel: SurfaceViewModel
    let path: String

    private var rating: Int {
        let dc = viewModel.makeDataContext()
        if let value = dc.resolve(DynamicNumber.dataBinding(path: path)) {
            return max(0, min(5, Int(value.rounded())))
        }
        return 0
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundStyle(star <= rating ? .yellow : .gray.opacity(0.4))
                    .onTapGesture {
                        try? viewModel.makeDataContext().set(path, value: .number(Double(star)))
                    }
            }
        }
        .font(.title2)
        .accessibilityElement()
        .accessibilityLabel("Rating: \(rating) of 5")
    }
}
