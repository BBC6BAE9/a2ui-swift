# Contributing to A2UI SwiftUI Renderer

Thank you for your interest in contributing. This guide covers everything you need to get started.

## Table of Contents

- [Getting Started](#getting-started)
- [Running Tests](#running-tests)
- [Project Structure](#project-structure)
- [Adding a Component](#adding-a-component)
- [Good First Issues](#good-first-issues)
- [Submitting a Pull Request](#submitting-a-pull-request)

---

## Getting Started

```bash
git clone https://github.com/BBC6BAE9/a2ui-swiftui.git
cd a2ui-swiftui
open A2UIDemoApp/A2UIDemoApp.xcodeproj  # optional: run the demo app
```

No dependencies beyond the Swift toolchain. The package resolves entirely from the standard library and Apple SDKs.

---

## Running Tests

```bash
swift test
```

All 87 tests should pass. The test suite covers message decoding, component parsing, data binding, JSONL streaming, incremental surface updates, and Codable round-trips.

To run a specific test file:

```bash
swift test --filter MessageDecodingTests
```

---

## Project Structure

```
Sources/A2UI/
├── Models/
│   ├── Messages.swift          # ServerToClientMessage, ClientToServerMessage
│   ├── Components.swift        # A2UIComponent (tagged union of all 18 types)
│   ├── ComponentTypes.swift    # Per-component model structs
│   └── Primitives.swift        # Shared value types (Color, Font, Action, etc.)
├── Processing/
│   ├── SurfaceManager.swift    # @Observable state — owns the component tree
│   └── JSONLStreamParser.swift # Async JSONL → ServerToClientMessage stream
├── Views/
│   ├── A2UIComponentView.swift # Top-level switch — dispatches to component views
│   └── Components/             # One file per component (A2UIText.swift, etc.)
│       └── COMPONENT_DECISIONS.md  # Design rationale for every component
├── Styling/
│   └── A2UIStyle.swift         # Theme system — passed via SwiftUI Environment
├── Networking/
│   └── A2AClient.swift         # JSON-RPC over HTTP for A2A agent connections
└── A2UIRenderer.swift          # Public API — A2UIRendererView (3 initializers)
```

---

## Adding a Component

The A2UI spec defines all standard components. If you're implementing a missing non-standard extension or improving an existing component, follow these steps:

### 1. Add the model (if new)

In `Sources/A2UI/Models/ComponentTypes.swift`, add a `Codable` struct for the new component. Follow the existing pattern — all properties should be optional with sensible defaults where the spec allows.

### 2. Register the type

In `Sources/A2UI/Models/Components.swift`, add a case to the `A2UIComponent` enum and handle it in the `init(from:)` decoder.

### 3. Create the view

Create `Sources/A2UI/Views/Components/A2UIYourComponent.swift`. Key conventions:

- **No hardcoded colors, padding, or corner radii** — pull from `A2UIStyle` via `@Environment`
- **Use idiomatic SwiftUI** — prefer system controls over custom drawing
- **Platform conditionals** via `#if os(watchOS)` / `#if os(tvOS)` for unavailable APIs
- **Document non-obvious decisions** — add an entry to `COMPONENT_DECISIONS.md`

### 4. Wire up the renderer

In `Sources/A2UI/Views/A2UIComponentView.swift`, add a `case` for the new component in the main `switch`.

### 5. Write tests

Add test cases in `Tests/A2UITests/MessageDecodingTests.swift` (or a new file if warranted). At minimum, test:
- Successful decode from JSON
- Default values when optional fields are absent
- Codable round-trip

---

## Good First Issues

If you're new to the codebase, these are well-scoped starting points:

| Area | Task |
|------|------|
| **Tests** | Add edge-case JSON inputs to `TestData/` and corresponding decode tests |
| **Icon mapping** | Expand the Material → SF Symbol mapping table in `A2UIIcon.swift` |
| **Styling** | Expose additional `A2UIStyle` properties for existing components |
| **Accessibility** | Audit components for missing `.accessibilityLabel` / `.accessibilityHint` annotations |
| **Documentation** | Add or improve inline doc comments (`///`) on public API types |
| **tvOS** | Improve fallback UIs for components with limited tvOS support |

---

## Submitting a Pull Request

1. **Fork** the repo and create a branch from `main`
2. **Make your changes** — keep commits focused and the diff readable
3. **Run the tests** — `swift test` must pass with 0 failures
4. **Open a PR** — describe what you changed and why; link any relevant A2UI spec sections

For significant changes (new components, API changes, architectural decisions), open an issue first to align on approach before writing code.

---

## Code Style

- Follow Swift API Design Guidelines
- Use `@Observable` for any new state-holding types (not `ObservableObject`)
- Avoid `AnyView` — prefer generics or `@ViewBuilder`
- No third-party dependencies

---

Questions? Open an issue or start a Discussion.
