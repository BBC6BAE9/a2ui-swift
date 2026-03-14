# AGENTS.md

Instructions for AI coding agents working in this repository.

## What this project is

A SwiftUI renderer for the [A2UI protocol](https://github.com/google/A2UI). It takes `ServerToClientMessage` JSON streams from AI agents and renders them as fully native Apple platform UIs. The public surface is one view: `A2UIRendererView`.

## Commands

```bash
swift test                          # run all tests (must pass with 0 failures)
swift test --filter <TestName>      # run a single test class
open A2UIDemoApp/A2UIDemoApp.xcodeproj  # open demo app in Xcode
```

No build script. No Makefile. No dependencies beyond the Swift toolchain and Apple SDKs.

## Architecture

```
A2UIRendererView          ← only public API (3 initializers)
    └── SurfaceManager    ← @Observable, owns all surface state
        └── SurfaceViewModel (per surface)
            └── ComponentNode tree (pre-resolved, rebuilt on each update)
                └── A2UIComponentView (recursive renderer, read-only)
                    └── A2UI{Component}.swift (one file per component type)
```

**Key invariant:** `A2UIComponentView` and all component views are read-only. They never mutate state directly. All tree mutations go through `SurfaceManager`.

**UI state** (e.g., selected tab index, modal presentation) lives on `ComponentNode.uiState` — an `@Observable` object that is migrated by ID across tree rebuilds, so it survives `LazyVStack` recycling.

**Styling** flows through the SwiftUI `Environment` as `A2UIStyle`. Never pass style as an explicit parameter to component views.

## File map

| Path | Purpose |
|------|---------|
| `Sources/A2UI/A2UIRenderer.swift` | Public API — `A2UIRendererView` |
| `Sources/A2UI/Models/Messages.swift` | `ServerToClientMessage`, `ClientToServerMessage` |
| `Sources/A2UI/Models/Components.swift` | `A2UIComponent` tagged union |
| `Sources/A2UI/Models/ComponentTypes.swift` | Per-component `Codable` structs |
| `Sources/A2UI/Models/Primitives.swift` | Shared value types (`Color`, `Action`, etc.) |
| `Sources/A2UI/Processing/SurfaceManager.swift` | `@Observable` state, message processing |
| `Sources/A2UI/Processing/JSONLStreamParser.swift` | Async JSONL → message stream |
| `Sources/A2UI/Views/A2UIComponentView.swift` | Top-level component switch |
| `Sources/A2UI/Views/Components/` | One `.swift` per component |
| `Sources/A2UI/Views/Components/COMPONENT_DECISIONS.md` | Design rationale per component |
| `Sources/A2UI/Styling/A2UIStyle.swift` | Theme system + Environment integration |
| `Sources/A2UI/Networking/A2AClient.swift` | JSON-RPC over HTTP |
| `Tests/A2UITests/` | 87 tests across 5 files |

## Rules

### Do
- Use `@Observable` for any new state-holding types
- Use `@Environment(\.a2uiStyle)` to read styling — never hardcode colors, padding, or corner radii
- Use `#if os(watchOS)` / `#if os(tvOS)` for platform-specific fallbacks
- Prefer system SwiftUI controls over custom drawing
- Keep `A2UIComponentView` and child views read-only
- Add an entry to `COMPONENT_DECISIONS.md` when making a non-obvious implementation choice
- Write tests for every new decode path: happy path, missing optional fields, Codable round-trip

### Don't
- Use `ObservableObject` / `@StateObject` / `@Published` — this codebase uses `@Observable`
- Use `AnyView` — use generics or `@ViewBuilder`
- Add third-party dependencies
- Hardcode any numeric values (spacing, radii, font sizes) — pull from `A2UIStyle`
- Mutate component tree state from inside a view
- Skip `swift test` before completing a task

## Adding a component

1. **Model** — add a `Codable` struct in `ComponentTypes.swift`. All properties optional with sensible defaults.
2. **Register** — add a case to `A2UIComponent` in `Components.swift` and handle it in `init(from:)`.
3. **View** — create `Sources/A2UI/Views/Components/A2UI{Name}.swift`. Follow the conventions above.
4. **Wire** — add a `case` in `A2UIComponentView.renderComponent(_:)`.
5. **Test** — add decode tests in `Tests/A2UITests/MessageDecodingTests.swift` or a new file.
6. **Document** — add an entry to `COMPONENT_DECISIONS.md`.

## Testing conventions

Test files live in `Tests/A2UITests/`. JSON fixtures go in `Tests/A2UITests/TestData/`.

Each test file has a clear scope:
- `MessageDecodingTests.swift` — JSON → model decode
- `DataBindingTests.swift` — data binding / path resolution
- `PrimitivesTests.swift` — primitive value types
- `MultipleChoiceLogicTests.swift` — selection logic
- `TextFieldValidationTests.swift` — regex validation

When adding tests, match the existing file structure. Prefer small, focused test functions over large ones. Use `XCTAssertEqual` rather than `XCTAssert` so failures show the actual vs expected values.

## Platform support matrix

| Feature | iOS | macOS | visionOS | watchOS | tvOS |
|---------|-----|-------|----------|---------|------|
| `@Observable` | ✅ 17+ | ✅ 14+ | ✅ 1+ | ✅ 10+ | ✅ 17+ |
| `AVPlayerViewController` | ✅ | ❌ (use `AVPlayerView`) | ✅ | ❌ | ✅ |
| `DatePicker` | ✅ | ✅ | ✅ | ✅ | ❌ (fallback: read-only text) |
| `Slider` | ✅ | ✅ | ✅ | ✅ | ❌ (fallback: +/− buttons) |
| `TextEditor` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `.segmented` Picker | ✅ | ✅ | ✅ | ❌ (fallback: `.wheel`) | ❌ |

When a control is unavailable on a platform, provide a functional fallback — never silently render nothing.
