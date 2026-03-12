import SwiftUI
import A2UI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Contact Card") {
                    SampleView(filename: "contact_card")
                        .navigationTitle("Contact Card")
                }
                NavigationLink("Recipe") {
                    SampleView(filename: "recipe")
                        .navigationTitle("Recipe")
                }
            }
            .navigationTitle("A2UI Watch")
        }
    }
}

struct SampleView: View {
    let filename: String

    @State private var manager = SurfaceManager()
    @State private var loaded = false
    @State private var errorText: String?

    var body: some View {
        Group {
            if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .font(.caption)
            } else if !loaded {
                ProgressView()
                    .task { loadJSON() }
            } else {
                ScrollView {
                    A2UIRendererView(manager: manager)
                }
            }
        }
    }

    private func loadJSON() {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            errorText = "\(filename).json not found"
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let messages = try JSONDecoder().decode([ServerToClientMessage].self, from: data)
            try manager.processMessages(messages)
            loaded = true
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
