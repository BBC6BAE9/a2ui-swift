# Getting Started with A2UI

Add the A2UI renderer to your SwiftUI app and display your first agent surface.

@Metadata {
    @PageImage(
        purpose: card,
        source: "gettingStarted-card",
        alt: "A collection of native SwiftUI cards rendered from A2UI agent JSON payloads.")
}

## Overview

A2UI lets AI agents describe rich, interactive UIs through declarative JSON — and this renderer turns that JSON into fully native SwiftUI views. Getting started takes three steps: add the package, decode messages, and render them.

### Install the Package

Add A2UI to your project via Swift Package Manager.

**In `Package.swift`:**

```swift
dependencies: [
    .package(url: "https://github.com/BBC6BAE9/a2ui-swiftui", from: "0.1.0"),
],
targets: [
    .target(name: "YourApp", dependencies: ["A2UISwiftUI"]),
]
```

**In Xcode:** File → Add Package Dependencies → paste the repository URL.

### Render Static JSON

The simplest integration decodes a JSON payload and passes it to ``A2UIRendererView`` via a ``SurfaceViewModel``:

```swift
import A2UISwiftUI

let messages = try JSONDecoder().decode(
    [ServerToClientMessage].self,
    from: jsonData
)

let manager = SurfaceManager()
try manager.processMessages(messages)

struct ContentView: View {
    let manager: SurfaceManager

    var body: some View {
        A2UIRendererView(manager: manager)
    }
}
```

``SurfaceManager`` routes each ``ServerToClientMessage`` to the correct ``SurfaceViewModel`` by `surfaceId`. The view layer stays purely declarative — no message processing logic in the view.

### Stream from a JSONL Endpoint

Agents typically send A2UI messages as a JSONL stream — one JSON object per line. Use ``JSONLStreamParser`` to consume the stream and feed messages to the manager:

```swift
import A2UISwiftUI
import A2A

let parser = JSONLStreamParser()
let manager = SurfaceManager()

let (bytes, _) = try await URLSession.shared.bytes(for: request)
for try await message in parser.messages(from: bytes) {
    try manager.processMessage(message)
}

A2UIRendererView(manager: manager)
```

### Connect to a Live A2A Agent

For a full agent-to-agent connection, use ``A2AClient`` to discover the agent endpoint from its card and send queries:

```swift
import A2UISwiftUI
import A2A

let client = try await A2AClient.fromAgentCardURL(
    URL(string: "http://localhost:10003/.well-known/agent-card.json")!
)

let manager = SurfaceManager()

// Non-streaming
let result = try await client.sendText("Show me a contact card")
try manager.processMessages(result.messages)

// Streaming (SSE)
for try await event in client.sendTextStream("Show me a dashboard") {
    if case .result(let result) = event {
        try manager.processMessages(result.messages)
    }
}

A2UIRendererView(manager: manager) { action in
    Task {
        try await client.sendAction(action, surfaceId: "main")
    }
}
```

### Handle User Actions

When a user taps a button or interacts with a form, the renderer emits a ``ResolvedAction`` through the `onAction` callback:

```swift
A2UIRendererView(manager: manager) { action in
    print("Action: \(action.name)")
    print("Source: \(action.sourceComponentId)")
    print("Context: \(action.context)")
}
```

### Customize Appearance

Override the default look and feel using SwiftUI environment modifiers powered by ``A2UIStyle``:

```swift
A2UIRendererView(manager: manager)
    .a2uiTextStyle(for: .h1, font: .system(size: 48), weight: .black)
    .a2uiButtonStyle(for: .primary, backgroundColor: .blue, cornerRadius: 12)
    .a2uiCardStyle(cornerRadius: 16, shadowRadius: 8)
    .a2uiIcon(.home, systemName: "house.fill")
```

### Register Custom Components

Extend the renderer with your own component types using ``CustomComponentRegistry``:

```swift
A2UIRendererView(manager: manager)
    .a2uiCustomComponents { typeName, node, children, viewModel in
        switch typeName {
        case "Chart":
            return AnyView(MyChartView(node: node, viewModel: viewModel))
        default:
            return nil
        }
    }
```
