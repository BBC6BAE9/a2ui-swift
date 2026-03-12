import SwiftUI
import A2UI

struct StyleOverridePage: View {
    @State private var useCustom = true
    @State private var showingInspector = false

    private static let jsonl = """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Card":{"child":"col"}}},{"id":"col","component":{"Column":{"children":{"explicitList":["title","body","row_icon","btn"]}}}},{"id":"title","component":{"Text":{"text":{"literalString":"Welcome"},"usageHint":"h2"}}},{"id":"body","component":{"Text":{"text":{"literalString":"Toggle the switch to see how style modifiers restyle A2UI components without changing the server JSON."}}}},{"id":"row_icon","component":{"Row":{"children":{"explicitList":["ic","ic_label"]},"align":"center"}}},{"id":"ic","component":{"Icon":{"name":{"literalString":"home"}}}},{"id":"ic_label","component":{"Text":{"text":{"literalString":"Home"},"usageHint":"caption"}}},{"id":"btn","component":{"Button":{"child":"btn_t","primary":true,"action":{"name":"tap"}}}},{"id":"btn_t","component":{"Text":{"text":{"literalString":"Primary Button"}}}}]}}
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

    var body: some View {
        List {
            Section {
                Toggle("Custom Style", isOn: $useCustom.animation())
            }

            if let root = viewModel.componentTree {
                Section("Preview") {
                    if useCustom {
                        A2UIComponentView(node: root, viewModel: viewModel)
                            .a2uiTextStyle(for: .h2, font: .system(.title, design: .rounded), weight: .black, color: .indigo)
                            .a2uiTextStyle(for: .caption, color: .purple)
                            .a2uiButtonStyle(for: .primary, backgroundColor: .indigo, cornerRadius: 20)
                            .a2uiCardStyle(cornerRadius: 20, shadowRadius: 8, backgroundColor: .indigo.opacity(0.05))
                            .a2uiIcon(.home, systemName: "house.fill")
                    } else {
                        A2UIComponentView(node: root, viewModel: viewModel)
                    }
                }
            }
        }
        .navigationTitle("Style Override")
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
                Text("Shows how to restyle built-in A2UI components using SwiftUI view modifiers (.a2uiTextStyle, .a2uiButtonStyle, .a2uiCardStyle, .a2uiIcon) — no server-side JSON changes needed.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .inspectorColumnWidth(min: 260, ideal: 300, max: 400)
        }
#endif
        .environment(\.a2uiStyle, viewModel.a2uiStyle)
    }
    
}
