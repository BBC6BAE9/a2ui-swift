<div align="center">

# A2UI-Swift

**Let your AI agent draw native Apple UI — SwiftUI, UIKit, and AppKit.**

![a2ui](./a2ui.png)

[![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS-007AFF?logo=apple)](#requirements)
[![SPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen)](#installation)
[![Documentation](https://img.shields.io/badge/DocC-documentation-blue?logo=swift&logoColor=white)](https://bbc6bae9.github.io/a2ui-swift/documentation/)
[![A2UI Spec](https://img.shields.io/badge/A2UI%20spec-v0.9-8A2BE2)](https://github.com/a2ui-project/a2ui)
[![License](https://img.shields.io/github/license/BBC6BAE9/a2ui-swift)](LICENSE)
[![Stars](https://img.shields.io/github/stars/BBC6BAE9/a2ui-swift?style=social)](https://github.com/BBC6BAE9/a2ui-swift/stargazers)

</div>

[A2UI](https://github.com/a2ui-project/a2ui) is an open protocol from Google that lets AI agents generate rich, interactive user interfaces through declarative JSON — not executable code. The agent describes **what** to render; the renderer decides **how**, using real native platform controls.

**A2UI-Swift** is the Swift renderer for the entire Apple ecosystem, listed on the [official A2UI ecosystem page](https://a2ui.org/ecosystem/renderers/).

```
Agent  ──▶  JSON payload  ──▶  A2UI-Swift  ──▶  Native Apple UI
```

## ✨ Highlights

- 🧩 **Three native renderers, one protocol** — SwiftUI (`A2UISurfaceView`), UIKit (iOS / tvOS / visionOS), and AppKit (macOS), all aligned to A2UI spec v0.9 with matching feature sets.
- 📦 **17 built-in components** — Text, Image, Icon, Button, TextField, CheckBox, Slider, ChoicePicker, DateTimeInput, Row/Column Stacks, List, Card, Tabs, Modal, Divider, AudioPlayer, and Video.
- 🔌 **Extensible by design** — register your own components through the custom catalog (`A2UIUIKitComponent` / `A2UIAppKitComponent`) and mix them freely with the built-ins.
- 🔄 **Live two-way data binding** — expression bindings, input write-back, and template-driven lists react to streaming agent updates in place.
- 🛡️ **Safe by construction** — agents send data, never code. Everything renders through vetted native controls.
- 🌍 **Localization built in** — ICU-backed number, currency, date formatting, and pluralization.
- ✅ **Battle-tested** — 300+ tests across the schema, data model, expression engine, and all three renderers.

## 🚀 Quick Start

### SwiftUI

```swift
import A2UISwiftUI

@State var vm = SurfaceViewModel(catalog: basicCatalog)

// Feed messages from your agent transport:
try vm.processMessages(messages)

// Render — with an optional action handler:
A2UISurfaceView(viewModel: vm) { action in
    print("Action: \(action.name)")
}
```

### UIKit / AppKit

```swift
import A2UISwiftCore
import A2UIUIKit        // or: import A2UIAppKit on macOS

let host = A2UISurfaceHostView()

let processor = MessageProcessor(catalogs: [catalog]) { action in
    print("Action: \(action.name)")
}
processor.processMessages(messages)

if let surface = processor.model.getSurface(surfaceId) {
    host.render(surface: surface, rootComponentId: "root")
}
```

## 📦 Installation

Add the package via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/BBC6BAE9/a2ui-swift", from: "0.3.0"),
],
```

### Requirements

| Platform | Minimum version |
|----------|-----------------|
| iOS / tvOS | 17.0 |
| macOS | 14.0 |
| watchOS | 10.0 |
| visionOS | 1.0 |

## 🧱 Modules

The package ships six independent library products — pull in only what you need:

| Module | Purpose |
|--------|---------|
| **A2UISwiftCore** | v0.9 shared protocol layer — schema, data model, catalog system, expression parser, transport |
| **A2UISwiftUI** | v0.9 SwiftUI renderer via `A2UISurfaceView` + `SurfaceViewModel` |
| **A2UIUIKit** | v0.9 UIKit renderer for iOS, tvOS, and visionOS via `A2UISurfaceHostView` |
| **A2UIAppKit** | v0.9 AppKit renderer for macOS via `A2UISurfaceHostView` |
| **Primitives** | Shared primitive types — `ChatMessage`, `Part`, `JSONValue`, `ToolDefinition`, etc. |
| ~~**v_08**~~ | ⚠️ **Deprecated** — v0.8 renderer via `A2UIRendererView` with `SurfaceManager` |

Full API reference for every module is published at the [DocC documentation site](https://bbc6bae9.github.io/a2ui-swift/documentation/).

## 📱 Sample Apps

### travel_app — generative AI, end to end

A full-featured travel app showing the v0.9 renderer with AI client integration, custom catalog components, and real generative AI interactions. The A2A protocol client lives in its own package — [a2a-swift](https://github.com/BBC6BAE9/a2a-swift) — consumed as a remote SPM dependency.

### sample_0.9 — one demo per renderer

Minimal demos for each framework, side by side: `samples/sample_0.9/A2UISwiftUIDemo`, `A2UIUIKitDemo`, and `A2UIAppKitDemo`. The fastest way to see the same JSON payload rendered by SwiftUI, UIKit, and AppKit.

### sample_0.8 — the original demo (legacy)

Demo app for the deprecated v0.8 renderer: `samples/sample_0.8/A2UIDemoApp.xcodeproj`. Includes static JSON demos and live A2A agent connections; each page has an **info inspector**, and action-triggering pages show a **Resolved Action log** with the full context payload.

|                             info                             |                          action log                          |                            genui                             |
| :----------------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: |
| <img src="https://github.com/user-attachments/assets/1cefe139-3266-4b57-8f2e-d4d2046b3ae6" height="200"/> | <img src="https://github.com/user-attachments/assets/f65a68a3-78a7-4542-8bf4-868ce0e91ec4" height="200"/> | <img src="https://github.com/user-attachments/assets/3b38f7c5-3b7e-4910-9222-bfa2c7cf236b" height="200"/> |

## 🧪 Testing

```bash
swift test
```

## 🤝 Contributing

Issues and pull requests are welcome — whether it's a new catalog component, a renderer fix, or a sample app. If A2UI-Swift helps you ship, a ⭐️ goes a long way.

## 📄 License

[MIT](LICENSE)

<div align="center">
<sub>Built for the <a href="https://github.com/a2ui-project/a2ui">A2UI</a> ecosystem · Swift on every Apple platform</sub>
</div>
