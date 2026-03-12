# A2UI SwiftUI Component Mapping Decisions

## Text
Maps `usageHint` (h1–h5, caption, body) to semantic `Font` and `AccessibilityHeadingLevel`. Supports inline Markdown via `AttributedString(markdown:)`. Styles overridable through `A2UIStyle.textStyles`. Caption defaults to `.secondary` color.

## Image
Uses `AsyncImage` for remote URLs. Sizing driven by `usageHint` (avatar/icon/header/etc.) with sensible defaults, overridable via `A2UIStyle.imageStyles`. `fit` maps to `contentMode` (.fit/.fill) + `clipped()`. Avatar uses `Circle()` clip; others use `RoundedRectangle`.

## Icon
Standard icons: SF Symbol via `A2UIStyle.sfSymbolName()` mapping (spec uses Material naming). Fixed 24×24 frame for grid alignment — matches web-core's `width:1em; height:1em` approach. Custom SVG path: delegates to `SVGIconView` which uses a custom `Layout` to size the Canvas based on font line height (adapts to Dynamic Type).

## Button
Uses native `Button` with `.borderedProminent` / `.bordered` for system HIG rendering. When `A2UIStyle.buttonStyles` provides a `ButtonVariantStyle` override, switches to custom drawing (plain style + manual background/padding/radius). The child is an arbitrary component tree (typically Text), not a plain string label.

## Card
Pure visual container with a single `child`. NOT interactive — hover/focus effects belong to the outer Button. Default appearance uses only SwiftUI system APIs with no magic numbers: `.padding()`, `.background(.background)`, `.clipShape(.rect(cornerRadius:style:))` with continuous squircle. No shadow by default — Apple system cards rely on background contrast, not drop shadows. All styling overridable via `.a2uiCardStyle(...)`.

## Column
`VStack`. `distribution` (main-axis) via Spacer-based layout in `a2uiDistributedContent`. `alignment` (cross-axis) maps to `HorizontalAlignment`; defaults to stretch. `weight` handled globally by `WeightModifier`.

## Row
`HStack`. Same layout model as Column but with `VerticalAlignment` for cross-axis. `distribution` and `weight` handled identically.

## List
`ScrollView` + `LazyVStack` / `LazyHStack`. `direction` switches between vertical (default) and horizontal. Pure layout container — no tap/hover/focus handling; interaction is the child's responsibility.

## Divider
Directly maps to `SwiftUI.Divider()`. The spec's `axis` property is intentionally ignored — SwiftUI's Divider auto-adapts orientation based on parent container.

## TextField
Each `textFieldType` maps to the most appropriate native control:
- `shortText` / default → `TextField` + `.roundedBorder`
- `obscured` → `SecureField`
- `number` → `TextField` + `.keyboardType(.decimalPad)`
- `longText` → `TextEditor` (fallback to `TextField` on watchOS/tvOS)
- `date` → delegated to `DateTimeInput`

Supports `validationRegexp` for client-side regex validation. No hardcoded spacing, padding, colors, or corner radii.

## CheckBox
Maps to `Toggle` without specifying `.toggleStyle()`, letting `.automatic` work per platform. This is intentional — not specifying a style means the UI automatically follows platform evolution (e.g. macOS moving toward iOS-style switches). Platform behavior: iOS/visionOS = switch, macOS = checkbox (evolving), watchOS = switch, tvOS = button-toggle.

## ChoicePicker (MultipleChoice)
Rendering varies by variant, selection mode, and platform:
- `maxAllowedSelections == 1`: chips → horizontal button group; macOS multi-word labels → `Picker(.radioGroup)`; otherwise → menu Picker
- Multi-select: checkbox → inline checkmark rows; chips → `FlowLayout` capsule buttons
- `filterable = true`: sheet + `.searchable()` + list/chips inside
- tvOS (all variants): `NavigationLink` → secondary page with checkmark list

## Slider
Uses `SwiftUI.Slider` directly — general-purpose numeric input, not a media scrubber. tvOS: `Slider` unavailable, falls back to +/− Button pair with `ProgressView`. Step size is 1/20 of the range.

## DateTimeInput
Maps to `DatePicker(selection:displayedComponents:)` with `.date` and/or `.hourAndMinute` based on `enableDate`/`enableTime`. tvOS: `DatePicker` unavailable, falls back to read-only text display.

## Tabs
- ≤5 tabs → `Picker(.segmented)` (Settings App pattern)
- &gt;5 tabs → horizontal `ScrollView` + `Button(.bordered)` row (Music Browse pattern)
- watchOS: `.segmented` unavailable, falls back to `.wheel`

## Modal
Entry point renders as-is; interaction handled by the Button inside it. Content presented via `.sheet` with `NavigationStack` + `ScrollView`. Close button uses `.cancellationAction` placement. iOS/macOS/visionOS: `.presentationDetents([.medium, .large])` + `.presentationBackground(.regularMaterial)`. watchOS/tvOS: plain `.sheet`.

## Video
`AVPlayerViewController` in `ScrollView` + `LazyVStack` causes severe scroll jank. Solution: singleton `SharedPlayerController` — one `AVPlayerViewController` (iOS/tvOS/visionOS) or `AVPlayerView` (macOS) shared across all Video components. Inactive videos show a poster (async first-frame thumbnail + play button). Tapping activates the singleton; only one Video plays at a time. Thumbnails loaded via `Task.detached` (survives LazyVStack recycling), cached on `VideoUIState`. watchOS: static placeholder.

## AudioPlayer
Custom audio player UI with progress bar, matching `<audio controls>` functionality. Uses `AVPlayer` with time observation for progress tracking. Playback state (`isPlaying`, `currentTime`, `duration`) stored in `AudioPlayerUIState` for persistence across tree rebuilds. watchOS: AVKit unavailable, placeholder only.
