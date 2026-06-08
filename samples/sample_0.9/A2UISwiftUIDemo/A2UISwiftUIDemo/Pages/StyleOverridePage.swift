import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

struct StyleOverridePage: View {
    @State private var useCustom = true
    @State private var showingInspector = false

    private static let json = """
    [
      { "version": "v0.9", "createSurface": { "surfaceId": "main", "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json" } },
      { "version": "v0.9", "updateComponents": { "surfaceId": "main", "components": [
        { "id": "root", "component": "Card", "child": "col" },
        { "id": "col", "component": "Column", "children": ["title", "body", "row_icon", "btn"], "align": "stretch" },
        { "id": "title", "component": "Text", "text": "Welcome", "variant": "h2" },
        { "id": "body", "component": "Text", "text": "Toggle the switch to see how a custom A2UIStyle restyles A2UI components without changing the server JSON." },
        { "id": "row_icon", "component": "Row", "children": ["ic", "ic_label"], "align": "center" },
        { "id": "ic", "component": "Icon", "name": "home" },
        { "id": "ic_label", "component": "Text", "text": "Home", "variant": "caption" },
        { "id": "btn_t", "component": "Text", "text": "Primary Button" },
        { "id": "btn", "component": "Button", "child": "btn_t", "variant": "primary", "action": { "event": { "name": "tap" } } }
      ] } }
    ]
    """

    /// A custom style built in code. Mirrors what the `.a2uiTextStyle` /
    /// `.a2uiButtonStyle` / `.a2uiCardStyle` / `.a2uiIcon` view modifiers produce.
    private static let customStyle = A2UIStyle(
        primaryColor: .indigo,
        textStyles: [
            "h2": .init(font: .system(.title, design: .rounded), weight: .black, color: .indigo),
            "caption": .init(color: .purple)
        ],
        iconOverrides: ["home": "house.fill"],
        cardStyle: .init(cornerRadius: 20, shadowRadius: 8, backgroundColor: .indigo.opacity(0.05)),
        buttonStyles: ["primary": .init(backgroundColor: .indigo, cornerRadius: 20)]
    )

    private static func makeViewModel() -> SurfaceViewModel {
        let messages = (try? DemoMessages.decode(Data(json.utf8))) ?? []
        return makeSurfaceViewModel(from: messages)
    }

    @State private var viewModel = makeViewModel()

    var body: some View {
        List {
            Section {
                Toggle("Custom Style", isOn: $useCustom.animation())
            }

            Section("Preview") {
                A2UISurfaceView(viewModel: viewModel, scrolls: false)
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
                Text("Shows how to restyle built-in A2UI components with a custom A2UIStyle (text variants, button variant, card, icon overrides) — no server-side JSON changes needed.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .inspectorColumnWidth(min: 260, ideal: 300, max: 400)
        }
#endif
        .onAppear { applyStyle() }
        .onChange(of: useCustom) { applyStyle() }
    }

    private func applyStyle() {
        viewModel.a2uiStyle = useCustom ? Self.customStyle : A2UIStyle()
    }
}
