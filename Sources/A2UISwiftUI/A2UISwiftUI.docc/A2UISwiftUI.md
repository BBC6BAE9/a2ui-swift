# ``A2UISwiftUI``

Render AI agent interfaces natively on Apple platforms using the A2UI open protocol.

@Metadata {
    @PageImage(
        purpose: icon,
        source: "a2ui-icon",
        alt: "A technology icon representing the A2UI SwiftUI renderer framework.")
    @PageColor(green)
    @TechnologyRoot
}

## Overview

A2UI is the community SwiftUI renderer for the [A2UI](https://github.com/google/A2UI) open protocol. It transforms declarative JSON payloads from AI agents into fully native SwiftUI interfaces across iOS, macOS, visionOS, watchOS, and tvOS — no WebView, no bridge layer.

The SDK is organized into focused modules:

- **A2UISwiftUI** — SwiftUI renderer and view layer (this module)
- **A2UISwiftCore** — Protocol processing, state management, component catalog
- **A2A** — A2A protocol client for connecting to live agents
- **Primitives** — Shared primitive types

```swift
let messages = try JSONDecoder().decode([A2uiMessage].self, from: data)

let viewModel = SurfaceViewModel(catalog: basicCatalog)
try viewModel.processMessages(messages)

A2UISurfaceView(viewModel: viewModel) { action in
    print("User triggered: \(action.name)")
}
```

### Featured

@Links(visualStyle: detailedGrid) {
    - <doc:GettingStarted>
}

## Topics

### Getting Started

- <doc:GettingStarted>

### Rendering

- ``A2UISurfaceView``
- ``A2UIChildView``
- ``SurfaceViewModel``

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

- ``CustomComponentCatalog``
- ``CatalogItem``
