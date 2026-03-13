# A2UI SwiftUI Renderer

A native SwiftUI renderer for the [A2UI](https://github.com/google/A2UI) protocol.
Renders agent-generated JSON into native iOS and macOS interfaces using SwiftUI.

This is a community-maintained renderer for the A2UI specification.
| iOS | iPadOS | macOS | visionOS | watchOS | tvOS |
|:---:|:------:|:-----:|:--------:|:-------:|:----:|
| <img src="https://github.com/user-attachments/assets/b765127a-b97f-4767-a2ef-98f2d8f3f96e" height="280"/> | <img src="https://github.com/user-attachments/assets/902e5e55-f556-4112-b8ec-09ec9f991231" height="280"/> | <img src="https://github.com/user-attachments/assets/1eacae69-f8ba-4285-bb3d-dad1bd8eefb0" height="280"/> | <img src="https://github.com/user-attachments/assets/99e8c253-130c-4b09-a661-9b5aaeff2b5f" height="280"/> | <img src="https://github.com/user-attachments/assets/6bbd46f5-8ff0-4360-9d39-9175444843bf" height="280"/> | <img src="https://github.com/user-attachments/assets/f3e16070-e0e6-4862-a393-c12543816fbe" height="280"/> |



## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 5.9+
- Xcode 15+

## Installation

Since the `Package.swift` lives in the `renderers/swiftui/` subdirectory (not the
repository root), use a local path reference:

**In `Package.swift`:**

```swift
dependencies: [
    .package(path: "../path/to/A2UI/renderers/swiftui"),
]
```

**In Xcode:** File → Add Package Dependencies → Add Local… → select the
`renderers/swiftui` directory.

## Quick Start

```swift
import A2UI

// 1. Load A2UI messages (from a JSON file, network response, etc.)
let data = try Data(contentsOf: jsonFileURL)
let messages = try JSONDecoder().decode([ServerToClientMessage].self, from: data)

// 2. Render the surface
A2UIRendererView(messages: messages)
```

### Live Agent Streaming

```swift
import A2UI

// Stream messages from an A2A agent
A2UIRendererView(stream: messageStream, onAction: { action in
    print("User triggered: \(action.name)")
})
```

### JSONL Stream Parsing

```swift
import A2UI

let parser = JSONLStreamParser()
let manager = SurfaceManager()

// Parse from async byte stream (e.g. URLSession)
let (bytes, _) = try await URLSession.shared.bytes(for: request)
for try await message in parser.messages(from: bytes) {
    try manager.processMessage(message)
}

// Render in SwiftUI — View only observes, no stream logic
A2UIRendererView(manager: manager)
```

## Supported Components

All 18 standard A2UI components are implemented:

| Category | Components |
|----------|-----------|
| Display | Text, Image, Icon, Video, AudioPlayer, Divider |
| Layout | Row, Column, List, Card, Tabs, Modal |
| Input | Button, TextField, CheckBox, DateTimeInput, Slider, MultipleChoice |

### Component Mapping

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

## Architecture

```
Sources/A2UI/
├── Models/         Codable data models (Messages, Components, Primitives)
├── Processing/     SurfaceViewModel (state) + JSONLStreamParser (streaming)
├── Views/          A2UIComponentView (recursive renderer)
├── Styling/        A2UIStyle + SwiftUI Environment integration
├── Networking/     A2AClient (JSON-RPC over HTTP)
└── A2UIRenderer.swift   Public API entry point
```

The renderer uses `@Observable` (Observation framework) for property-level
reactivity, matching the Signal-based approach used by the official Lit and
Angular renderers.

## Running Tests

```bash
cd renderers/swiftui
swift test
```

84 tests across 5 test files cover message decoding, component parsing, data
binding, path resolution, template rendering, catalog functions, validation,
JSONL streaming, incremental updates, and Codable round-trips.

## Demo App

The demo app is located at `samples/client/swiftui/A2UIDemoApp/` in the
repository root. It demonstrates both offline sample rendering and live A2A
agent integration.

Open `samples/client/swiftui/A2UIDemoApp/A2UIDemoApp.xcodeproj` in Xcode and run on a
simulator or device.

|                             info                             |                          action log                          |                            genui                             |
| :----------------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: |
| <img src="https://github.com/user-attachments/assets/1cefe139-3266-4b57-8f2e-d4d2046b3ae6" height="200"/> | <img src="https://github.com/user-attachments/assets/f65a68a3-78a7-4542-8bf4-868ce0e91ec4" height="200"/> | <img src="https://github.com/user-attachments/assets/3b38f7c5-3b7e-4910-9222-bfa2c7cf236b" height="200"/> |

The demo app (`samples/client/swiftui/`) includes **10 pages** covering both static JSON demos and live agent connections. Each demo page includes an **info inspector** explaining what it demonstrates, and action-triggering pages display a **Resolved Action** log showing the resolved context payload.

genui demo: https://github.com/BBC6BAE9/genui

## Known Limitations

- Requires iOS 17+ / macOS 14+ (uses `@Observable` from the Observation framework).
- Custom (non-standard) component types are decoded but not rendered.
- Video playback uses `UIViewControllerRepresentable` on iOS; macOS uses a
  `VideoPlayer` fallback.
- No built-in Content Security Policy enforcement for image/video URLs —
  applications should validate URLs from untrusted agents.

## Security

**Important:** The sample code provided is for demonstration purposes and
illustrates the mechanics of A2UI and the Agent-to-Agent (A2A) protocol. When
building production applications, it is critical to treat any agent operating
outside of your direct control as a potentially untrusted entity.

All operational data received from an external agent — including its AgentCard,
messages, artifacts, and task statuses — should be handled as untrusted input.
For example, a malicious agent could provide crafted data in its fields (e.g.,
name, skills.description) that, if used without sanitization to construct
prompts for a Large Language Model (LLM), could expose your application to
prompt injection attacks.

Similarly, any UI definition or data stream received must be treated as
untrusted. Malicious agents could attempt to spoof legitimate interfaces to
deceive users (phishing), inject malicious scripts via property values (XSS),
or generate excessive layout complexity to degrade client performance (DoS). If
your application supports optional embedded content (such as iframes or web
views), additional care must be taken to prevent exposure to malicious external
sites.

**Developer Responsibility:** Failure to properly validate data and strictly
sandbox rendered content can introduce severe vulnerabilities. Developers are
responsible for implementing appropriate security measures — such as input
sanitization, Content Security Policies (CSP), strict isolation for optional
embedded content, and secure credential handling — to protect their systems and
users.

## License

MIT — see [LICENSE](LICENSE).
