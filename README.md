# Generative UI SDK for SwiftUI (genui)

**Render AI agent interfaces natively on Apple platforms — no WebView, no compromise.**

The community SwiftUI renderer for the [A2UI](https://github.com/google/A2UI) protocol, listed on the [official A2UI ecosystem page](https://a2ui.org/ecosystem/renderers/). Drop in `A2UIRendererView` and your agent's JSON surfaces become fully native iOS, macOS, visionOS, watchOS, and tvOS interfaces — complete with live streaming, two-way data binding, and the full SwiftUI component lifecycle.

![Swift](https://img.shields.io/badge/Swift-5.9+-orange?logo=swift)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20%7C%20macOS%2014%20%7C%20visionOS%201%20%7C%20watchOS%2010%20%7C%20tvOS%2017-blue)
![A2UI](https://img.shields.io/badge/A2UI-v0.8%20%2B%20v0.9-purple)
![License](https://img.shields.io/badge/License-MIT-green)
![Tests](https://img.shields.io/badge/Tests-87%20passing-brightgreen)

| iOS | iPadOS | macOS | visionOS | watchOS | tvOS |
|:---:|:------:|:-----:|:--------:|:-------:|:----:|
| <img src="https://github.com/user-attachments/assets/b765127a-b97f-4767-a2ef-98f2d8f3f96e" height="280"/> | <img src="https://github.com/user-attachments/assets/902e5e55-f556-4112-b8ec-09ec9f991231" height="280"/> | <img src="https://github.com/user-attachments/assets/1eacae69-f8ba-4285-bb3d-dad1bd8eefb0" height="280"/> | <img src="https://github.com/user-attachments/assets/99e8c253-130c-4b09-a661-9b5aaeff2b5f" height="280"/> | <img src="https://github.com/user-attachments/assets/6bbd46f5-8ff0-4360-9d39-9175444843bf" height="280"/> | <img src="https://github.com/user-attachments/assets/f3e16070-e0e6-4862-a393-c12543816fbe" height="280"/> |

## What is A2UI?

[A2UI](https://github.com/google/A2UI) is an open protocol that lets AI agents generate rich, interactive user interfaces through a declarative JSON format — not executable code. An agent describes *what* to render; the renderer decides *how* using native platform controls.

```
Agent → JSON payload → A2UIRendererView → Native SwiftUI UI
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
    .target(name: "YourApp", dependencies: ["A2UI"]),
]
```

**In Xcode:** File → Add Package Dependencies → paste the repository URL.

## Quick Start

### Static JSON

```swift
import A2UI

// Decode A2UI messages from a JSON payload
let messages = try JSONDecoder().decode([ServerToClientMessage].self, from: data)

A2UIRendererView(messages: messages)
```

### Live Agent Streaming

```swift
import A2UI

// Connect directly to a streaming A2A agent
A2UIRendererView(stream: messageStream) { action in
    print("User triggered: \(action.name)")
}
```

### JSONL over URLSession

```swift
import A2UI

let parser = JSONLStreamParser()
let manager = SurfaceManager()

let (bytes, _) = try await URLSession.shared.bytes(for: request)
for try await message in parser.messages(from: bytes) {
    try manager.processMessage(message)
}

// View only observes — no stream logic in the view layer
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

The demo app includes a **Rizzcharts** example with custom `Chart` (Swift Charts) and `GoogleMap` (MapKit) components registered via `CustomComponentRegistry`.

## Architecture

```
Sources/A2UI/
├── Shared/           Version-independent code (AnyCodable, ResolvedAction, UIState, DataStoreUtils)
├── V08/              v0.8 protocol (Models, Processing, Views — all types suffixed _V08)
├── V09/              v0.9 protocol (Models, Processing, Views — all types suffixed _V09)
├── Processing/       SurfaceManager (version dispatch) + JSONLStreamParser (auto-detect)
├── Views/Helpers/    Shared SwiftUI helpers (SVG, accessibility, weight modifiers)
├── Styling/          A2UIStyle + SwiftUI Environment integration
├── Networking/       A2AClient (JSON-RPC over HTTP + SSE streaming)
├── ProtocolVersion.swift   Version detection + VersionedMessage enum
└── A2UIRenderer.swift      Public API entry point
```

The public API is a single view — `A2UIRendererView` — that renders both v0.8 and v0.9 surfaces transparently. All state lives in `SurfaceManager`, which auto-detects protocol version and routes messages to the correct versioned handler. v0.8 and v0.9 are file-level separated (aligned with the official web_core architecture), with shared utilities extracted to `Shared/`.

## Demo App

Open `A2UIDemoApp/A2UIDemoApp.xcodeproj` in Xcode and run on a simulator or device.

The app includes **10 demo pages** — static JSON demos (no agent required) and live A2A agent connections. Each page has an **info inspector** explaining what it demonstrates; action-triggering pages display a **Resolved Action log** showing the full context payload.

|                             info                             |                          action log                          |                            genui                             |
| :----------------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: |
| <img src="https://github.com/user-attachments/assets/1cefe139-3266-4b57-8f2e-d4d2046b3ae6" height="200"/> | <img src="https://github.com/user-attachments/assets/f65a68a3-78a7-4542-8bf4-868ce0e91ec4" height="200"/> | <img src="https://github.com/user-attachments/assets/3b38f7c5-3b7e-4910-9222-bfa2c7cf236b" height="200"/> |

> Live agent demo: [BBC6BAE9/genui](https://github.com/BBC6BAE9/genui)

## Spec Compliance

This renderer supports **both A2UI v0.8 and v0.9** protocols simultaneously, with automatic version detection.

### v0.8
- **Protocol messages:** `beginRendering`, `surfaceUpdate`, `dataModelUpdate`, `deleteSurface`
- **Data binding:** Path-based resolution (`/items/0/name`), bracket/dot normalization, template rendering, literal seeding
- **Action system:** Full action context resolution with `[{key, value}]` context format
- **Styling:** `beginRendering.styles` parsed into `A2UIStyle`

### v0.9
- **Protocol messages:** `createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`
- **Flat component format:** `{"component": "Text", "text": "hello"}` (no nested wrapper)
- **Data binding:** JSON Pointer paths (RFC 6901), `DynamicString` / `DynamicNumber` / `DynamicBoolean` / `DynamicStringList` with literal, path, and function call support
- **Action system:** Event-based `{event: {name, context}}` with `Record<string, DynamicValue>` context, or client-side `{functionCall: {...}}`
- **Validation:** `checks` array with `CheckRule` (condition + message) for input components
- **Styling:** `createSurface.theme` structured JSON object

### Shared
- **Catalog functions:** `formatString`, `formatNumber`, `formatCurrency`, `formatDate`, `pluralize`, `openUrl`, `required`, `email`, `regex`, `length`, `numeric`, `and`, `or`, `not`
- **Version detection:** Fast byte-scan — no overhead per message. Falls back to message-key detection if `"version"` field is absent

## Testing

```bash
swift test
```

87 tests across 5 test files cover message decoding, component parsing, data binding, path resolution, template rendering, catalog functions, validation, JSONL streaming, incremental updates, and Codable round-trips.

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
