# A2UI-Swift

![a2ui](./a2ui.png)

## What is A2UI-Swift?

[A2UI](https://github.com/google/A2UI) is an open protocol that lets AI agents generate rich, interactive user interfaces through a declarative JSON format — not executable code. An agent describes *what* to render; the renderer decides *how* using native platform controls. 

A2UI-Swift is a Swift-based renderer for A2UI that supports all Apple UI frameworks. The `SwiftUI` implementation is feature-complete, while `UIKit` and `AppKit` support are currently under active development. Listed on the [official A2UI ecosystem page](https://a2ui.org/ecosystem/renderers/).

```
Agent → JSON payload → A2UISurfaceView / A2UIRendererView → Native UI
```

## Installation

Add this package to your project via Swift Package Manager:

**In `Package.swift`:**

```swift
dependencies: [
    .package(url: "https://github.com/BBC6BAE9/a2ui-swift", from: "0.1.0"),
],
```

## Modules

The package is organized into six independent library products:

| Module | Purpose |
|--------|---------|
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

The A2A protocol client has been extracted into its own package — [a2a-swift](https://github.com/BBC6BAE9/a2a-swift) — and is consumed here as a remote Swift Package Manager dependency.

## Testing

```bash
swift test
```
