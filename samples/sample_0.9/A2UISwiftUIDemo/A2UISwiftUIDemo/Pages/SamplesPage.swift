import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

// MARK: - Data

enum SampleDemo: String, CaseIterable, Identifiable {
    case contactForm = "Contact Form"
    case contactCard = "Contact Card"
    case recipe = "Recipe"
    case incrementalUpdate = "Incremental Update"
    case actionContext = "Action Context"
    case formatFunctions = "Format Functions"

    var id: String { rawValue }

    var filename: String {
        switch self {
        case .contactForm: return "contact_form"
        case .contactCard: return "contact_card"
        case .recipe: return "recipe"
        case .incrementalUpdate: return "incremental_update"
        case .actionContext: return "action_context"
        case .formatFunctions: return "format_functions"
        }
    }

    var icon: String {
        switch self {
        case .contactForm: return "person.crop.rectangle"
        case .contactCard: return "person.text.rectangle"
        case .recipe: return "fork.knife"
        case .incrementalUpdate: return "arrow.triangle.2.circlepath"
        case .actionContext: return "arrow.up.message"
        case .formatFunctions: return "calendar.badge.clock"
        }
    }
}

// MARK: - Detail Page

struct SampleDetailPage: View {
    let demo: SampleDemo

    @State private var store = SurfaceStore()
    @State private var loaded = false
    @State private var errorText: String?

    var body: some View {
        Group {
            if let errorText {
                ContentUnavailableView(
                    "Load Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorText)
                )
            } else if !loaded {
                ProgressView()
                    .task { loadJSON() }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.orderedSurfaceIds, id: \.self) { surfaceId in
                            if let vm = store.viewModels[surfaceId] {
                                A2UISurfaceView(viewModel: vm, scrolls: false)
                                    .padding()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(demo.rawValue)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func loadJSON() {
        do {
            let messages = try DemoMessages.load(demo.filename)
            store.process(messages)
            loaded = true
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        SampleDetailPage(demo: .contactForm)
    }
}
