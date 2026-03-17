# ``A2UI``

Render AI agent interfaces natively on Apple platforms using the A2UI protocol and SwiftUI.

@Metadata {
    @PageImage(
        purpose: icon,
        source: "a2ui-icon",
        alt: "A technology icon representing the A2UI SwiftUI renderer framework.")
    @PageColor(green)
}

## Overview

A2UI is the community SwiftUI renderer for the [A2UI](https://github.com/google/A2UI) open protocol. It transforms declarative JSON payloads from AI agents into fully native SwiftUI interfaces across iOS, macOS, visionOS, watchOS, and tvOS — no WebView, no bridge layer.

The public API centers on a single view — ``A2UIRendererView`` — backed by a ``SurfaceManager`` that routes incoming ``ServerToClientMessage`` payloads to the correct ``SurfaceViewModel``. You can feed messages from static JSON, a JSONL stream via ``JSONLStreamParser``, or a live A2A agent connection via ``A2AClient``.

Every A2UI component maps to its idiomatic SwiftUI counterpart (`HStack`, `LazyVStack`, `DatePicker`, `.sheet`, etc.), giving you native performance, platform adaptivity, accessibility, Dark Mode, and Dynamic Type for free.

```swift
// Decode A2UI messages from a JSON payload
let messages = try JSONDecoder().decode([ServerToClientMessage].self, from: data)

let manager = SurfaceManager()
try manager.processMessages(messages)

A2UIRendererView(manager: manager) { action in
    print("User triggered: \(action.name)")
}
```

### Featured

@Links(visualStyle: detailedGrid) {
    - <doc:GettingStarted>
    - <doc:A2UIDemoApp>
}

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:A2UIDemoApp>
- ``A2UIRendererView``
- ``SurfaceManager``

### Protocol Messages

- ``ServerToClientMessage``
- ``BeginRenderingMessage``
- ``SurfaceUpdateMessage``
- ``DataModelUpdateMessage``
- ``DeleteSurfaceMessage``

### Streaming and Parsing

- ``JSONLStreamParser``
- ``A2AClient``
- ``SendResult``
- ``StreamEvent``
- ``A2ATaskState``
- ``AgentCardInfo``

### Surface State

- ``SurfaceViewModel``
- ``ComponentNode``
- ``DataStore``

### Component Model

- ``RawComponentInstance``
- ``RawComponentPayload``
- ``ComponentType``
- ``ChildrenReference``
- ``TemplateReference``

### Actions and Data Binding

- ``Action``
- ``ActionContextEntry``
- ``ResolvedAction``

### Styling and Theming

- ``A2UIStyle``
- ``A2UIStyle/TextVariant``
- ``A2UIStyle/TextStyle``
- ``A2UIStyle/ButtonVariant``
- ``A2UIStyle/ButtonVariantStyle``
- ``A2UIStyle/ImageVariant``
- ``A2UIStyle/ImageStyle``
- ``A2UIStyle/CardStyle``
- ``A2UIStyle/IconName``

### Custom Components

- ``CustomComponentRenderer``

### Error Handling

- ``A2UIClientError``
- ``A2AError``
