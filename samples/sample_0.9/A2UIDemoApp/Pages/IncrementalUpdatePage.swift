import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

struct IncrementalUpdatePage: View {
    @State private var viewModel = IncrementalUpdatePage.makeViewModel()
    @State private var allMessages: [A2uiMessage] = []
    @State private var currentStep = 0
    @State private var errorText: String?
    @State private var showingInspector = false

    private let stepDescriptions = [
        "Step 1: createSurface — create surface",
        "Step 2: ADD — title + Message A",
        "Step 3: ADD — Message B, C",
        "Step 4: REPLACE — edit Message A",
        "Step 5: DELETE — remove Message B"
    ]

    private var totalSteps: Int { allMessages.count }

    private static func makeViewModel() -> SurfaceViewModel {
        SurfaceViewModel(surface: SurfaceModel(id: "main", catalog: demoCatalog))
    }

    var body: some View {
        List {
            Section {
                Text(currentStep > 0 && currentStep <= stepDescriptions.count
                     ? stepDescriptions[currentStep - 1]
                     : "Tap Next Step to begin")
                .foregroundStyle(.secondary)
            } header: {
                Text("Progress: \(currentStep) / \(totalSteps)")
            }

            if viewModel.componentTree != nil {
                Section("Rendered") {
                    A2UISurfaceView(viewModel: viewModel, scrolls: false)
                }
            }

            if let errorText {
                Section { Text(errorText).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Incremental Update")
#if !os(visionOS) && !os(tvOS)
        .navigationSubtitle("Step-by-step component add, replace & delete")
#endif
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Next Step") { applyNextStep() }
                    .disabled(currentStep >= totalSteps)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Reset") { resetAll() }
            }
#if !os(visionOS) && !os(tvOS)
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingInspector.toggle()
                } label: {
                    Label("About", systemImage: "info.circle")
                }
            }
#endif
        }
#if !os(visionOS) && !os(tvOS)
        .inspector(isPresented: $showingInspector) {
            ScrollView {
                Text("Demonstrates incremental UI updates via the v0.9 updateComponents message. Each step sends a single message that adds, replaces, or removes components from the surface without a full re-render.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .inspectorColumnWidth(min: 260, ideal: 300, max: 400)
        }
#endif
        .task { loadMessages() }
    }

    private func loadMessages() {
        do {
            allMessages = try DemoMessages.load("incremental_update")
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func applyNextStep() {
        guard currentStep < totalSteps else { return }
        do {
            try viewModel.processMessage(allMessages[currentStep])
            currentStep += 1
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func resetAll() {
        viewModel = Self.makeViewModel()
        currentStep = 0
    }
}
