# AGENTS.md

Instructions for AI coding agents working in this repository. (Mirrors `CLAUDE.md` — keep the two in sync when editing either.)

## What this is

Swift renderer for the [A2UI protocol](https://github.com/google/A2UI) — converts JSON UI descriptions streamed from AI agents into native Apple UI. SwiftUI is the feature-complete renderer; UIKit and AppKit are in development. The current spec version is **v0.9**; v0.8 lives in the deprecated `v_08` module and should not be extended.

## Commands

```bash
swift test                                                # run all tests
swift test --filter A2UISwiftUITests                      # run one test target
swift test --filter SurfaceViewModelTests                 # run one test class
swift test --filter SurfaceViewModelTests/testFoo         # run one test method
swift build                                               # build all targets
./build-docc.sh                                           # build DocC for all targets (macOS)
```

No Makefile. Only external dependency is `swift-foundation-icu` (used by `A2UISwiftCore` for ICU pluralization). Min platforms: iOS 17 / macOS 14 / tvOS 17 / watchOS 10 / visionOS 1.

## Module layout

Six SPM library products, organized by concern. Cross-module dependencies are explicit in `Package.swift` — respect them.

| Module | Depends on | What it owns |
|---|---|---|
| `Primitives` | — | Shared value types used across SDKs: `ChatMessage`, `Part`, `JSONValue`, `ToolDefinition` |
| `A2UISwiftCore` | `_FoundationICU` | **v0.9 protocol layer** — schema, data model, catalogs, expression evaluator, message processor, transport. UI-framework-agnostic. |
| `A2UISwiftUI` | `A2UISwiftCore` | v0.9 SwiftUI renderer (`A2UISurfaceView`, `SurfaceViewModel`) |
| `A2UIUIKit` | `A2UISwiftCore` | v0.9 UIKit renderer (iOS/tvOS/visionOS) — community extension via `A2UIUIKitComponent` |
| `A2UIAppKit` | `A2UISwiftCore` | v0.9 AppKit renderer (macOS) — community extension via `A2UIAppKitComponent` |
| `v_08` | — | **Deprecated** v0.8 renderer (`A2UIRendererView`, `SurfaceManager`). Bug-fix only; do not add features. |

## v0.9 architecture

The core insight: protocol logic (`A2UISwiftCore`) is fully decoupled from any UI framework. The SwiftUI/UIKit/AppKit renderers are thin layers on top of the same `SurfaceModel` + `ComponentNode` tree.

```
Agent JSON (JSONL stream)
    │
    ▼
A2UITransport / A2UIStreamParser      ◄── Sources/A2UISwiftCore/Transport
    │   (ServerToClientMessage values)
    ▼
MessageProcessor                       ◄── Sources/A2UISwiftCore/Processing
    │   • routes createSurface / updateDataModel / updateComponents / etc.
    │   • owns the SurfaceGroupModel (one per agent connection)
    ▼
SurfaceModel  ─── DataModel              ◄── PathSlot values (@Observable, per-path)
    │         ─── SurfaceComponentsModel ◄── component definitions (RawComponent)
    │
    ▼
SurfaceViewModel (SwiftUI-only)         ◄── Sources/A2UISwiftUI
    │   • rebuilds the ComponentNode tree on updateComponents
    │   • exposes @Observable componentTree
    ▼
A2UISurfaceView → A2UIComponentView (recursive switch on ComponentType)
    │
    ▼
A2UI{Component}.swift   (one per component, read-only)
    │   • reads props via dataContext.resolve(props.text)
    │   • reads style via @Environment(\.a2uiStyle)
    │   • reads/writes ui state on ComponentNode.uiState
```

**Two update paths with very different granularity** — keep them straight:

| Path | Trigger | Observable surface | Re-render scope |
|---|---|---|---|
| **Data layer** | `updateDataModel` message | `PathSlot.value` (per path) | Only views that resolved that path |
| **Structure layer** | `updateComponents` message | `ComponentNode.instance` / `componentTree` | The node whose `instance` changed (intended) |

Touching either of these without understanding the SwiftUI observation it triggers will silently regress performance. Before assigning to an `@Observable` property, check whether the value actually changed — `@Observable` does not de-duplicate.

## Key types (Core)

| File | Role |
|---|---|
| `Sources/A2UISwiftCore/State/SurfaceModel.swift` | Per-surface state container; owns `DataModel` + `SurfaceComponentsModel`; dispatches actions/errors via `EventEmitter`. Mirrors WebCore `SurfaceModel`. |
| `Sources/A2UISwiftCore/State/DataModel.swift` | Path-keyed value store backing `PathSlot` |
| `Sources/A2UISwiftCore/State/SurfaceGroupModel.swift` | Holds multiple surfaces for one agent connection |
| `Sources/A2UISwiftCore/Rendering/ComponentNode.swift` | `@Observable` resolved tree node — `instance`, `weight`, `children`, `uiState` |
| `Sources/A2UISwiftCore/Rendering/DataContext.swift` | View-side facade — `resolve(expr)` reads `PathSlot.value`; SwiftUI tracks the dependency automatically |
| `Sources/A2UISwiftCore/Processing/MessageProcessor.swift` | Routes `ServerToClientMessage` → SurfaceModel mutations |
| `Sources/A2UISwiftCore/Catalog/Types.swift` | `Catalog`, `FunctionInvoker` — what a renderer needs to invoke catalog functions |
| `Sources/A2UISwiftCore/BasicCatalog/BasicCatalog.swift` | The standard 18-component + 25-function catalog; mirror of the React renderer's `basicCatalog` |
| `Sources/A2UISwiftCore/Schema/ServerToClient.swift` | Decoders for incoming messages |
| `Sources/A2UISwiftCore/Schema/RawComponentExtensions.swift` | `RawComponent.typedProperties<T>()` — decode flat v0.9 props into a struct |
| `Sources/A2UISwiftCore/Transport/JsonBlockParser.swift` | Incremental JSONL → message parser used by streaming transports |

Many comments in `A2UISwiftCore` reference the WebCore (TypeScript) reference renderer. When changing behavior here, check the cited WebCore method — this package intentionally mirrors it.

## Adding or modifying a SwiftUI component

1. **Catalog entry** — if it's a standard component, the `BASIC_COMPONENT_NAMES` list in `Sources/A2UISwiftCore/BasicCatalog/Components/BasicComponents.swift` already includes it. For custom components, register via `CustomComponentCatalog` / `CustomComponentRegistry` (see `Sources/A2UISwiftUI/`).
2. **Typed props** — define a `Codable` struct and decode with `node.typedProperties(YourProps.self)`. All properties optional with sensible defaults.
3. **View** — add `Sources/A2UISwiftUI/Views/Components/A2UIYourComponent.swift`. Read styling from `@Environment(\.a2uiStyle)`, resolve dynamic values via the surface's `DataContext`, and never mutate the tree from inside the view.
4. **Wire** — add a `case` to `A2UIComponentView`.
5. **Test** — add a test in `Tests/A2UISwiftUITests/` (UI/rendering) or `Tests/A2UISwiftCoreTests/` (protocol/decoding).

## Rules

- **Use `@Observable`** for any new observable state. Never `ObservableObject` / `@Published` / `@StateObject`.
- **Guard assignments** before writing to an `@Observable` property. `existing.instance = new.instance` notifies SwiftUI even when the value is identical — check equality first when reconciling trees.
- **No hardcoded numerics** (spacing, radii, font sizes, colors) in component views — pull from `A2UIStyle`.
- **No `AnyView`** — use generics or `@ViewBuilder`.
- **No third-party dependencies** other than what's already in `Package.swift` (`swift-foundation-icu`).
- **Read-only component views.** All mutation goes through `SurfaceModel` / `SurfaceViewModel`. UI-only state lives on `ComponentNode.uiState`, which survives tree rebuilds (keyed by node id) so `LazyVStack` recycling is safe.
- **Locale-sensitive code** in `BasicCatalog/Functions` must match WebCore's behavior — see PR refs in commits like `feat: align locale support with WebCore PR #1427`.
- **Don't extend `v_08`.** New features land in the v0.9 modules.
- **Platform fallbacks** — when a control is unavailable on watchOS/tvOS, provide a functional fallback (e.g., wheel picker instead of segmented, +/− buttons instead of slider). Never render nothing.

## Commit convention

Repo uses [Conventional Commits](https://www.conventionalcommits.org/) — `cliff.toml` parses `feat:` / `fix:` / `perf:` / `refactor:` / `docs:` / `test:` / `ci:` into changelog sections. Releases are tagged `vX.Y.Z`; `.github/workflows/release.yml` auto-generates release notes via `git-cliff` on tag push.

## Tests

Six test targets, one per module. Tests live in `Tests/<ModuleName>Tests/`. Use `XCTAssertEqual` (shows actual vs expected on failure) over `XCTAssert`. When mirroring a WebCore test, name the test method to match so the correspondence is obvious.
