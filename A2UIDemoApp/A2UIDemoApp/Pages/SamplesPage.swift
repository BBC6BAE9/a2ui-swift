import SwiftUI
import A2UI

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

    @State private var manager = SurfaceManager()
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
                A2UIRendererView(manager: manager)
            }
        }
        .navigationTitle(demo.rawValue)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func loadJSON() {
        guard let url = Bundle.main.url(
            forResource: demo.filename, withExtension: "json"
        ) else {
            errorText = "\(demo.filename).json not found in bundle"
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
    NavigationStack {
        SampleDetailPage(demo: .contactForm)
    }
}
