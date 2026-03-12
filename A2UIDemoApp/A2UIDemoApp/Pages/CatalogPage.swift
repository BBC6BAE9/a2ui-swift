import SwiftUI
import A2UI

// MARK: - Catalog Page

struct CatalogPage: View {
    @State private var showingInspector = false
    @State private var inspectedEntry: CatalogEntry?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(componentCatalog) { entry in
                    catalogCard(entry)
                }
            }
            .padding()
        }
        .navigationTitle("Component Gallery")
        #if !os(visionOS) && !os(tvOS)
        .navigationSubtitle("Building blocks and examples for Agent Driven UIs")
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
        .sheet(item: $inspectedEntry) { entry in
            NavigationStack {
                CatalogDetailPage(entry: entry)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { inspectedEntry = nil }
                        }
                    }
            }
        }
#if !os(visionOS) && !os(tvOS)
        .inspector(isPresented: $showingInspector) {
            ScrollView {
                Text("A gallery of all A2UI standard components rendered by the SwiftUI renderer. Each card is live-rendered from static JSON. Tap the detail button to inspect source JSON.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .inspectorColumnWidth(min: 260, ideal: 300, max: 400)
        }
#endif
    }

    @ViewBuilder
    private func catalogCard(_ entry: CatalogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.name)
                    .font(.title3)
                    .fontWeight(.medium)
                Spacer()
                Button {
                    inspectedEntry = entry
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            VStack {
                if let vm = entry.viewModel, let root = vm.componentTree {
                    A2UIComponentView(node: root, viewModel: vm)
                        // TODO: rizzchartsRenderer disabled — causes infinite re-render during scroll.
                        // .environment(\.a2uiCustomComponentRenderer, rizzchartsRenderer)
                        .padding()
                } else {
                    Text("Failed to parse")
                        .foregroundStyle(.red)
                        .padding()
                }
            }
            #if os(iOS)
            .background(Color(.secondarySystemGroupedBackground))
            #elseif os(macOS)
            .background(Color(.windowBackgroundColor))
            #elseif os(visionOS)
            .background(.regularMaterial)
            #else
            .background(.ultraThinMaterial)
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
            #if os(macOS)
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Detail Page

struct CatalogDetailPage: View {
    let entry: CatalogEntry
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedTab) {
                Text("Rendered").tag(0)
                Text("JSON").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            if selectedTab == 0 {
                renderedView
            } else {
                jsonView
            }
        }
        .navigationTitle(entry.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var renderedView: some View {
        ScrollView {
            if let vm = entry.viewModel, let root = vm.componentTree {
                A2UIComponentView(node: root, viewModel: vm)
                    // TODO: rizzchartsRenderer disabled — causes infinite re-render during scroll.
                    // .environment(\.a2uiCustomComponentRenderer, rizzchartsRenderer)
                    .padding()
            } else {
                ContentUnavailableView(
                    "Parse Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Failed to parse the JSON input.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var jsonView: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(entry.prettyJSON)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .background(Color(.systemGray6))
        #elseif os(macOS)
        .background(Color(.textBackgroundColor))
        #else
        .background(.ultraThinMaterial)
        #endif
    }
}

// MARK: - Data

struct CatalogEntry: Identifiable {
    let name: String
    let icon: String
    let jsonl: String
    let viewModel: SurfaceViewModel?

    var id: String { name }

    var prettyJSON: String {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return jsonl
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { line -> String in
                guard let data = line.data(using: .utf8),
                      let obj = try? decoder.decode(AnyCodableJSON.self, from: data),
                      let pretty = try? encoder.encode(obj),
                      let str = String(data: pretty, encoding: .utf8)
                else { return line }
                return str
            }
            .joined(separator: "\n\n")
    }

    init(name: String, icon: String = "square", jsonl: String) {
        self.name = name
        self.icon = icon
        self.jsonl = jsonl

        let vm = SurfaceViewModel()
        let decoder = JSONDecoder()
        var ok = true
        for line in jsonl.components(separatedBy: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            if let data = line.data(using: .utf8),
               let msg = try? decoder.decode(ServerToClientMessage.self, from: data) {
                try? vm.processMessage(msg)
            } else {
                ok = false
            }
        }
        self.viewModel = ok ? vm : nil
    }
}

struct AnyCodableJSON: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodableJSON].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodableJSON].self) {
            value = array.map { $0.value }
        } else if let s = try? container.decode(String.self) {
            value = s
        } else if let n = try? container.decode(Double.self) {
            value = n
        } else if let b = try? container.decode(Bool.self) {
            value = b
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodableJSON(value: $0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodableJSON(value: $0) })
        case let s as String:
            try container.encode(s)
        case let n as Double:
            try container.encode(n)
        case let b as Bool:
            try container.encode(b)
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encode("\(value)")
        }
    }

    init(value: Any) { self.value = value }
}

// MARK: - Catalog Data

let componentCatalog: [CatalogEntry] = [

    CatalogEntry(name: "Text", icon: "textformat", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["h1","h2","h3","h4","h5","body","cap"]}}}},{"id":"h1","component":{"Text":{"text":{"literalString":"Heading 1 — h1"},"usageHint":"h1"}}},{"id":"h2","component":{"Text":{"text":{"literalString":"Heading 2 — h2"},"usageHint":"h2"}}},{"id":"h3","component":{"Text":{"text":{"literalString":"Heading 3 — h3"},"usageHint":"h3"}}},{"id":"h4","component":{"Text":{"text":{"literalString":"Heading 4 — h4"},"usageHint":"h4"}}},{"id":"h5","component":{"Text":{"text":{"literalString":"Heading 5 — h5"},"usageHint":"h5"}}},{"id":"body","component":{"Text":{"text":{"literalString":"Body text — default"}}}},{"id":"cap","component":{"Text":{"text":{"literalString":"Caption text — caption"},"usageHint":"caption"}}}]}}
    """),

    CatalogEntry(name: "Image", icon: "photo", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["sec_variants","row_small","header_img","sec_fit","fit_contain","fit_cover","fit_fill","fit_none","fit_scaledown"]}}}},{"id":"sec_variants","component":{"Text":{"text":{"literalString":"Variants"},"usageHint":"h4"}}},{"id":"row_small","component":{"Row":{"children":{"explicitList":["avatar","icon","small"]},"align":"center"}}},{"id":"avatar","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/64/200/200"},"usageHint":"avatar"}}},{"id":"icon","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/76/200/200"},"usageHint":"icon"}}},{"id":"small","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/82/200/200"},"usageHint":"smallFeature"}}},{"id":"header_img","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/10/800/400"},"usageHint":"header","fit":"cover"}}},{"id":"sec_fit","component":{"Text":{"text":{"literalString":"Fit modes (same 600×300 image in 300×150 frame)"},"usageHint":"h4"}}},{"id":"fit_contain","component":{"Column":{"children":{"explicitList":["fc_label","fc_img"]}}}},{"id":"fc_label","component":{"Text":{"text":{"literalString":"contain — fit entirely, may letterbox"},"usageHint":"caption"}}},{"id":"fc_img","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/11/600/300"},"usageHint":"mediumFeature","fit":"contain"}}},{"id":"fit_cover","component":{"Column":{"children":{"explicitList":["fv_label","fv_img"]}}}},{"id":"fv_label","component":{"Text":{"text":{"literalString":"cover — fill frame, may crop"},"usageHint":"caption"}}},{"id":"fv_img","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/11/600/300"},"usageHint":"mediumFeature","fit":"cover"}}},{"id":"fit_fill","component":{"Column":{"children":{"explicitList":["ff_label","ff_img"]}}}},{"id":"ff_label","component":{"Text":{"text":{"literalString":"fill — stretch to frame, ignores aspect ratio"},"usageHint":"caption"}}},{"id":"ff_img","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/11/600/300"},"usageHint":"mediumFeature","fit":"fill"}}},{"id":"fit_none","component":{"Column":{"children":{"explicitList":["fn_label","fn_img"]}}}},{"id":"fn_label","component":{"Text":{"text":{"literalString":"none — original size, no scaling"},"usageHint":"caption"}}},{"id":"fn_img","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/11/600/300"},"usageHint":"mediumFeature","fit":"none"}}},{"id":"fit_scaledown","component":{"Column":{"children":{"explicitList":["fs_label","fs_img"]}}}},{"id":"fs_label","component":{"Text":{"text":{"literalString":"scaleDown — like contain, but never enlarges"},"usageHint":"caption"}}},{"id":"fs_img","component":{"Image":{"url":{"literalString":"https://picsum.photos/id/11/600/300"},"usageHint":"mediumFeature","fit":"scaleDown"}}}]}}
    """),

    CatalogEntry(name: "Icon", icon: "star.circle", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["i1","i2","i3"]},"distribution":"spaceEvenly","align":"center"}}},{"id":"i1","component":{"Icon":{"name":{"literalString":"star"}}}},{"id":"i2","component":{"Icon":{"name":{"literalString":"home"}}}},{"id":"i3","component":{"Icon":{"name":{"literalString":"settings"}}}}]}}
    """),

    CatalogEntry(name: "Divider", icon: "minus", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["sec_h","t1","dh","t2","sec_v","row_v"]}}}},{"id":"sec_h","component":{"Text":{"text":{"literalString":"Horizontal (default)"},"usageHint":"h4"}}},{"id":"t1","component":{"Text":{"text":{"literalString":"Content above"}}}},{"id":"dh","component":{"Divider":{}}},{"id":"t2","component":{"Text":{"text":{"literalString":"Content below"}}}},{"id":"sec_v","component":{"Text":{"text":{"literalString":"Vertical (axis)"},"usageHint":"h4"}}},{"id":"row_v","component":{"Row":{"children":{"explicitList":["left","dv","right"]},"align":"stretch"}}},{"id":"left","component":{"Text":{"text":{"literalString":"Left"}}}},{"id":"dv","component":{"Divider":{"axis":"vertical"}}},{"id":"right","component":{"Text":{"text":{"literalString":"Right"}}}}]}}
    """),

    CatalogEntry(name: "Row", icon: "arrow.left.and.right", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["lbl_default","row_default","lbl_center","row_center","lbl_between","row_between","lbl_evenly","row_evenly","lbl_end","row_end","lbl_align","row_align"]}}}},{"id":"lbl_default","component":{"Text":{"text":{"literalString":"distribution: start (default)"},"usageHint":"caption"}}},{"id":"row_default","component":{"Row":{"children":{"explicitList":["d1","d2","d3"]}}}},{"id":"d1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"d2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"d3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"lbl_center","component":{"Text":{"text":{"literalString":"distribution: center"},"usageHint":"caption"}}},{"id":"row_center","component":{"Row":{"children":{"explicitList":["c1","c2","c3"]},"distribution":"center"}}},{"id":"c1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"c2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"c3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"lbl_between","component":{"Text":{"text":{"literalString":"distribution: spaceBetween"},"usageHint":"caption"}}},{"id":"row_between","component":{"Row":{"children":{"explicitList":["b1","b2","b3"]},"distribution":"spaceBetween"}}},{"id":"b1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"b2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"b3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"lbl_evenly","component":{"Text":{"text":{"literalString":"distribution: spaceEvenly"},"usageHint":"caption"}}},{"id":"row_evenly","component":{"Row":{"children":{"explicitList":["e1","e2","e3"]},"distribution":"spaceEvenly"}}},{"id":"e1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"e2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"e3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"lbl_end","component":{"Text":{"text":{"literalString":"distribution: end"},"usageHint":"caption"}}},{"id":"row_end","component":{"Row":{"children":{"explicitList":["n1","n2","n3"]},"distribution":"end"}}},{"id":"n1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"n2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"n3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"lbl_align","component":{"Text":{"text":{"literalString":"align: center (mixed height)"},"usageHint":"caption"}}},{"id":"row_align","component":{"Row":{"children":{"explicitList":["a1","a2"]},"align":"center"}}},{"id":"a1","component":{"Text":{"text":{"literalString":"Small"}}}},{"id":"a2","component":{"Text":{"text":{"literalString":"Big Title"},"usageHint":"h2"}}}]}}
    """),

    CatalogEntry(name: "Column", icon: "arrow.up.and.down", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["lbl_justify","row_justify","lbl_align","col_align"]}}}},{"id":"lbl_justify","component":{"Text":{"text":{"literalString":"justify: start / center / end"},"usageHint":"caption"}}},{"id":"row_justify","component":{"Row":{"children":{"explicitList":["col_start","dv1","col_center","dv2","col_end"]}}}},{"id":"col_start","component":{"Column":{"children":{"explicitList":["ls","s1","s2","s3","s4","s5","s6"]},"justify":"start"}},"weight":1},{"id":"ls","component":{"Text":{"text":{"literalString":"start"},"usageHint":"caption"}}},{"id":"s1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"s2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"s3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"s4","component":{"Text":{"text":{"literalString":"D"}}}},{"id":"s5","component":{"Text":{"text":{"literalString":"E"}}}},{"id":"s6","component":{"Text":{"text":{"literalString":"F"}}}},{"id":"dv1","component":{"Divider":{"axis":"vertical"}}},{"id":"col_center","component":{"Column":{"children":{"explicitList":["lc","c1","c2","c3"]},"justify":"center"}},"weight":1},{"id":"lc","component":{"Text":{"text":{"literalString":"center"},"usageHint":"caption"}}},{"id":"c1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"c2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"c3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"dv2","component":{"Divider":{"axis":"vertical"}}},{"id":"col_end","component":{"Column":{"children":{"explicitList":["le","e1","e2","e3"]},"justify":"end"}},"weight":1},{"id":"le","component":{"Text":{"text":{"literalString":"end"},"usageHint":"caption"}}},{"id":"e1","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"e2","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"e3","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"lbl_align","component":{"Text":{"text":{"literalString":"alignment: center"},"usageHint":"caption"}}},{"id":"col_align","component":{"Column":{"children":{"explicitList":["a1","a2"]},"alignment":"center"}}},{"id":"a1","component":{"Text":{"text":{"literalString":"Short"}}}},{"id":"a2","component":{"Text":{"text":{"literalString":"A longer text to show cross-axis centering"}}}}]}}
    """),

    CatalogEntry(name: "Card", icon: "rectangle.on.rectangle", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Card":{"child":"content"}}},{"id":"content","component":{"Column":{"children":{"explicitList":["title","desc"]}}}},{"id":"title","component":{"Text":{"text":{"literalString":"Card Title"},"usageHint":"h4"}}},{"id":"desc","component":{"Text":{"text":{"literalString":"This is a card with some content inside."}}}}]}}
    """),

    CatalogEntry(name: "Button", icon: "rectangle.and.hand.point.up.left", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["b1","b2"]}}}},{"id":"b1","component":{"Button":{"child":"bt1","primary":true,"action":{"name":"tap1"}}}},{"id":"bt1","component":{"Text":{"text":{"literalString":"Primary"}}}},{"id":"b2","component":{"Button":{"child":"bt2","action":{"name":"tap2"}}}},{"id":"bt2","component":{"Text":{"text":{"literalString":"Default"}}}}]}}
    """),

    CatalogEntry(name: "TextField", icon: "character.cursor.ibeam", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["tf_short","tf_num","tf_pw","tf_long","tf_regex"]}}}},{"id":"tf_short","component":{"TextField":{"label":{"literalString":"Name"},"text":{"path":"/name"}}}},{"id":"tf_num","component":{"TextField":{"label":{"literalString":"Age"},"text":{"path":"/age"},"textFieldType":"number"}}},{"id":"tf_pw","component":{"TextField":{"label":{"literalString":"Password"},"text":{"path":"/pw"},"textFieldType":"obscured"}}},{"id":"tf_long","component":{"TextField":{"label":{"literalString":"Bio"},"text":{"path":"/bio"},"textFieldType":"longText"}}},{"id":"tf_regex","component":{"TextField":{"label":{"literalString":"Email"},"text":{"path":"/email"},"validationRegexp":"^[\\\\w.+-]+@[\\\\w-]+\\\\.[a-zA-Z]{2,}$"}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"name","valueString":"Jane Doe"},{"key":"age","valueString":"28"},{"key":"pw","valueString":"secret"},{"key":"bio","valueString":"Hello world"},{"key":"email","valueString":"jane@example.com"}]}}
    """),

    CatalogEntry(name: "CheckBox", icon: "checkmark.square", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["cb1","cb2"]}}}},{"id":"cb1","component":{"CheckBox":{"label":{"literalString":"Accept Terms"},"value":{"path":"/terms"}}}},{"id":"cb2","component":{"CheckBox":{"label":{"literalString":"Subscribe to Newsletter"},"value":{"path":"/newsletter"}}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"terms","valueBool":true},{"key":"newsletter","valueBool":false}]}}
    """),

    CatalogEntry(name: "Slider", icon: "slider.horizontal.3", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["s"]}}}},{"id":"s","component":{"Slider":{"label":{"literalString":"Volume"},"value":{"path":"/volume"},"minValue":0,"maxValue":100}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"volume","valueNumber":50}]}}
    """),

    CatalogEntry(name: "List (Vertical)", icon: "list.bullet", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"List":{"children":{"explicitList":["l1","l2","l3"]},"direction":"vertical"}}},{"id":"l1","component":{"Text":{"text":{"literalString":"Item 1"}}}},{"id":"l2","component":{"Text":{"text":{"literalString":"Item 2"}}}},{"id":"l3","component":{"Text":{"text":{"literalString":"Item 3"}}}}]}}
    """),

    CatalogEntry(name: "List (Horizontal)", icon: "list.bullet.indent", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"List":{"children":{"explicitList":["h1","h2","h3","h4","h5"]},"direction":"horizontal"}}},{"id":"h1","component":{"Card":{"child":"ht1"}}},{"id":"ht1","component":{"Text":{"text":{"literalString":"Card A"}}}},{"id":"h2","component":{"Card":{"child":"ht2"}}},{"id":"ht2","component":{"Text":{"text":{"literalString":"Card B"}}}},{"id":"h3","component":{"Card":{"child":"ht3"}}},{"id":"ht3","component":{"Text":{"text":{"literalString":"Card C"}}}},{"id":"h4","component":{"Card":{"child":"ht4"}}},{"id":"ht4","component":{"Text":{"text":{"literalString":"Card D"}}}},{"id":"h5","component":{"Card":{"child":"ht5"}}},{"id":"ht5","component":{"Text":{"text":{"literalString":"Card E"}}}}]}}
    """),

    CatalogEntry(name: "DateTimeInput", icon: "calendar", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["dt1","dt2","dt3"]}}}},{"id":"dt1","component":{"DateTimeInput":{"label":{"literalString":"Date only"},"value":{"path":"/date"},"enableDate":true,"enableTime":false}}},{"id":"dt2","component":{"DateTimeInput":{"label":{"literalString":"Time only"},"value":{"path":"/time"},"enableDate":false,"enableTime":true}}},{"id":"dt3","component":{"DateTimeInput":{"label":{"literalString":"Date & Time"},"value":{"path":"/datetime"}}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"date","valueString":"2025-12-09"},{"key":"time","valueString":"14:30:00"},{"key":"datetime","valueString":"2025-12-09T14:30:00"}]}}
    """),

    // --- MultipleChoice: 6 variants covering all combinations ---

    CatalogEntry(name: "Single — Radio (long labels)", icon: "circle.inset.filled", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Show scroll bars"},"selections":{"path":"/singleRadio"},"maxAllowedSelections":1,"options":[{"label":{"literalString":"Automatically based on mouse or trackpad"},"value":"auto"},{"label":{"literalString":"When scrolling"},"value":"scroll"},{"label":{"literalString":"Always"},"value":"always"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"singleRadio","valueMap":[{"key":"0","valueString":"auto"}]}]}}
    """),

    CatalogEntry(name: "Single — Menu (short labels)", icon: "chevron.up.chevron.down", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Icon size"},"selections":{"path":"/singleMenu"},"maxAllowedSelections":1,"options":[{"label":{"literalString":"Small"},"value":"small"},{"label":{"literalString":"Medium"},"value":"medium"},{"label":{"literalString":"Large"},"value":"large"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"singleMenu","valueMap":[{"key":"0","valueString":"medium"}]}]}}
    """),

    CatalogEntry(name: "Single Select — Chips", icon: "tag", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Pick one size"},"selections":{"path":"/singleChips"},"variant":"chips","maxAllowedSelections":1,"options":[{"label":{"literalString":"Small"},"value":"S"},{"label":{"literalString":"Medium"},"value":"M"},{"label":{"literalString":"Large"},"value":"L"},{"label":{"literalString":"XL"},"value":"XL"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"singleChips","valueMap":[{"key":"0","valueString":"M"}]}]}}
    """),

    CatalogEntry(name: "Multi Select — Checkbox", icon: "checklist", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Select toppings"},"selections":{"path":"/multiCB"},"options":[{"label":{"literalString":"Cheese"},"value":"cheese"},{"label":{"literalString":"Pepperoni"},"value":"pepperoni"},{"label":{"literalString":"Mushrooms"},"value":"mushrooms"},{"label":{"literalString":"Olives"},"value":"olives"},{"label":{"literalString":"Onions"},"value":"onions"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"multiCB","valueMap":[{"key":"0","valueString":"cheese"},{"key":"1","valueString":"mushrooms"}]}]}}
    """),

    CatalogEntry(name: "Multi Select — Chips", icon: "tag.fill", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Select tags"},"selections":{"path":"/multiChips"},"variant":"chips","options":[{"label":{"literalString":"Work"},"value":"work"},{"label":{"literalString":"Home"},"value":"home"},{"label":{"literalString":"Urgent"},"value":"urgent"},{"label":{"literalString":"Later"},"value":"later"},{"label":{"literalString":"Fun"},"value":"fun"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"multiChips","valueMap":[{"key":"0","valueString":"work"},{"key":"1","valueString":"urgent"}]}]}}
    """),

    CatalogEntry(name: "Filterable — Checkbox", icon: "line.3.horizontal.decrease.circle", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Select countries"},"selections":{"path":"/filterCB"},"filterable":true,"options":[{"label":{"literalString":"United States"},"value":"US"},{"label":{"literalString":"Canada"},"value":"CA"},{"label":{"literalString":"United Kingdom"},"value":"UK"},{"label":{"literalString":"Australia"},"value":"AU"},{"label":{"literalString":"Germany"},"value":"DE"},{"label":{"literalString":"France"},"value":"FR"},{"label":{"literalString":"Japan"},"value":"JP"},{"label":{"literalString":"South Korea"},"value":"KR"},{"label":{"literalString":"Brazil"},"value":"BR"},{"label":{"literalString":"India"},"value":"IN"},{"label":{"literalString":"Mexico"},"value":"MX"},{"label":{"literalString":"Italy"},"value":"IT"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"filterCB","valueMap":[{"key":"0","valueString":"US"}]}]}}
    """),

    CatalogEntry(name: "Filterable — Chips", icon: "line.3.horizontal.decrease.circle.fill", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"MultipleChoice":{"description":{"literalString":"Select languages"},"selections":{"path":"/filterChips"},"variant":"chips","filterable":true,"options":[{"label":{"literalString":"Swift"},"value":"swift"},{"label":{"literalString":"Python"},"value":"python"},{"label":{"literalString":"Rust"},"value":"rust"},{"label":{"literalString":"Go"},"value":"go"},{"label":{"literalString":"TypeScript"},"value":"typescript"},{"label":{"literalString":"Kotlin"},"value":"kotlin"},{"label":{"literalString":"Java"},"value":"java"},{"label":{"literalString":"C++"},"value":"cpp"},{"label":{"literalString":"Ruby"},"value":"ruby"},{"label":{"literalString":"Haskell"},"value":"haskell"},{"label":{"literalString":"Scala"},"value":"scala"},{"label":{"literalString":"Elixir"},"value":"elixir"},{"label":{"literalString":"Dart"},"value":"dart"},{"label":{"literalString":"Zig"},"value":"zig"}]}}}]}}
    {"dataModelUpdate":{"surfaceId":"main","path":"/","contents":[{"key":"filterChips","valueMap":[{"key":"0","valueString":"swift"},{"key":"1","valueString":"rust"}]}]}}
    """),

    CatalogEntry(name: "Tabs", icon: "rectangle.split.3x1", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Tabs":{"tabItems":[{"title":{"literalString":"View One"},"child":"t1"},{"title":{"literalString":"View Two"},"child":"t2"}]}}},{"id":"t1","component":{"Text":{"text":{"literalString":"First tab content"}}}},{"id":"t2","component":{"Text":{"text":{"literalString":"Second tab content"}}}}]}}
    """),

    CatalogEntry(name: "Modal", icon: "rectangle.portrait.on.rectangle.portrait", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Modal":{"entryPointChild":"mbtn","contentChild":"mcol"}}},{"id":"mbtn","component":{"Button":{"child":"mbtn-text","action":{"name":"open_modal"}}}},{"id":"mbtn-text","component":{"Text":{"text":{"literalString":"Open Modal"}}}},{"id":"mcol","component":{"Column":{"children":{"explicitList":["mh","mp","mclose"]}}}},{"id":"mh","component":{"Text":{"text":{"literalString":"Modal Title"},"usageHint":"h3"}}},{"id":"mp","component":{"Text":{"text":{"literalString":"This is a modal dialog with rich content. Tap the X button or swipe down to dismiss."}}}},{"id":"mclose","component":{"Button":{"child":"mclose-text","action":{"name":"dismiss_modal"}}}},{"id":"mclose-text","component":{"Text":{"text":{"literalString":"Got it"}}}}]}}
    """),

    CatalogEntry(name: "Video", icon: "play.rectangle", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"Video":{"url":{"literalString":"https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"}}}}]}}
    """),

    CatalogEntry(name: "AudioPlayer", icon: "waveform", jsonl: """
    {"beginRendering":{"surfaceId":"main","root":"root"}}
    {"surfaceUpdate":{"surfaceId":"main","components":[{"id":"root","component":{"AudioPlayer":{"url":{"literalString":"https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"},"description":{"literalString":"Sample Audio Track"}}}}]}}
    """),

]

#Preview {
    NavigationStack {
        CatalogPage()
    }
}
