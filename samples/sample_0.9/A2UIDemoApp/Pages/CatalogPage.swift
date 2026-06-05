import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

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
                Text("A gallery of all A2UI standard components rendered by the SwiftUI renderer. Each card is live-rendered from static v0.9 JSON. Tap the detail button to inspect source JSON.")
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
                if let vm = entry.viewModel {
                    A2UISurfaceView(viewModel: vm, scrolls: false)
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

    @ViewBuilder
    private var renderedView: some View {
        if let vm = entry.viewModel {
            A2UISurfaceView(viewModel: vm)
        } else {
            ContentUnavailableView(
                "Parse Error",
                systemImage: "exclamationmark.triangle",
                description: Text("Failed to parse the JSON input.")
            )
        }
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
    let json: String
    let viewModel: SurfaceViewModel?

    var id: String { name }

    var prettyJSON: String { prettyPrintedA2UIJSON(json) }

    init(name: String, icon: String = "square", json: String) {
        self.name = name
        self.icon = icon
        self.json = json
        if let messages = try? DemoMessages.decode(Data(json.utf8)), !messages.isEmpty {
            self.viewModel = makeSurfaceViewModel(from: messages)
        } else {
            self.viewModel = nil
        }
    }
}

// MARK: - Catalog Data

private let CID = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"

let componentCatalog: [CatalogEntry] = [

    CatalogEntry(name: "Text", icon: "textformat", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)"}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Column","children":["h1","h2","h3","h4","h5","body","cap"]},
      {"id":"h1","component":"Text","text":"Heading 1 — h1","variant":"h1"},
      {"id":"h2","component":"Text","text":"Heading 2 — h2","variant":"h2"},
      {"id":"h3","component":"Text","text":"Heading 3 — h3","variant":"h3"},
      {"id":"h4","component":"Text","text":"Heading 4 — h4","variant":"h4"},
      {"id":"h5","component":"Text","text":"Heading 5 — h5","variant":"h5"},
      {"id":"body","component":"Text","text":"Body text — default","variant":"body"},
      {"id":"cap","component":"Text","text":"Caption text — caption","variant":"caption"}
    ]}}
    ]
    """),

    CatalogEntry(name: "Image", icon: "photo", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)"}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Column","children":["sec_variants","row_small","header_img","sec_fit","fit_contain","fit_cover","fit_fill","fit_none","fit_scaledown"]},
      {"id":"sec_variants","component":"Text","text":"Variants","variant":"h4"},
      {"id":"row_small","component":"Row","children":["avatar","icon","small"],"align":"center"},
      {"id":"avatar","component":"Image","url":"https://picsum.photos/id/64/200/200","variant":"avatar"},
      {"id":"icon","component":"Image","url":"https://picsum.photos/id/76/200/200","variant":"icon"},
      {"id":"small","component":"Image","url":"https://picsum.photos/id/82/200/200","variant":"smallFeature"},
      {"id":"header_img","component":"Image","url":"https://picsum.photos/id/10/800/400","variant":"header","fit":"cover"},
      {"id":"sec_fit","component":"Text","text":"Fit modes (same 600×300 image in a feature frame)","variant":"h4"},
      {"id":"fit_contain","component":"Column","children":["fc_label","fc_img"]},
      {"id":"fc_label","component":"Text","text":"contain — fit entirely, may letterbox","variant":"caption"},
      {"id":"fc_img","component":"Image","url":"https://picsum.photos/id/11/600/300","variant":"mediumFeature","fit":"contain"},
      {"id":"fit_cover","component":"Column","children":["fv_label","fv_img"]},
      {"id":"fv_label","component":"Text","text":"cover — fill frame, may crop","variant":"caption"},
      {"id":"fv_img","component":"Image","url":"https://picsum.photos/id/11/600/300","variant":"mediumFeature","fit":"cover"},
      {"id":"fit_fill","component":"Column","children":["ff_label","ff_img"]},
      {"id":"ff_label","component":"Text","text":"fill — stretch to frame, ignores aspect ratio","variant":"caption"},
      {"id":"ff_img","component":"Image","url":"https://picsum.photos/id/11/600/300","variant":"mediumFeature","fit":"fill"},
      {"id":"fit_none","component":"Column","children":["fn_label","fn_img"]},
      {"id":"fn_label","component":"Text","text":"none — original size, no scaling","variant":"caption"},
      {"id":"fn_img","component":"Image","url":"https://picsum.photos/id/11/600/300","variant":"mediumFeature","fit":"none"},
      {"id":"fit_scaledown","component":"Column","children":["fs_label","fs_img"]},
      {"id":"fs_label","component":"Text","text":"scaleDown — like contain, but never enlarges","variant":"caption"},
      {"id":"fs_img","component":"Image","url":"https://picsum.photos/id/11/600/300","variant":"mediumFeature","fit":"scaleDown"}
    ]}}
    ]
    """),

    CatalogEntry(name: "Icon", icon: "star.circle", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)"}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Row","children":["i1","i2","i3"],"justify":"spaceEvenly","align":"center"},
      {"id":"i1","component":"Icon","name":"favorite"},
      {"id":"i2","component":"Icon","name":"home"},
      {"id":"i3","component":"Icon","name":"settings"}
    ]}}
    ]
    """),

    CatalogEntry(name: "Divider", icon: "minus", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)"}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Column","children":["sec_h","t1","dh","t2","sec_v","row_v"]},
      {"id":"sec_h","component":"Text","text":"Horizontal (default)","variant":"h4"},
      {"id":"t1","component":"Text","text":"Content above"},
      {"id":"dh","component":"Divider"},
      {"id":"t2","component":"Text","text":"Content below"},
      {"id":"sec_v","component":"Text","text":"Vertical (axis)","variant":"h4"},
      {"id":"row_v","component":"Row","children":["left","dv","right"],"align":"stretch"},
      {"id":"left","component":"Text","text":"Left"},
      {"id":"dv","component":"Divider","axis":"vertical"},
      {"id":"right","component":"Text","text":"Right"}
    ]}}
    ]
    """),

    CatalogEntry(name: "Row", icon: "arrow.left.and.right", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)"}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Column","children":["lbl_default","row_default","lbl_center","row_center","lbl_between","row_between","lbl_evenly","row_evenly","lbl_end","row_end","lbl_align","row_align"]},
      {"id":"lbl_default","component":"Text","text":"justify: start (default)","variant":"caption"},
      {"id":"row_default","component":"Row","children":["d1","d2","d3"]},
      {"id":"d1","component":"Text","text":"A"},{"id":"d2","component":"Text","text":"B"},{"id":"d3","component":"Text","text":"C"},
      {"id":"lbl_center","component":"Text","text":"justify: center","variant":"caption"},
      {"id":"row_center","component":"Row","children":["c1","c2","c3"],"justify":"center"},
      {"id":"c1","component":"Text","text":"A"},{"id":"c2","component":"Text","text":"B"},{"id":"c3","component":"Text","text":"C"},
      {"id":"lbl_between","component":"Text","text":"justify: spaceBetween","variant":"caption"},
      {"id":"row_between","component":"Row","children":["b1","b2","b3"],"justify":"spaceBetween"},
      {"id":"b1","component":"Text","text":"A"},{"id":"b2","component":"Text","text":"B"},{"id":"b3","component":"Text","text":"C"},
      {"id":"lbl_evenly","component":"Text","text":"justify: spaceEvenly","variant":"caption"},
      {"id":"row_evenly","component":"Row","children":["e1","e2","e3"],"justify":"spaceEvenly"},
      {"id":"e1","component":"Text","text":"A"},{"id":"e2","component":"Text","text":"B"},{"id":"e3","component":"Text","text":"C"},
      {"id":"lbl_end","component":"Text","text":"justify: end","variant":"caption"},
      {"id":"row_end","component":"Row","children":["n1","n2","n3"],"justify":"end"},
      {"id":"n1","component":"Text","text":"A"},{"id":"n2","component":"Text","text":"B"},{"id":"n3","component":"Text","text":"C"},
      {"id":"lbl_align","component":"Text","text":"align: center (mixed height)","variant":"caption"},
      {"id":"row_align","component":"Row","children":["a1","a2"],"align":"center"},
      {"id":"a1","component":"Text","text":"Small"},
      {"id":"a2","component":"Text","text":"Big Title","variant":"h2"}
    ]}}
    ]
    """),

    CatalogEntry(name: "Column", icon: "arrow.up.and.down", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)"}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Column","children":["lbl_justify","row_justify","lbl_align","col_align"]},
      {"id":"lbl_justify","component":"Text","text":"justify: start / center / end","variant":"caption"},
      {"id":"row_justify","component":"Row","children":["col_start","dv1","col_center","dv2","col_end"]},
      {"id":"col_start","weight":1,"component":"Column","children":["ls","s1","s2","s3"],"justify":"start"},
      {"id":"ls","component":"Text","text":"start","variant":"caption"},
      {"id":"s1","component":"Text","text":"A"},{"id":"s2","component":"Text","text":"B"},{"id":"s3","component":"Text","text":"C"},
      {"id":"dv1","component":"Divider","axis":"vertical"},
      {"id":"col_center","weight":1,"component":"Column","children":["lc","c1","c2","c3"],"justify":"center"},
      {"id":"lc","component":"Text","text":"center","variant":"caption"},
      {"id":"c1","component":"Text","text":"A"},{"id":"c2","component":"Text","text":"B"},{"id":"c3","component":"Text","text":"C"},
      {"id":"dv2","component":"Divider","axis":"vertical"},
      {"id":"col_end","weight":1,"component":"Column","children":["le","e1","e2","e3"],"justify":"end"},
      {"id":"le","component":"Text","text":"end","variant":"caption"},
      {"id":"e1","component":"Text","text":"A"},{"id":"e2","component":"Text","text":"B"},{"id":"e3","component":"Text","text":"C"},
      {"id":"lbl_align","component":"Text","text":"align: center","variant":"caption"},
      {"id":"col_align","component":"Column","children":["aa1","aa2"],"align":"center"},
      {"id":"aa1","component":"Text","text":"Short"},
      {"id":"aa2","component":"Text","text":"A longer text to show cross-axis centering"}
    ]}}
    ]
    """),

    CatalogEntry(name: "Card", icon: "rectangle.on.rectangle", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)"}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Card","child":"content"},
      {"id":"content","component":"Column","children":["title","desc"]},
      {"id":"title","component":"Text","text":"Card Title","variant":"h4"},
      {"id":"desc","component":"Text","text":"This is a card with some content inside."}
    ]}}
    ]
    """),

    CatalogEntry(name: "Button", icon: "rectangle.and.hand.point.up.left", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)"}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Row","children":["b1","b2"]},
      {"id":"b1","component":"Button","child":"bt1","variant":"primary","action":{"event":{"name":"tap1"}}},
      {"id":"bt1","component":"Text","text":"Primary"},
      {"id":"b2","component":"Button","child":"bt2","action":{"event":{"name":"tap2"}}},
      {"id":"bt2","component":"Text","text":"Default"}
    ]}}
    ]
    """),

    CatalogEntry(name: "TextField", icon: "character.cursor.ibeam", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)","sendDataModel":true}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Column","children":["tf_short","tf_num","tf_pw","tf_long","tf_regex"]},
      {"id":"tf_short","component":"TextField","label":"Name","value":{"path":"/name"}},
      {"id":"tf_num","component":"TextField","label":"Age","value":{"path":"/age"},"variant":"number"},
      {"id":"tf_pw","component":"TextField","label":"Password","value":{"path":"/pw"},"variant":"obscured"},
      {"id":"tf_long","component":"TextField","label":"Bio","value":{"path":"/bio"},"variant":"longText"},
      {"id":"tf_regex","component":"TextField","label":"Email","value":{"path":"/email"},"validationRegexp":"^[\\\\w.+-]+@[\\\\w-]+\\\\.[a-zA-Z]{2,}$"}
    ]}},
    {"version":"v0.9","updateDataModel":{"surfaceId":"main","value":{"name":"Jane Doe","age":"28","pw":"secret","bio":"Hello world","email":"jane@example.com"}}}
    ]
    """),

    CatalogEntry(name: "CheckBox", icon: "checkmark.square", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)","sendDataModel":true}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Column","children":["cb1","cb2"]},
      {"id":"cb1","component":"CheckBox","label":"Accept Terms","value":{"path":"/terms"}},
      {"id":"cb2","component":"CheckBox","label":"Subscribe to Newsletter","value":{"path":"/newsletter"}}
    ]}},
    {"version":"v0.9","updateDataModel":{"surfaceId":"main","value":{"terms":true,"newsletter":false}}}
    ]
    """),

    CatalogEntry(name: "Slider", icon: "slider.horizontal.3", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)","sendDataModel":true}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Column","children":["s"]},
      {"id":"s","component":"Slider","label":"Volume","value":{"path":"/volume"},"min":0,"max":100}
    ]}},
    {"version":"v0.9","updateDataModel":{"surfaceId":"main","value":{"volume":50}}}
    ]
    """),

    CatalogEntry(name: "List (Vertical)", icon: "list.bullet", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)"}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"List","children":["l1","l2","l3"],"direction":"vertical"},
      {"id":"l1","component":"Text","text":"Item 1"},
      {"id":"l2","component":"Text","text":"Item 2"},
      {"id":"l3","component":"Text","text":"Item 3"}
    ]}}
    ]
    """),

    CatalogEntry(name: "List (Horizontal)", icon: "list.bullet.indent", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)"}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"List","children":["h1","h2","h3","h4","h5"],"direction":"horizontal"},
      {"id":"h1","component":"Card","child":"ht1"},{"id":"ht1","component":"Text","text":"Card A"},
      {"id":"h2","component":"Card","child":"ht2"},{"id":"ht2","component":"Text","text":"Card B"},
      {"id":"h3","component":"Card","child":"ht3"},{"id":"ht3","component":"Text","text":"Card C"},
      {"id":"h4","component":"Card","child":"ht4"},{"id":"ht4","component":"Text","text":"Card D"},
      {"id":"h5","component":"Card","child":"ht5"},{"id":"ht5","component":"Text","text":"Card E"}
    ]}}
    ]
    """),

    CatalogEntry(name: "DateTimeInput", icon: "calendar", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)","sendDataModel":true}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Column","children":["dt1","dt2","dt3"]},
      {"id":"dt1","component":"DateTimeInput","label":"Date only","value":{"path":"/date"},"enableDate":true,"enableTime":false},
      {"id":"dt2","component":"DateTimeInput","label":"Time only","value":{"path":"/time"},"enableDate":false,"enableTime":true},
      {"id":"dt3","component":"DateTimeInput","label":"Date & Time","value":{"path":"/datetime"},"enableDate":true,"enableTime":true}
    ]}},
    {"version":"v0.9","updateDataModel":{"surfaceId":"main","value":{"date":"2025-12-09","time":"14:30:00","datetime":"2025-12-09T14:30:00"}}}
    ]
    """),

    CatalogEntry(name: "Single Select — Picker", icon: "circle.inset.filled", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)","sendDataModel":true}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"ChoicePicker","label":"Show scroll bars","value":{"path":"/singleRadio"},"variant":"mutuallyExclusive","displayStyle":"checkbox","options":[
        {"label":"Automatically based on mouse or trackpad","value":"auto"},
        {"label":"When scrolling","value":"scroll"},
        {"label":"Always","value":"always"}
      ]}
    ]}},
    {"version":"v0.9","updateDataModel":{"surfaceId":"main","value":{"singleRadio":["auto"]}}}
    ]
    """),

    CatalogEntry(name: "Single Select — Chips", icon: "tag", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)","sendDataModel":true}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"ChoicePicker","label":"Pick one size","value":{"path":"/singleChips"},"variant":"mutuallyExclusive","displayStyle":"chips","options":[
        {"label":"Small","value":"S"},{"label":"Medium","value":"M"},{"label":"Large","value":"L"},{"label":"XL","value":"XL"}
      ]}
    ]}},
    {"version":"v0.9","updateDataModel":{"surfaceId":"main","value":{"singleChips":["M"]}}}
    ]
    """),

    CatalogEntry(name: "Multi Select — Checkbox", icon: "checklist", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)","sendDataModel":true}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"ChoicePicker","label":"Select toppings","value":{"path":"/multiCB"},"variant":"multipleSelection","displayStyle":"checkbox","options":[
        {"label":"Cheese","value":"cheese"},{"label":"Pepperoni","value":"pepperoni"},{"label":"Mushrooms","value":"mushrooms"},{"label":"Olives","value":"olives"},{"label":"Onions","value":"onions"}
      ]}
    ]}},
    {"version":"v0.9","updateDataModel":{"surfaceId":"main","value":{"multiCB":["cheese","mushrooms"]}}}
    ]
    """),

    CatalogEntry(name: "Multi Select — Chips", icon: "tag.fill", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)","sendDataModel":true}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"ChoicePicker","label":"Select tags","value":{"path":"/multiChips"},"variant":"multipleSelection","displayStyle":"chips","options":[
        {"label":"Work","value":"work"},{"label":"Home","value":"home"},{"label":"Urgent","value":"urgent"},{"label":"Later","value":"later"},{"label":"Fun","value":"fun"}
      ]}
    ]}},
    {"version":"v0.9","updateDataModel":{"surfaceId":"main","value":{"multiChips":["work","urgent"]}}}
    ]
    """),

    CatalogEntry(name: "Filterable — Checkbox", icon: "line.3.horizontal.decrease.circle", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)","sendDataModel":true}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"ChoicePicker","label":"Select countries","value":{"path":"/filterCB"},"variant":"multipleSelection","displayStyle":"checkbox","filterable":true,"options":[
        {"label":"United States","value":"US"},{"label":"Canada","value":"CA"},{"label":"United Kingdom","value":"UK"},{"label":"Australia","value":"AU"},{"label":"Germany","value":"DE"},{"label":"France","value":"FR"},{"label":"Japan","value":"JP"},{"label":"South Korea","value":"KR"},{"label":"Brazil","value":"BR"},{"label":"India","value":"IN"},{"label":"Mexico","value":"MX"},{"label":"Italy","value":"IT"}
      ]}
    ]}},
    {"version":"v0.9","updateDataModel":{"surfaceId":"main","value":{"filterCB":["US"]}}}
    ]
    """),

    CatalogEntry(name: "Filterable — Chips", icon: "line.3.horizontal.decrease.circle.fill", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)","sendDataModel":true}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"ChoicePicker","label":"Select languages","value":{"path":"/filterChips"},"variant":"multipleSelection","displayStyle":"chips","filterable":true,"options":[
        {"label":"Swift","value":"swift"},{"label":"Python","value":"python"},{"label":"Rust","value":"rust"},{"label":"Go","value":"go"},{"label":"TypeScript","value":"typescript"},{"label":"Kotlin","value":"kotlin"},{"label":"Java","value":"java"},{"label":"C++","value":"cpp"},{"label":"Ruby","value":"ruby"},{"label":"Haskell","value":"haskell"},{"label":"Scala","value":"scala"},{"label":"Elixir","value":"elixir"},{"label":"Dart","value":"dart"},{"label":"Zig","value":"zig"}
      ]}
    ]}},
    {"version":"v0.9","updateDataModel":{"surfaceId":"main","value":{"filterChips":["swift","rust"]}}}
    ]
    """),

    CatalogEntry(name: "Tabs", icon: "rectangle.split.3x1", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)"}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Tabs","tabs":[{"title":"View One","child":"t1"},{"title":"View Two","child":"t2"}]},
      {"id":"t1","component":"Text","text":"First tab content"},
      {"id":"t2","component":"Text","text":"Second tab content"}
    ]}}
    ]
    """),

    CatalogEntry(name: "Modal", icon: "rectangle.portrait.on.rectangle.portrait", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)"}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Modal","trigger":"mbtn","content":"mcol"},
      {"id":"mbtn","component":"Button","child":"mbtn-text","action":{"event":{"name":"open_modal"}}},
      {"id":"mbtn-text","component":"Text","text":"Open Modal"},
      {"id":"mcol","component":"Column","children":["mh","mp","mclose"]},
      {"id":"mh","component":"Text","text":"Modal Title","variant":"h3"},
      {"id":"mp","component":"Text","text":"This is a modal dialog with rich content. Tap the close button to dismiss."},
      {"id":"mclose","component":"Button","child":"mclose-text","action":{"event":{"name":"dismiss_modal"}}},
      {"id":"mclose-text","component":"Text","text":"Got it"}
    ]}}
    ]
    """),

    CatalogEntry(name: "Video", icon: "play.rectangle", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)"}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"Video","url":"https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"}
    ]}}
    ]
    """),

    CatalogEntry(name: "AudioPlayer", icon: "waveform", json: """
    [
    {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"\(CID)"}},
    {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
      {"id":"root","component":"AudioPlayer","url":"https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3","description":"Sample Audio Track"}
    ]}}
    ]
    """),

]

#Preview {
    NavigationStack {
        CatalogPage()
    }
}
