import SwiftUI
import A2UI

struct ActionDemoPage: View {
    let filename: String
    let title: String
    let subtitle: String
    let info: String
    
    @State private var viewModel = SurfaceViewModel()
    @State private var loaded = false
    @State private var errorText: String?
    @State private var lastAction: ResolvedAction?
    @State private var showingInspector = false
    
    var body: some View {
        List {
            if let errorText {
                Section { Text(errorText).foregroundStyle(.red) }
            } else if !loaded {
                ProgressView().task { loadJSON() }
            } else {
                if let root = viewModel.componentTree {
                    Section("Form") {
                        A2UIComponentView(node: root, viewModel: viewModel)
                    }
                }
                
                if let action = lastAction {
                    Section("Resolved Action") {
                        LabeledContent("event", value: action.name)
                        
                        ForEach(action.context.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            LabeledContent(key, value: displayValue(value))
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
#if !os(visionOS) && !os(tvOS)
        .navigationSubtitle(subtitle)
#endif
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
                Text(info)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .inspectorColumnWidth(min: 260, ideal: 300, max: 400)
        }
#endif
        .environment(\.a2uiStyle, viewModel.a2uiStyle)
        .environment(\.a2uiActionHandler) { action in
            lastAction = action
        }
    }
    
    private func displayValue(_ value: AnyCodable) -> String {
        switch value {
        case .string(let s): return s
        case .number(let n): return "\(n)"
        case .bool(let b): return "\(b)"
        case .null: return "null"
        default: return "\(value)"
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
            for msg in messages { try viewModel.processMessage(msg) }
            loaded = true
        } catch {
            errorText = error.localizedDescription
        }
    }
}
