# Generative UI SDK for SwiftUI (genui)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange?logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-iOS%2017%20%7C%20macOS%2014%20%7C%20visionOS%201%20%7C%20watchOS%2010%20%7C%20tvOS%2017-blue)
![UIKit](https://img.shields.io/badge/UIKit-work%20in%20progress-lightgrey)
![AppKit](https://img.shields.io/badge/AppKit-work%20in%20progress-lightgrey)
![A2UI](https://img.shields.io/badge/A2UI-v0.8-purple)
![A2UI](https://img.shields.io/badge/A2UI-v0.9-purple)
![License](https://img.shields.io/badge/License-MIT-green)
![Tests](https://img.shields.io/badge/Tests-277%20passing-brightgreen)

**Render AI agent interfaces natively on Apple platforms — no WebView, no compromise.**

The community SwiftUI renderer for the [A2UI](https://github.com/google/A2UI) protocol, listed on the [official A2UI ecosystem page](https://a2ui.org/ecosystem/renderers/). Your agent's JSON surfaces become fully native iOS, macOS, visionOS, watchOS, and tvOS interfaces — complete with live streaming, two-way data binding, and the full SwiftUI component lifecycle.

| iOS | iPadOS | macOS | visionOS | watchOS | tvOS |
|:---:|:------:|:-----:|:--------:|:-------:|:----:|
| <img src="https://github.com/user-attachments/assets/b765127a-b97f-4767-a2ef-98f2d8f3f96e" height="280"/> | <img src="https://github.com/user-attachments/assets/902e5e55-f556-4112-b8ec-09ec9f991231" height="280"/> | <img src="https://github.com/user-attachments/assets/1eacae69-f8ba-4285-bb3d-dad1bd8eefb0" height="280"/> | <img src="https://github.com/user-attachments/assets/99e8c253-130c-4b09-a661-9b5aaeff2b5f" height="280"/> | <img src="https://github.com/user-attachments/assets/6bbd46f5-8ff0-4360-9d39-9175444843bf" height="280"/> | <img src="https://github.com/user-attachments/assets/f3e16070-e0e6-4862-a393-c12543816fbe" height="280"/> |

## What is A2UI?

[A2UI](https://github.com/google/A2UI) is an open protocol that lets AI agents generate rich, interactive user interfaces through a declarative JSON format — not executable code. An agent describes *what* to render; the renderer decides *how* using native platform controls.

```
Agent → JSON payload → A2UISurfaceView / A2UIRendererView → Native SwiftUI UI
```

Because the format is declarative and component-constrained, agents can only request pre-approved UI components from a trusted catalog — making A2UI secure by design. The same JSON payload renders appropriately across web, Flutter, React, and all Apple platforms via this renderer.

## Why SwiftUI?

Most agent UI renderers use WebView or custom draw loops. This renderer maps every A2UI component to its idiomatic SwiftUI counterpart — `HStack`, `LazyVStack`, `DatePicker`, `.sheet`, and so on. You get:

- **Native performance** — no WebView overhead, no bridge layer
- **Platform adaptivity** — the same JSON renders appropriately on iPhone, Mac, Apple Watch, and Apple Vision Pro
- **SwiftUI ecosystem** — themes, accessibility, Dark Mode, Dynamic Type, and environment values just work
- **Property-level reactivity** — powered by `@Observable` (Observation framework), matching the Signal-based approach of the official Lit and Angular renderers
- **Security by design** — declarative JSON means agents cannot execute arbitrary code on the client

## Requirements

- iOS 17.0+ / macOS 14.0+ / visionOS 1.0+ / watchOS 10.0+ / tvOS 17.0+
- Swift 5.9+
- Xcode 15+

## Installation

Add this package to your project via Swift Package Manager:

**In `Package.swift`:**

```swift
dependencies: [
    .package(url: "https://github.com/BBC6BAE9/a2ui-swiftui", from: "0.1.0"),
],
targets: [
    .target(name: "YourApp", dependencies: [
        "A2A",            // A2A protocol client
        "Primitives",     // Shared primitive types
        "v_08",           // v0.8 renderer
        "A2UISwiftCore",  // v0.9 shared protocol layer (data model, schema, catalog)
        "A2UISwiftUI",    // v0.9 SwiftUI renderer
        // "A2UIUIKit",   // v0.9 UIKit renderer (iOS, tvOS, visionOS)
        // "A2UIAppKit",  // v0.9 AppKit renderer (macOS)
    ]),
]
```

**In Xcode:** File → Add Package Dependencies → paste the repository URL.

## Modules

The package is organized into six independent library products:

| Module | Purpose |
|--------|---------|
| **A2A** | A2A protocol client — agent card, task lifecycle, JSON-RPC, HTTP & SSE transports |
| **Primitives** | Shared primitive types — `ChatMessage`, `Part`, `JSONValue`, `ToolDefinition`, etc. |
| **A2UISwiftCore** | v0.9 shared protocol layer — schema, data model, catalog system, expression parser, transport |
| **A2UISwiftUI** | v0.9 SwiftUI renderer via `A2UISurfaceView` with `SurfaceViewModel` |
| **A2UIUIKit** | v0.9 UIKit renderer — iOS, tvOS, visionOS (community extension point via `A2UIUIKitComponent`) |
| **A2UIAppKit** | v0.9 AppKit renderer — macOS (community extension point via `A2UIAppKitComponent`) |
| ~~**v_08**~~ | ⚠️ **Deprecated** — v0.8 renderer via `A2UIRendererView` with `SurfaceManager` |

## Quick Start

### v0.9 — `A2UISurfaceView` (recommended)

```swift
import A2UISwiftUI

@State var vm = SurfaceViewModel(catalog: basicCatalog)

// Process messages from your agent transport:
try vm.processMessages(messages)

// Render:
A2UISurfaceView(viewModel: vm)

// With action handler:
A2UISurfaceView(viewModel: vm) { action in
    print("Action: \(action.name)")
}
```

### v0.8 — `A2UIRendererView`

```swift
import v_08

let parser = JSONLStreamParser()
let manager = SurfaceManager()

let (bytes, _) = try await URLSession.shared.bytes(for: request)
for try await message in parser.messages(from: bytes) {
    try manager.processMessage(message)
}

A2UIRendererView(manager: manager)
```

## Supported Components

All 18 standard A2UI components are implemented and platform-adaptive. Each uses native SwiftUI controls with no hardcoded spacing, colors, or corner radii.

| Category | Components |
|----------|-----------|
| Display  | Text, Image, Icon, Video, AudioPlayer, Divider |
| Layout   | Row, Column, List, Card, Tabs, Modal |
| Input    | Button, TextField, CheckBox, DateTimeInput, Slider, MultipleChoice / ChoicePicker |

<details>
<summary>Full component → SwiftUI mapping</summary>

| A2UI Component | SwiftUI Implementation | Platform Notes |
|---------------|----------------------|----------------|
| Text | `SwiftUI.Text` with `usageHint` → font mapping (h1–h6) | Dynamic Type on all platforms |
| Image | `AsyncImage` with `usageHint` variants (avatar, icon, feature, header) | Avatar → circle clip |
| Icon | `Image(systemName:)` with Material → SF Symbol mapping | Font-relative sizing via custom `Layout` |
| Video | `AVPlayerViewController` (iOS/tvOS/visionOS) / `AVPlayerView` (macOS) | watchOS: static placeholder |
| AudioPlayer | `AVPlayer` with custom play/pause controls | watchOS: placeholder only |
| Row | `HStack` with distribution and alignment | Spacer-based `spaceBetween` / `spaceEvenly` |
| Column | `VStack` with distribution and alignment | |
| List | `LazyVStack` / `LazyHStack` with template support | |
| Card | Continuous squircle container | No shadow (system cards use background contrast) |
| Tabs | `Picker(.segmented)` / scrollable button row | ≤5 tabs → segmented; >5 → scroll; watchOS → `.wheel` |
| Modal | `.sheet` + `NavigationStack` | `.presentationDetents` on iOS/macOS; plain sheet on watchOS/tvOS |
| Button | `.borderedProminent` / `.bordered` | Overridable via `A2UIStyle` |
| TextField | `TextField` / `SecureField` / `TextEditor` | `textFieldType`-driven; number → `.decimalPad` |
| CheckBox | `Toggle(.automatic)` | iOS=switch, macOS=checkbox |
| DateTimeInput | `DatePicker` | tvOS: read-only text fallback |
| Slider | `SwiftUI.Slider` | tvOS: ±Button pair + `ProgressView` fallback |
| MultipleChoice | Radio / Menu / Chips / Filterable Sheet | Single→radio/menu; Multi→checkbox/chips; tvOS→`NavigationLink` |
| Divider | `SwiftUI.Divider()` | Auto-adapts orientation from parent |

</details>

## Custom Components

Third-party components can be registered and rendered inline alongside standard A2UI components:

```swift
A2UIRendererView(messages: messages)
    .environment(\.a2uiCustomComponentRenderer) { typeName, props, viewModel in
        if typeName == "Chart" {
            MyChartView(props: props)
        }
    }
```

## Architecture

```
Sources/
├── A2A/                  A2A protocol client library
│   ├── Core/             Agent card, task, message, part, event types
│   └── Client/           A2AClient, HTTP & SSE transports, SSE parser
├── Primitives/           Shared primitive types (ChatMessage, Part, JSONValue, ToolDefinition)
├── v_08/                 v0.8 renderer
│   ├── Shared/           AnyCodable, ResolvedAction, UIState, DataStoreUtils
│   ├── V08/              Models, Processing, Views (suffixed _V08)
│   ├── Processing/       SurfaceManager + JSONLStreamParser
│   ├── Views/Helpers/    SVG, accessibility, weight modifiers
│   ├── Styling/          A2UIStyle + Environment integration
│   ├── Networking/       A2AClient (JSON-RPC over HTTP + SSE)
│   └── A2UIRenderer.swift  Public API — A2UIRendererView
├── A2UISwiftCore/        v0.9 shared protocol layer (UI-framework agnostic)
│   ├── Schema/           ServerToClient / ClientToServer messages, component types
│   ├── State/            SurfaceModel, DataModel, ComponentModel, UIState
│   ├── Rendering/        ComponentNode, ComponentContext, DataContext, DataSubscriptions
│   ├── Processing/       MessageProcessor
│   ├── BasicCatalog/     Built-in catalog, expression parser, catalog functions
│   ├── Catalog/          FunctionInvoker, catalog type system
│   ├── Common/           Shared utilities
│   ├── Errors.swift      Protocol error types
│   └── Transport/        A2UITransport, stream parser, JSON block parser
├── A2UISwiftUI/          v0.9 SwiftUI renderer
│   ├── SurfaceViewModel.swift  @Observable SwiftUI view model
│   ├── CatalogItem.swift
│   ├── CustomComponentRegistry.swift
│   ├── Styling/          A2UIStyle + SwiftUI Environment
│   ├── Helpers/          SVG, alignment, weight modifiers
│   └── Views/            A2UISurfaceView, A2UIComponentView, per-component views
├── A2UIUIKit/            v0.9 UIKit renderer — iOS, tvOS, visionOS
│   └── A2UIUIKitComponent.swift  Protocol + implementation guide
├── A2UIAppKit/           v0.9 AppKit renderer — macOS
│   └── A2UIAppKitComponent.swift Protocol + implementation guide
└── samples/
    ├── sample_0.8/       Demo app for v0.8 renderer (Xcode project)
    └── travel_app/       Full travel app sample with AI client integration
```

The v0.9 implementation is split into three renderer-agnostic layers: **A2UISwiftCore** owns all protocol logic (schema, data model, catalog, transport); **A2UISwiftUI** adds the `@Observable` `SurfaceViewModel` and SwiftUI views; **A2UIUIKit** / **A2UIAppKit** provide the `A2UIUIKitComponent` / `A2UIAppKitComponent` protocols as extension points for UIKit and AppKit renderers. The **v_08** module provides the `A2UIRendererView` API with `SurfaceManager` for v0.8 protocol rendering.

## Sample Apps

### sample_0.8

The original demo app for the v0.8 renderer. Open `samples/sample_0.8/A2UIDemoApp.xcodeproj` in Xcode.

Includes static JSON demos (no agent required) and live A2A agent connections. Each page has an **info inspector** explaining what it demonstrates; action-triggering pages display a **Resolved Action log** showing the full context payload.

|                             info                             |                          action log                          |                            genui                             |
| :----------------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: |
| <img src="https://github.com/user-attachments/assets/1cefe139-3266-4b57-8f2e-d4d2046b3ae6" height="200"/> | <img src="https://github.com/user-attachments/assets/f65a68a3-78a7-4542-8bf4-868ce0e91ec4" height="200"/> | <img src="https://github.com/user-attachments/assets/3b38f7c5-3b7e-4910-9222-bfa2c7cf236b" height="200"/> |

> Live agent demo is included in the app — no external dependency required.

### travel_app

A full-featured travel app sample demonstrating the v0.9 renderer with AI client integration, custom catalog components, and real generative AI interactions.

## Spec Compliance

### v0.8 (`v_08` module)
- **Protocol messages:** `beginRendering`, `surfaceUpdate`, `dataModelUpdate`, `deleteSurface`
- **Data binding:** Path-based resolution (`/items/0/name`), bracket/dot normalization, template rendering, literal seeding
- **Action system:** Full action context resolution with `[{key, value}]` context format
- **Styling:** `beginRendering.styles` parsed into `A2UIStyle`

### v0.9 (`A2UISwiftCore` + `A2UISwiftUI` modules)
- **Protocol messages:** `createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`
- **Flat component format:** `{"component": "Text", "text": "hello"}` (no nested wrapper)
- **Data binding:** JSON Pointer paths (RFC 6901), `DynamicString` / `DynamicNumber` / `DynamicBoolean` / `DynamicStringList` with literal, path, and function call support
- **Action system:** Event-based `{event: {name, context}}` with `Record<string, DynamicValue>` context, or client-side `{functionCall: {...}}`
- **Validation:** `checks` array with `CheckRule` (condition + message) for input components
- **Styling:** `createSurface.theme` structured JSON object
- **Catalog functions:** `formatString`, `formatNumber`, `formatCurrency`, `formatDate`, `pluralize`, `openUrl`, `required`, `email`, `regex`, `length`, `numeric`, `and`, `or`, `not`

## Testing

```bash
swift test
```

277 tests across 7 test suites cover message decoding, component parsing, data binding, path resolution, template rendering, catalog functions, validation, JSONL streaming, incremental updates, and Codable round-trips.

## Known Limitations

- Requires iOS 17+ / macOS 14+ (uses `@Observable` from the Observation framework)
- Custom (non-standard) component types are decoded but not rendered unless registered via `CustomComponentRegistry`
- Video playback uses `UIViewControllerRepresentable` on iOS; macOS uses `AVPlayerView`
- No built-in Content Security Policy enforcement for image/video URLs — applications should validate URLs from untrusted agents

## Security

A2UI's declarative model means agents can only request components from a trusted catalog — they cannot inject executable code. When building production applications, treat any agent outside your direct control as an untrusted entity.

Concretely:
- **Prompt injection:** sanitize agent-supplied strings before using them in LLM prompts
- **Phishing / UI spoofing:** validate agent identity before rendering their surfaces
- **XSS:** apply a strict Content Security Policy if your app embeds web content
- **DoS:** enforce limits on layout complexity for surfaces from untrusted agents

Developers are responsible for input sanitization, sandboxing rendered content, and secure credential handling. The sample code is for demonstration purposes only.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add components, run tests, and submit PRs.

## License

MIT — see [LICENSE](LICENSE).
