import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

struct ActionDemoPage: View {
    let filename: String
    let title: String
    let subtitle: String
    let info: String

    @State private var viewModel: SurfaceViewModel?
    @State private var errorText: String?
    @State private var lastAction: ResolvedAction?
    @State private var showingInspector = false

    var body: some View {
        List {
            if let errorText {
                Section { Text(errorText).foregroundStyle(.red) }
            } else if let viewModel {
                Section("Form") {
                    A2UISurfaceView(viewModel: viewModel, scrolls: false) { action in
                        lastAction = action
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
            } else {
                ProgressView().task { loadJSON() }
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
        do {
            let messages = try DemoMessages.load(filename)
            viewModel = makeSurfaceViewModel(from: messages)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
