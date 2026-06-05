import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

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

    @State private var viewModel: SurfaceViewModel?
    @State private var errorText: String?

    var body: some View {
        Group {
            if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .font(.caption)
            } else if let viewModel {
                A2UISurfaceView(viewModel: viewModel)
            } else {
                ProgressView()
                    .task { loadJSON() }
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
            let messages = try JSONDecoder().decode([A2uiMessage].self, from: data)
            let surfaceId = messages.compactMap { message -> String? in
                if case .createSurface(let p) = message { return p.surfaceId }
                return nil
            }.first ?? "main"
            let surface = SurfaceModel(id: surfaceId, catalog: basicCatalog)
            let vm = SurfaceViewModel(surface: surface)
            vm.processMessages(messages)
            viewModel = vm
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
