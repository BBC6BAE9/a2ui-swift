# A2UI SwiftUI Renderer

![Swift](https://img.shields.io/badge/Swift-5.9+-orange?logo=swift)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20%7C%20macOS%2014%20%7C%20visionOS%201%20%7C%20watchOS%2010%20%7C%20tvOS%2017-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Tests](https://img.shields.io/badge/Tests-87%20passing-brightgreen)

**Render AI agent interfaces natively on Apple platforms — no WebView, no compromise.**

A SwiftUI renderer for the [A2UI](https://github.com/google/A2UI) protocol. Drop in `A2UIRendererView` and your agent's JSON surfaces become fully native iOS, macOS, visionOS, watchOS, and tvOS interfaces — complete with live streaming, two-way data binding, and the full SwiftUI component lifecycle.

| iOS | iPadOS | macOS | visionOS | watchOS | tvOS |
|:---:|:------:|:-----:|:--------:|:-------:|:----:|
| <img src="https://github.com/user-attachments/assets/b765127a-b97f-4767-a2ef-98f2d8f3f96e" height="280"/> | <img src="https://github.com/user-attachments/assets/902e5e55-f556-4112-b8ec-09ec9f991231" height="280"/> | <img src="https://github.com/user-attachments/assets/1eacae69-f8ba-4285-bb3d-dad1bd8eefb0" height="280"/> | <img src="https://github.com/user-attachments/assets/99e8c253-130c-4b09-a661-9b5aaeff2b5f" height="280"/> | <img src="https://github.com/user-attachments/assets/6bbd46f5-8ff0-4360-9d39-9175444843bf" height="280"/> | <img src="https://github.com/user-attachments/assets/f3e16070-e0e6-4862-a393-c12543816fbe" height="280"/> |

## Why SwiftUI?

Most agent UI renderers use WebView or custom draw loops. This renderer maps every A2UI component to its idiomatic SwiftUI counterpart — `HStack`, `LazyVStack`, `DatePicker`, `.sheet`, and so on. You get:

- **Native performance** — no WebView overhead, no bridge layer
- **Platform adaptivity** — the same JSON renders appropriately on iPhone, Mac, Apple Watch, and Apple Vision Pro
- **SwiftUI ecosystem** — themes, accessibility, Dark Mode, Dynamic Type, and environment values just work
- **Property-level reactivity** — powered by `@Observable` (Observation framework), matching the Signal-based approach of the official Lit and Angular renderers

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

All 18 standard A2UI components are implemented:

| Category | Components |
|----------|-----------|
| Display  | Text, Image, Icon, Video, AudioPlayer, Divider |
| Layout   | Row, Column, List, Card, Tabs, Modal |
| Input    | Button, TextField, CheckBox, DateTimeInput, Slider, MultipleChoice |

<details>
<summary>Full component mapping</summary>

| A2UI Component | SwiftUI Implementation |
|---------------|----------------------|
| Text | `SwiftUI.Text` with usageHint → font mapping (h1–h6) |
| Image | `AsyncImage` with usageHint variants (avatar, icon, feature, header) |
| Icon | `Image(systemName:)` with Material → SF Symbol mapping |
| Video | `AVPlayerViewController` (iOS) / `VideoPlayer` (macOS) |
| AudioPlayer | `AVPlayer` with custom play/pause controls |
| Row | `HStack` with distribution and alignment |
| Column | `VStack` with distribution and alignment |
| List | `LazyVStack` / `LazyHStack` with template support |
| Card | Rounded-corner container with shadow |
| Tabs | Segmented tab bar with content switching |
| Modal | `.sheet` presentation |
| Button | Primary / secondary styles with action callbacks |
| TextField | `SwiftUI.TextField` / `TextEditor` with two-way binding |
| CheckBox | `Toggle` |
| DateTimeInput | `DatePicker` |
| Slider | `SwiftUI.Slider` |
| MultipleChoice | Checkbox list or chips (FlowLayout) with filtering |
| Divider | `SwiftUI.Divider` |

</details>

## Architecture

```
Sources/A2UI/
├── Models/           Codable data models (Messages, Components, Primitives)
├── Processing/       SurfaceManager (state) + JSONLStreamParser (streaming)
├── Views/            A2UIComponentView (recursive renderer)
├── Styling/          A2UIStyle + SwiftUI Environment integration
├── Networking/       A2AClient (JSON-RPC over HTTP)
└── A2UIRenderer.swift   Public API entry point
```

The public API is a single view — `A2UIRendererView` — with three initializers covering static, streamed, and externally-managed surfaces. All state lives in `SurfaceManager`, keeping the view layer pure.

## Demo App

Open `A2UIDemoApp/A2UIDemoApp.xcodeproj` in Xcode and run on a simulator or device.

The app includes **10 demo pages** covering static JSON rendering and live A2A agent connections. Each page has an **info inspector** explaining what it demonstrates; action-triggering pages display a **Resolved Action log** showing the full context payload.

|                             info                             |                          action log                          |                            genui                             |
| :----------------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: |
| <img src="https://github.com/user-attachments/assets/1cefe139-3266-4b57-8f2e-d4d2046b3ae6" height="200"/> | <img src="https://github.com/user-attachments/assets/f65a68a3-78a7-4542-8bf4-868ce0e91ec4" height="200"/> | <img src="https://github.com/user-attachments/assets/3b38f7c5-3b7e-4910-9222-bfa2c7cf236b" height="200"/> |

> Live agent demo: [BBC6BAE9/genui](https://github.com/BBC6BAE9/genui)

## Testing

```bash
swift test
```

87 tests across 5 test files cover message decoding, component parsing, data binding, path resolution, template rendering, catalog functions, validation, JSONL streaming, incremental updates, and Codable round-trips.

## Known Limitations

- Requires iOS 17+ / macOS 14+ (uses `@Observable` from the Observation framework)
- Custom (non-standard) component types are decoded but not rendered
- Video playback uses `UIViewControllerRepresentable` on iOS; macOS uses a `VideoPlayer` fallback
- No built-in Content Security Policy enforcement for image/video URLs — applications should validate URLs from untrusted agents

## Security

When building production applications, treat any agent operating outside your direct control as an untrusted entity. All data received from an external agent — AgentCard, messages, artifacts, task statuses — should be handled as untrusted input.

Concretely:
- **Prompt injection:** agent-supplied strings (name, description, etc.) must be sanitized before being used to construct LLM prompts
- **Phishing / UI spoofing:** validate the identity of agents before rendering their surfaces
- **XSS:** if your app embeds web content, apply a strict Content Security Policy
- **DoS:** enforce limits on layout complexity for surfaces from untrusted agents

Developers are responsible for input sanitization, sandboxing rendered content, and secure credential handling. The sample code in this repository is for demonstration purposes only.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add components, run tests, and submit PRs.

## License

MIT — see [LICENSE](LICENSE).
