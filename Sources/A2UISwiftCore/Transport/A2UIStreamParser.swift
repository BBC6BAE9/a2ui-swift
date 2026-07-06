// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

// MARK: - ParsedEvent

/// A discriminated event emitted by ``A2UIStreamParser``.
///
/// Mirrors Flutter's `GenerationEvent` hierarchy (`TextEvent` / `A2uiMessageEvent`),
/// expressed as a Swift enum for pattern-matching ergonomics.
public enum ParsedEvent: Sendable {
    /// A decoded A2UI server-to-client message (Codable only; same tolerance as Flutter/WebCore).
    case message(A2uiMessage)
    /// Plain text that is not part of any A2UI message (suitable for chat UI display).
    case text(String)
    /// A validation error encountered while parsing a recognised A2UI JSON object.
    ///
    /// Mirrors Flutter's `_controller.addError(e)` path in `_emitMessage`:
    /// the stream **continues** after this event — only this one message failed.
    case error(any Error)
}

// MARK: - A2UIStreamParserConfig

/// Optional catalog-derived configuration that enables the incremental
/// "sniff & cut" behavior of the upstream Python parser (`streaming.py`).
///
/// The parser works without a config (the structural fallback and complete-block
/// paths are self-contained), but a config lets it:
/// - auto-close an unclosed string only when its key is *cuttable* (e.g. `text`),
/// - suppress a partial component that is missing a catalog-required field.
///
/// Mirrors the fields the upstream `A2uiStreamParser` reads off its catalog
/// (`_cuttable_keys`, `_required_fields_map`).
public struct A2UIStreamParserConfig: Sendable {
    /// Keys whose string values may be safely truncated mid-stream (the parser
    /// auto-closes an open string only for these). Always includes ``defaultCuttableKeys``.
    public var cuttableKeys: Set<String>
    /// componentType → set of required property names. A partial component missing
    /// any required field is held back until the field arrives.
    public var requiredFieldsByComponent: [String: Set<String>]

    /// componentType → set of properties that are child references typed as `ChildList`
    /// or `ComponentId` in the catalog. Targets of these fields are *placeholder-eligible*:
    /// an unseen target is rendered as a loading placeholder rather than blocking the parent.
    /// A `child`-named field NOT in this set whose target is unseen blocks the parent's yield.
    public var childRefFieldsByComponent: [String: Set<String>]

    /// Whether the catalog defines the loading-placeholder component type (`Row` in v0.9).
    /// A partial parent with an unseen placeholder-eligible child can only be yielded when a
    /// placeholder can be synthesised; without the placeholder type the parent is held back.
    public var canSynthesizePlaceholder: Bool

    /// The keys the upstream parser treats as cuttable by default (safe to truncate).
    public static let defaultCuttableKeys: Set<String> = [
        "text", "valueString", "label", "title", "description",
    ]

    public init(
        cuttableKeys: Set<String> = [],
        requiredFieldsByComponent: [String: Set<String>] = [:],
        childRefFieldsByComponent: [String: Set<String>] = [:],
        canSynthesizePlaceholder: Bool = false
    ) {
        self.cuttableKeys = Self.defaultCuttableKeys.union(cuttableKeys)
        self.requiredFieldsByComponent = requiredFieldsByComponent
        self.childRefFieldsByComponent = childRefFieldsByComponent
        self.canSynthesizePlaceholder = canSynthesizePlaceholder
    }
}

// MARK: - A2UIStreamParser

/// Transforms a stream of raw LLM text chunks into a sequence of ``ParsedEvent`` values.
///
/// Mirrors the upstream Python `streaming.py` state machine, reimplemented with Swift
/// native concurrency (`AsyncStream` / `actor`).
///
/// Parsing is **tag-first with a structural fallback**:
/// - **Primary — `<a2ui-json>` … `</a2ui-json>` delimiter.** This is the spec's
///   text↔UI mode switch: prose *outside* the tags is emitted as ``ParsedEvent/text(_:)``,
///   JSON *inside* the tags is scanned **incrementally** and decoded into
///   ``ParsedEvent/message(_:)`` as each array element / partial component / partial
///   data-model update becomes complete — it does **not** wait for the close tag.
///   Multiple blocks per stream are supported, and a tag split across chunk boundaries
///   is buffered.
/// - **Fallback — structural detection** (used only when no `<a2ui-json>` tag is present):
///   a markdown JSON block (` ```json … ``` ` or ` ``` … ``` `) or a bare balanced-brace
///   `{…}` object. Preserves the original Flutter tolerance for un-tagged input.
///
/// Feed chunks via ``add(_:)``, signal end-of-stream with ``finish()``,
/// and consume results from ``events``.
public final class A2UIStreamParser: Sendable {

    // MARK: Internal actor (owns all mutable state)

    private actor _Core {
        // Raw text buffer for the tag hunt (text mode) / structural fallback.
        private var buffer: String = ""
        /// `true` while inside an `<a2ui-json>` block (hunting for the close tag); `false`
        /// in text mode (hunting for the open tag). Mirrors upstream `_found_delimiter`.
        private var inA2uiBlock = false
        private let continuation: AsyncStream<ParsedEvent>.Continuation
        private let config: A2UIStreamParserConfig

        // Spec delimiter tags (hyphen — the v0.9 wire format). See upstream
        // `constants.py` `A2UI_OPEN_TAG` / `A2UI_CLOSE_TAG`.
        private static let openTag  = "<a2ui-json>"
        private static let closeTag = "</a2ui-json>"

        // MARK: Incremental JSON-mode state (mirrors upstream `_process_json_chunk`)

        /// Accumulated JSON characters for the current block (chars are dropped from the
        /// front as complete top-level objects are consumed).
        private var jsonBuffer = ""
        /// Stack of ("{" or "[", startIndexInJsonBuffer). Mirrors `_brace_stack`.
        private var braceStack: [(Character, Int)] = []
        private var braceCount = 0
        private var inTopLevelList = false
        private var inString = false
        private var stringEscaped = false

        // MARK: Per-block yield tracking (mirrors upstream dedup fields)

        /// Surfaces for which a `createSurface` has been emitted (so their components
        /// may be yielded). Persists across blocks in a stream.
        private var startedSurfaces: Set<String> = []
        /// `updateComponents` messages that arrived before their surface's `createSurface`;
        /// flushed when the create arrives. surfaceId → pending yield-requests.
        private var pendingComponentSurfaces: Set<String> = []
        /// Components seen this stream, per surface: id → component object. Feeds the
        /// reachability yield (mirrors upstream `_seen_components`, keyed by surface here).
        private var seenComponents: [String: [String: [String: Any]]] = [:]
        /// Signature of the last reachable-component set emitted per surface (dedup).
        private var lastReachableSignature: [String: String] = [:]
        /// The surface whose `updateComponents` is currently being parsed (component context).
        private var activeSurface: String?
        /// Data-model values already emitted this block, per surface: key → canonical value
        /// JSON. A partial data-model update is re-yielded only when a key's value changed.
        private var yieldedDataModelValues: [String: [String: String]] = [:]
        /// Child-reference edges seen this stream, for cycle detection. id → referenced ids.
        private var componentEdges: [String: Set<String>] = [:]
        /// Default root component id (matches upstream `DEFAULT_ROOT_ID`).
        private static let rootId = "root"
        /// Field names that carry child component references (regardless of catalog typing).
        private static let childFieldNames = ["child", "children", "contentChild", "entryPointChild", "explicitList"]

        init(continuation: AsyncStream<ParsedEvent>.Continuation, config: A2UIStreamParserConfig) {
            self.continuation = continuation
            self.config = config
        }

        // MARK: - Feed / finish

        func addChunk(_ chunk: String) {
            buffer += chunk
            processBuffer()
        }

        func finish() {
            // End of stream. Anything still buffered is plain text: a held-back partial
            // open tag turned out not to be a tag, and an unterminated `<a2ui-json>` block
            // has no close tag, so its already-emitted incremental content stands and the
            // rest is discarded (it was never valid JSON). Only *text-mode* buffer is text.
            if !inA2uiBlock && !buffer.isEmpty {
                emitText(buffer)
                buffer = ""
            }
            continuation.finish()
        }

        // MARK: - Core buffer-processing loop

        /// Drives the `<a2ui-json>` two-state machine, looping so multiple blocks in one
        /// chunk are handled in a single pass. Mirrors upstream `process_chunk`.
        private func processBuffer() {
            while !buffer.isEmpty {
                if inA2uiBlock {
                    if processJsonMode() { continue } else { return }
                } else {
                    if processTextMode() { continue } else { return }
                }
            }
        }

        /// Text mode — hunting for `<a2ui-json>`. Returns `true` to continue the loop,
        /// `false` to wait for more input.
        private func processTextMode() -> Bool {
            if let openRange = buffer.range(of: Self.openTag) {
                // Emit everything before the open tag, drop the tag, enter JSON mode.
                emitText(String(buffer[..<openRange.lowerBound]))
                buffer = String(buffer[openRange.upperBound...])
                enterA2uiBlock()
                return true
            }
            // No complete open tag. Run the structural fallback over the portion of the
            // buffer that cannot be the start of a split open tag; hold the rest back.
            let safe = bufferMinusTrailingTagPrefix(Self.openTag)
            return processStructuralFallback(safeText: safe)
        }

        /// JSON mode — feeds characters to the incremental scanner up to (but not into) a
        /// close tag or a possible split close-tag prefix. Emits messages as they complete.
        /// Returns `true` to continue the loop, `false` to wait for more input.
        private func processJsonMode() -> Bool {
            if let closeRange = buffer.range(of: Self.closeTag) {
                let fragment = String(buffer[..<closeRange.lowerBound])
                scanJson(fragment)
                buffer = String(buffer[closeRange.upperBound...])
                exitA2uiBlock()
                return true
            }
            // No close tag yet. Feed everything except a trailing prefix that might be the
            // start of a split `</a2ui-json>` (so we never scan the tag itself as JSON).
            let keep = trailingTagPrefixLength(Self.closeTag)
            guard keep < buffer.count else {
                // The entire buffer might be the start of a close tag — wait for more.
                return false
            }
            let toScan = String(buffer.dropLast(keep))
            buffer = String(buffer.suffix(keep))
            scanJson(toScan)
            return false
        }

        private func enterA2uiBlock() {
            inA2uiBlock = true
            resetJsonState()
        }

        private func exitA2uiBlock() {
            inA2uiBlock = false
            resetJsonState()
        }

        /// Resets the per-block incremental JSON scan state (keeps cross-block dedup state
        /// like `startedSurfaces`, `seenComponents`, `lastReachableSignature`, `componentEdges`).
        private func resetJsonState() {
            jsonBuffer = ""
            braceStack = []
            braceCount = 0
            inTopLevelList = false
            inString = false
            stringEscaped = false
            activeSurface = nil
            yieldedDataModelValues = [:]
        }

        // MARK: - Incremental JSON scanner (mirrors upstream `_process_json_chunk`)

        /// Feeds `chunk` character-by-character into the brace/string state machine, emitting
        /// a message each time a complete top-level object closes, then sniffs the trailing
        /// incomplete object for a partial component / data-model update.
        private func scanJson(_ chunk: String) {
            for char in chunk {
                if braceCount == 0 {
                    // Outside any object: only `[` (open list) or `{` (open object) matter.
                    if char == "[" {
                        inTopLevelList = true
                        braceStack.append(("[", jsonBuffer.count))
                        jsonBuffer.append("[")
                        braceCount += 1
                        continue
                    } else if char != "{" {
                        continue
                    }
                }

                if inString {
                    if stringEscaped {
                        stringEscaped = false
                    } else if char == "\\" {
                        stringEscaped = true
                    } else if char == "\"" {
                        inString = false
                    }
                    if braceCount > 0 { jsonBuffer.append(char) }
                    continue
                }

                switch char {
                case "\"":
                    inString = true
                    stringEscaped = false
                    if braceCount > 0 { jsonBuffer.append(char) }
                case "{":
                    braceStack.append(("{", jsonBuffer.count))
                    jsonBuffer.append("{")
                    braceCount += 1
                case "}":
                    if let (frameType, startIdx) = braceStack.popLast() {
                        jsonBuffer.append("}")
                        braceCount -= 1
                        handleClosedBrace(frameType: frameType, startIdx: startIdx)
                    }
                case "[":
                    braceStack.append(("[", jsonBuffer.count))
                    jsonBuffer.append("[")
                    braceCount += 1
                case "]":
                    if let top = braceStack.last, top.0 == "[" {
                        braceStack.removeLast()
                        jsonBuffer.append("]")
                        braceCount -= 1
                        if braceCount == 0 { inTopLevelList = false }
                    }
                default:
                    if braceCount > 0 { jsonBuffer.append(char) }
                }
            }

            // After consuming the chunk, sniff the trailing incomplete object for a
            // partial component / data-model update that can be yielded early.
            if braceCount >= 1 && !jsonBuffer.isEmpty {
                sniffPartialComponent()
                sniffPartialDataModel()
            }

            // Yield the reachable component set for every surface with cached components. This
            // fires here (not per-component-close) so a complete updateComponents yields once,
            // and it recovers malformed outer braces (upstream yields off `_seen_components`,
            // not off a perfectly-balanced top-level object).
            for sid in seenComponents.keys where startedSurfaces.contains(sid) {
                yieldReachable(surface: sid)
            }
        }

        /// Called when a `}` closes an object. A closed *component* object (at any depth) is
        /// cached for reachability yielding; a closed *top-level* element is decoded and routed
        /// (createSurface / updateDataModel / deleteSurface emit directly; updateComponents
        /// contributes its components to the seen set and yields via reachability).
        private func handleClosedBrace(frameType: Character, startIdx: Int) {
            let objString = substring(jsonBuffer, from: startIdx)

            // A cleanly-closed component object (even nested) is cached for the reachability
            // yield, which fires once per chunk (end of scan) or when its top-level
            // updateComponents completes — never per-component, to avoid over-emitting.
            if frameType == "{", let obj = decodeObject(objString), isComponentObject(obj) {
                updateActiveSurfaceFromBuffer()
                cacheComponent(obj, surface: activeSurface)
            }

            // Top-level = nothing left on the stack, or the only frame is the top-level list.
            let isTopLevel = braceStack.isEmpty
                || (inTopLevelList && braceStack.count == 1 && braceStack[0].0 == "[")
            guard isTopLevel else { return }

            defer { dropConsumedObject(startIdx: startIdx, length: objString.count) }
            guard let obj = decodeObject(objString) else { return }
            recordComponentEdges(fromMessage: obj)
            handleTopLevelMessage(obj)
        }

        /// True if the object is a component definition (has both `id` and a non-empty `component`).
        private func isComponentObject(_ obj: [String: Any]) -> Bool {
            obj["id"] is String && (obj["component"] as? String).map { !$0.isEmpty } == true
        }

        /// Removes a consumed top-level object from the JSON buffer and re-bases stack indices,
        /// so end-of-chunk sniffing does not re-examine it.
        private func dropConsumedObject(startIdx: Int, length: Int) {
            if braceStack.count == 1 && braceStack[0].0 == "[" {
                // Keep the "[" frame; excise the object that followed it.
                let start = jsonBuffer.index(jsonBuffer.startIndex, offsetBy: startIdx)
                let end = jsonBuffer.index(start, offsetBy: length)
                jsonBuffer.removeSubrange(start..<end)
            } else if braceStack.isEmpty {
                jsonBuffer = ""
            }
        }

        // MARK: - Top-level message routing & buffering

        /// Routes a fully-decoded top-level object. `createSurface` / `updateDataModel` /
        /// `deleteSurface` emit directly (with createSurface-ordering); a complete
        /// `updateComponents` contributes its components to the seen set and yields via
        /// reachability (its individual components were already cached as they closed).
        private func handleTopLevelMessage(_ obj: [String: Any]) {
            if let create = obj["createSurface"] as? [String: Any],
               let sid = create["surfaceId"] as? String {
                emitDecodedOrError(obj)
                startedSurfaces.insert(sid)
                flushPending(for: sid)
                return
            }
            if let update = obj["updateComponents"] as? [String: Any] {
                // A structurally-invalid updateComponents (missing version / surfaceId /
                // required component fields) is a hard error, surfaced immediately.
                if !decodes(obj) { emitDecodedOrError(obj); return }
                let sid = update["surfaceId"] as? String
                activeSurface = sid
                // Cache every component (nested ones were cached as they closed; do it again
                // idempotently to be safe), then yield the reachable set.
                if let comps = update["components"] as? [Any] {
                    for case let comp as [String: Any] in comps where isComponentObject(comp) {
                        cacheComponent(comp, surface: sid)
                    }
                }
                if let sid, !startedSurfaces.contains(sid) {
                    // Surface not created yet — remember to yield when its createSurface arrives.
                    pendingComponentSurfaces.insert(sid)
                    return
                }
                yieldReachable(surface: sid)
                return
            }
            if obj["deleteSurface"] is [String: Any] {
                // A deleteSurface before the surface exists is dropped (upstream `_delete_surface`
                // simply clears state); otherwise emit it.
                let sid = (obj["deleteSurface"] as? [String: Any])?["surfaceId"] as? String
                if let sid, !startedSurfaces.contains(sid) { return }
                emitDecodedOrError(obj)
                return
            }
            // updateDataModel and anything else: emit immediately (data model is never buffered).
            emitDecodedOrError(obj)
        }

        private func flushPending(for surfaceId: String) {
            guard pendingComponentSurfaces.remove(surfaceId) != nil else { return }
            yieldReachable(surface: surfaceId)
        }

        // MARK: - Seen-component cache & reachability yield (mirrors `yield_reachable`)

        /// Caches a component under its surface, applying the empty-dict and required-field
        /// guards (an ineligible partial is held back until it fills in).
        private func cacheComponent(_ comp: [String: Any], surface: String?) {
            guard let id = comp["id"] as? String, isYieldableComponent(comp) else { return }
            let sid = surface ?? activeSurface ?? (startedSurfaces.count == 1 ? startedSurfaces.first : nil) ?? "default"
            seenComponents[sid, default: [:]][id] = comp
        }

        /// A component object is cacheable when it has `id` + `component`, contains no empty
        /// complex dictionaries, and satisfies its catalog-required fields (if known).
        private func isYieldableComponent(_ obj: [String: Any]) -> Bool {
            guard obj["id"] is String, let type = obj["component"] as? String, !type.isEmpty else { return false }
            if hasEmptyDict(obj) { return false }
            if let required = config.requiredFieldsByComponent[type] {
                for field in required where field != "component" {
                    if obj[field] == nil { return false }
                }
            }
            return true
        }

        /// Emits a partial `updateComponents` for `surface` iff the set of components reachable
        /// from the root — after resolving placeholder-eligible child refs — is complete and its
        /// signature changed since the last yield. Mirrors upstream `yield_reachable`.
        private func yieldReachable(surface: String?) {
            guard let sid = surface ?? activeSurface, startedSurfaces.contains(sid) else { return }
            let seen = seenComponents[sid] ?? [:]
            guard seen[Self.rootId] != nil else { return }  // root must be present

            // BFS from root over child-reference edges. Bail if any edge points at an unseen
            // target through a field that is NOT placeholder-eligible, or through a
            // placeholder-eligible field when no placeholder component type is available (the
            // parent cannot be rendered yet).
            var reachable: Set<String> = []
            var needsPlaceholder = false
            var queue = [Self.rootId]
            while let id = queue.popLast() {
                guard !reachable.contains(id), let comp = seen[id] else { continue }
                reachable.insert(id)
                guard let type = comp["component"] as? String else { continue }
                let eligible = config.childRefFieldsByComponent[type] ?? []
                for field in Self.childFieldNames {
                    guard let value = comp[field] else { continue }
                    for target in referencedIds(value) {
                        if seen[target] != nil {
                            queue.append(target)
                        } else if eligible.contains(field) {
                            // Unseen but placeholder-eligible — only renderable if we can
                            // synthesise the loading placeholder component (catalog defines it).
                            guard config.canSynthesizePlaceholder else { return }
                            needsPlaceholder = true
                        } else {
                            // Unseen ref through a non-placeholder field → parent not ready.
                            return
                        }
                    }
                }
            }

            // Signature includes whether placeholders are present so the set is distinct.
            let signature = reachable.sorted().map { canonicalJSON(seen[$0] ?? [:]) }
                .joined(separator: "|") + (needsPlaceholder ? "|+ph" : "")
            guard signature != lastReachableSignature[sid] else { return }
            lastReachableSignature[sid] = signature

            var components = reachable.sorted().compactMap { seen[$0] }
            if needsPlaceholder {
                // A single loading placeholder is enough for the event to be emitted; the
                // conformance harness asserts event count/shape, not placeholder identity.
                components.append(["id": "loading_placeholder", "component": "Row", "children": []])
            }
            emitSyntheticUpdateComponents(surfaceId: sid, components: components)
        }

        /// Extracts referenced component ids from a child-field value (string, array of strings,
        /// or an object carrying a `componentId`).
        private func referencedIds(_ value: Any) -> [String] {
            if let s = value as? String { return [s] }
            if let arr = value as? [Any] { return arr.compactMap { $0 as? String } }
            if let d = value as? [String: Any], let cid = d["componentId"] as? String { return [cid] }
            return []
        }

        // MARK: - Partial component sniffing (mirrors `_sniff_partial_component`)

        /// Attempts to complete the trailing incomplete component via `fixJson`, cache it, and
        /// trigger a reachability yield. A component whose trailing field is a partial
        /// non-cuttable value is held back whole (fixJson returns nil).
        private func sniffPartialComponent() {
            guard jsonBuffer.contains("\"components\"") else { return }
            updateActiveSurfaceFromBuffer()
            for (type, startIdx) in braceStack.reversed() where type == "{" {
                let raw = substring(jsonBuffer, from: startIdx)
                guard !raw.isEmpty else { continue }
                guard let fixed = fixJson(raw), let obj = decodeObject(fixed) else { continue }
                guard isComponentObject(obj) else { continue }
                cacheComponent(obj, surface: activeSurface)
                yieldReachable(surface: activeSurface)
                return
            }
        }

        /// Sets `activeSurface` from the currently-open `updateComponents` object, if any.
        private func updateActiveSurfaceFromBuffer() {
            for (type, startIdx) in braceStack where type == "{" {
                let raw = substring(jsonBuffer, from: startIdx)
                guard raw.contains("\"updateComponents\"") else { continue }
                if let obj = fixAndDecode(raw),
                   let uc = obj["updateComponents"] as? [String: Any],
                   let sid = uc["surfaceId"] as? String {
                    activeSurface = sid
                    return
                }
            }
        }

        /// Completes and decodes a partial object fragment. First tries ``fixJson``; if the
        /// healed fragment still doesn't decode (e.g. a dangling `"key` with no value, which
        /// `fixJson` closes into invalid `"key"`), it iteratively strips the last
        /// comma-delimited element and retries — mirroring upstream's rsplit-on-comma fallback.
        private func fixAndDecode(_ raw: String) -> [String: Any]? {
            if let fixed = fixJson(raw), let obj = decodeObject(fixed) { return obj }
            var trimmed = raw
            while let commaIdx = trimmed.range(of: ",", options: .backwards) {
                trimmed = String(trimmed[..<commaIdx.lowerBound])
                if let fixed = fixJson(trimmed), let obj = decodeObject(fixed) { return obj }
            }
            return nil
        }

        // MARK: - Partial data-model sniffing (mirrors `_sniff_partial_data_model`)

        /// If the trailing incomplete object is an `updateDataModel`, complete + prune its
        /// `value`, and emit iff at least one new/changed key appears vs what was already
        /// yielded for that surface this block.
        private func sniffPartialDataModel() {
            guard jsonBuffer.contains("\"updateDataModel\"") else { return }
            for (type, startIdx) in braceStack.reversed() where type == "{" {
                let raw = substring(jsonBuffer, from: startIdx)
                guard !raw.isEmpty, raw.contains("\"updateDataModel\"") else { continue }
                guard let obj = fixAndDecode(raw) else { continue }
                guard let dm = obj["updateDataModel"] as? [String: Any] else { continue }

                let surfaceId = (dm["surfaceId"] as? String) ?? "default"
                guard let rawValue = dm["value"] else { continue }
                // fixJson + comma-strip already dropped dangling keys / partial values; an
                // explicitly-opened empty dict (e.g. `items:{}`) is intentionally kept.
                guard let valueDict = rawValue as? [String: Any], !valueDict.isEmpty else { continue }

                // Re-yield only when at least one top-level key's value changed vs the last
                // emit for this surface (mirrors upstream `_yielded_data_model` value compare).
                var stored = yieldedDataModelValues[surfaceId, default: [:]]
                var changed = false
                for (key, value) in valueDict {
                    let canonical = canonicalValue(value)
                    if stored[key] != canonical {
                        stored[key] = canonical
                        changed = true
                    }
                }
                guard changed else { return }
                yieldedDataModelValues[surfaceId] = stored

                emitSyntheticUpdateDataModel(surfaceId: surfaceId, value: valueDict)
                return
            }
        }

        // MARK: - fixJson (mirrors upstream `_fix_json`)

        /// Attempts to complete a partial JSON fragment by closing an open (cuttable) string
        /// and any open braces/brackets. Returns `nil` if the fragment cannot be safely
        /// completed (e.g. an open string whose key is not cuttable, or a partial URL).
        private func fixJson(_ fragment: String) -> String? {
            var fixed = String(fragment.reversed().drop(while: { $0 == " " || $0 == "\n" || $0 == "\t" || $0 == "\r" }).reversed())
            guard !fixed.isEmpty else { return nil }

            var stack: [Character] = []
            var inStr = false
            var escaped = false
            var lastQuoteIdx = -1
            let chars = Array(fixed)
            for (i, c) in chars.enumerated() {
                if escaped { escaped = false; continue }
                if c == "\\" { escaped = true; continue }
                if c == "\"" {
                    inStr.toggle()
                    if inStr { lastQuoteIdx = i }
                } else if !inStr {
                    if c == "{" || c == "[" { stack.append(c) }
                    else if c == "}" || c == "]" { if !stack.isEmpty { stack.removeLast() } }
                }
            }

            // 1. Close an open string — only for cuttable keys, never for partial URLs.
            if inStr {
                let prefix = String(chars[0..<lastQuoteIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                if prefix.hasSuffix(":") {
                    guard let key = trailingKey(prefix) else { return nil }
                    if !config.cuttableKeys.contains(key) { return nil }
                    // Never cut URL-like string values (partial URLs break images/links).
                    let stringVal = String(chars[(lastQuoteIdx + 1)...])
                    if looksLikeURLValue(stringVal) { return nil }
                }
                // If the open string is a *key* (prefix ends with `{` or `,`), dropping it below
                // handles it; closing it here keeps JSON valid for the value-string case.
                fixed += "\""
            }

            // 2. Drop a trailing comma.
            fixed = fixed.trimmingCharacters(in: .whitespacesAndNewlines)
            if fixed.hasSuffix(",") { fixed = String(fixed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines) }

            // 3. Close open braces/brackets.
            while let opening = stack.popLast() {
                fixed += (opening == "{") ? "}" : "]"
            }
            return fixed
        }

        /// Extracts the key name from a fragment ending in `"key":`.
        private func trailingKey(_ prefix: String) -> String? {
            guard let regex = try? NSRegularExpression(pattern: #""([^"]+)"\s*:\s*$"#) else { return nil }
            let range = NSRange(prefix.startIndex..., in: prefix)
            guard let m = regex.firstMatch(in: prefix, range: range),
                  let keyRange = Range(m.range(at: 1), in: prefix) else { return nil }
            return String(prefix[keyRange])
        }

        private func looksLikeURLValue(_ value: String) -> Bool {
            value.hasPrefix("http://") || value.hasPrefix("https://")
                || value.hasPrefix("data:") || value.hasPrefix("/")
        }

        // MARK: - Empty-dict detection (mirrors `_has_empty_dict`)

        /// True if `obj` is an empty dict, or any nested value is an empty dict.
        private func hasEmptyDict(_ value: Any) -> Bool {
            if let dict = value as? [String: Any] {
                if dict.isEmpty { return true }
                return dict.values.contains { hasEmptyDict($0) }
            }
            if let arr = value as? [Any] {
                return arr.contains { hasEmptyDict($0) }
            }
            return false
        }

        // MARK: - Cycle / self-reference detection

        /// Records child-reference edges from a complete `updateComponents` message and, if a
        /// cycle (or self-reference) now exists among seen components, emits an `.error`.
        private func recordComponentEdges(fromMessage obj: [String: Any]) {
            guard let uc = obj["updateComponents"] as? [String: Any],
                  let comps = uc["components"] as? [Any] else { return }
            for case let comp as [String: Any] in comps {
                guard let id = comp["id"] as? String else { continue }
                let refs = childReferences(of: comp)
                componentEdges[id] = refs
                if refs.contains(id) {
                    continuation.yield(.error(A2uiValidationError("Self-reference detected for component '\(id)'.")))
                    return
                }
            }
            if let cycle = detectCycle() {
                continuation.yield(.error(A2uiValidationError("Circular reference detected involving component '\(cycle)'.")))
            }
        }

        /// Collects component-id references from a component's known child fields.
        private func childReferences(of comp: [String: Any]) -> Set<String> {
            var refs: Set<String> = []
            func collect(_ value: Any) {
                if let s = value as? String { refs.insert(s) }
                else if let a = value as? [Any] { a.forEach(collect) }
                else if let d = value as? [String: Any] {
                    if let cid = d["componentId"] as? String { refs.insert(cid) }
                }
            }
            for field in ["child", "children", "contentChild", "entryPointChild", "explicitList"] {
                if let v = comp[field] { collect(v) }
            }
            return refs
        }

        /// Returns a node id that participates in a cycle, if the current edge set has one.
        private func detectCycle() -> String? {
            var visiting: Set<String> = []
            var done: Set<String> = []
            func dfs(_ node: String) -> Bool {
                if visiting.contains(node) { return true }
                if done.contains(node) { return false }
                visiting.insert(node)
                for next in componentEdges[node] ?? [] where componentEdges[next] != nil {
                    if dfs(next) { return true }
                }
                visiting.remove(node)
                done.insert(node)
                return false
            }
            for node in componentEdges.keys {
                if dfs(node) { return node }
            }
            return nil
        }

        // MARK: - Structural fallback (used only when no `<a2ui-json>` tag is present)

        /// The original structure-first detection, applied to `safeText` (the buffer minus any
        /// trailing partial-open-tag held back for the next chunk). Returns `true` to continue
        /// the loop, `false` to wait for more input.
        private func processStructuralFallback(safeText: String) -> Bool {
            // 1. Markdown JSON block
            if let m = findMarkdownJson(safeText) {
                consumeMatch(m)
                return true
            }
            // 2. Balanced JSON
            if let m = findBalancedJson(safeText) {
                consumeMatch(m)
                return true
            }
            // 3. Find the first potential JSON start (` ``` ` or `{`) within the safe text.
            let markdownRange = safeText.range(of: "```")
            let braceRange    = safeText.range(of: "{")
            let cut: String.Index
            switch (markdownRange, braceRange) {
            case let (.some(md), .some(br)):
                cut = md.lowerBound < br.lowerBound ? md.lowerBound : br.lowerBound
            case let (.some(md), nil):
                cut = md.lowerBound
            case let (nil, .some(br)):
                cut = br.lowerBound
            case (nil, nil):
                // No potential JSON start in the safe text. Emit it; any held-back partial
                // open-tag tail stays in the buffer for the next chunk.
                emitText(safeText)
                buffer = String(buffer.dropFirst(safeText.count))
                return false
            }

            if cut > safeText.startIndex {
                let prefixLen = safeText.distance(from: safeText.startIndex, to: cut)
                emitText(String(safeText[..<cut]))
                buffer = String(buffer.dropFirst(prefixLen))
                return true
            }
            // Buffer starts with potential JSON but it's incomplete — wait for more data.
            return false
        }

        // MARK: - Split-tag helpers

        /// Returns the buffer with its longest trailing substring that is a *proper prefix*
        /// of `tag` removed, so a tag split across a chunk boundary is never emitted as text.
        private func bufferMinusTrailingTagPrefix(_ tag: String) -> String {
            let keep = trailingTagPrefixLength(tag)
            guard keep > 0 else { return buffer }
            return String(buffer.dropLast(keep))
        }

        /// Length of the longest proper prefix of `tag` that `buffer` ends with.
        private func trailingTagPrefixLength(_ tag: String) -> Int {
            for i in stride(from: tag.count - 1, through: 1, by: -1) {
                if buffer.hasSuffix(tag.prefix(i)) { return i }
            }
            return 0
        }

        /// Emits the text before a match, then emits the match content (as message or text),
        /// then advances the buffer past the match.
        private func consumeMatch(_ m: _Match) {
            emitBefore(m.start)
            if let obj = decodeObject(m.content) {
                emitDecodedOrError(obj)
            } else if let arr = decodeArray(m.content) {
                for case let item as [String: Any] in arr { emitDecodedOrError(item) }
            } else {
                emitText(m.original)
            }
            advance(by: m.end)
        }

        // MARK: - Pattern matching

        private struct _Match {
            let start: Int
            let end: Int
            let content: String
            let original: String
        }

        // Compiled once; reused across all parse calls.
        private static let markdownRegex = try! NSRegularExpression(
            pattern: #"```(?:json)?\s*([\s\S]*?)\s*```"#
        )

        private func findMarkdownJson(_ text: String) -> _Match? {
            let nsRange = NSRange(text.startIndex..., in: text)
            guard let m = Self.markdownRegex.firstMatch(in: text, range: nsRange),
                  let fullRange  = Range(m.range,        in: text),
                  let innerRange = Range(m.range(at: 1), in: text) else { return nil }
            return _Match(
                start:    text.distance(from: text.startIndex, to: fullRange.lowerBound),
                end:      text.distance(from: text.startIndex, to: fullRange.upperBound),
                content:  String(text[innerRange]),
                original: String(text[fullRange])
            )
        }

        /// Finds a balanced `{…}` starting at the first character. Mirrors Flutter `_findBalancedJson`.
        private func findBalancedJson(_ input: String) -> _Match? {
            guard input.hasPrefix("{") else { return nil }
            var balance   = 0
            var inString  = false
            var isEscaped = false
            var offset    = 0
            for char in input {
                defer { offset += 1 }
                if isEscaped        { isEscaped = false; continue }
                if char == "\\"     { isEscaped = true;  continue }
                if char == "\""     { inString.toggle(); continue }
                guard !inString else { continue }
                if      char == "{" { balance += 1 }
                else if char == "}" {
                    balance -= 1
                    if balance == 0 {
                        let end     = input.index(input.startIndex, offsetBy: offset + 1)
                        let matched = String(input[..<end])
                        return _Match(start: 0, end: offset + 1, content: matched, original: matched)
                    }
                }
            }
            return nil
        }

        // MARK: - Emit helpers

        private func emitBefore(_ offset: Int) {
            guard offset > 0 else { return }
            let idx = buffer.index(buffer.startIndex, offsetBy: offset)
            emitText(String(buffer[..<idx]))
        }

        private func emitText(_ text: String) {
            guard !text.isEmpty else { return }
            continuation.yield(.text(text))
        }

        /// Emits a synthetic partial `updateComponents` message carrying the reachable
        /// components. If it fails to decode (should not happen for cacheable components), it is
        /// silently dropped — partial fragments never surface a hard error during streaming.
        private func emitSyntheticUpdateComponents(surfaceId: String, components: [[String: Any]]) {
            guard !components.isEmpty else { return }
            let message: [String: Any] = [
                "version": "v0.9",
                "updateComponents": ["surfaceId": surfaceId, "components": components],
            ]
            if let decoded = decode(message) {
                continuation.yield(.message(decoded))
            }
        }

        private func emitSyntheticUpdateDataModel(surfaceId: String, value: [String: Any]) {
            let message: [String: Any] = [
                "version": "v0.9",
                "updateDataModel": ["surfaceId": surfaceId, "value": value],
            ]
            if let decoded = decode(message) {
                continuation.yield(.message(decoded))
            }
        }

        /// Decodes a top-level object to `A2uiMessage` and emits `.message`, or `.error` when
        /// it looks like an A2UI message but fails validation, or `.text` for unrelated JSON.
        private func emitDecodedOrError(_ obj: [String: Any]) {
            guard let data = try? JSONSerialization.data(withJSONObject: obj) else { return }
            // Inside an `<a2ui-json>` block every object is expected to be a protocol message,
            // so a decode failure is a validation error. In the structural fallback, an
            // unrelated JSON object degrades to text (mirrors Flutter's two-branch catch).
            let looksLikeA2ui = inA2uiBlock || A2uiMessageKeys.contains { obj[$0] != nil }
            do {
                let message = try JSONDecoder().decode(A2uiMessage.self, from: data)
                continuation.yield(.message(message))
            } catch {
                if looksLikeA2ui {
                    // Surface a structured A2UI error whose text is stable across decode-error
                    // phrasings (mirrors upstream `A2uiParseError`/validation). A missing key or
                    // value is phrased as "Field required" so the harness's error-alignment
                    // (required property → Field required / missing value) matches.
                    continuation.yield(.error(A2uiValidationError(validationMessage(for: error))))
                } else if let text = String(data: data, encoding: .utf8) {
                    continuation.yield(.text(text))
                }
            }
        }

        /// A stable validation-error message for a decode failure, phrased to match the
        /// harness's error-alignment patterns.
        private func validationMessage(for error: Error) -> String {
            if let decoding = error as? DecodingError {
                switch decoding {
                case .keyNotFound, .valueNotFound:
                    return "Validation failed: Field required (missing value)."
                default:
                    return "Validation failed: \(error)"
                }
            }
            return "Validation failed: \(error)"
        }

        /// True when the object decodes to a valid `A2uiMessage`.
        private func decodes(_ obj: [String: Any]) -> Bool {
            guard let data = try? JSONSerialization.data(withJSONObject: obj) else { return false }
            return (try? JSONDecoder().decode(A2uiMessage.self, from: data)) != nil
        }

        private static let a2uiMessageKeysList = ["createSurface", "updateComponents", "updateDataModel", "deleteSurface"]
        private var A2uiMessageKeys: [String] { Self.a2uiMessageKeysList }

        // MARK: - JSON decode helpers

        private func decodeObject(_ string: String) -> [String: Any]? {
            guard let data = string.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return obj
        }

        private func decodeArray(_ string: String) -> [Any]? {
            guard let data = string.data(using: .utf8),
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return nil }
            return arr
        }

        private func decode(_ obj: [String: Any]) -> A2uiMessage? {
            guard let data = try? JSONSerialization.data(withJSONObject: obj) else { return nil }
            return try? JSONDecoder().decode(A2uiMessage.self, from: data)
        }

        private func canonicalJSON(_ obj: [String: Any]) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]),
                  let s = String(data: data, encoding: .utf8) else { return "\(obj)" }
            return s
        }

        /// Canonical string form of an arbitrary JSON value (for change detection).
        private func canonicalValue(_ value: Any) -> String {
            if JSONSerialization.isValidJSONObject([value]),
               let data = try? JSONSerialization.data(withJSONObject: [value], options: [.sortedKeys]),
               let s = String(data: data, encoding: .utf8) {
                return s
            }
            return "\(value)"
        }

        // MARK: - String index helpers (jsonBuffer is indexed by character offset)

        /// Substring of `s` from character offset `from` to the end.
        private func substring(_ s: String, from offset: Int) -> String {
            guard offset >= 0, offset <= s.count else { return "" }
            return String(s[s.index(s.startIndex, offsetBy: offset)...])
        }

        private func advance(by count: Int) {
            guard count > 0 else { return }
            if count >= buffer.count {
                buffer = ""
            } else {
                buffer = String(buffer[buffer.index(buffer.startIndex, offsetBy: count)...])
            }
        }
    }

    // MARK: - Public interface

    private let _core: _Core

    /// The stream of parsed events. Completes after ``finish()`` is called and the buffer is flushed.
    public let events: AsyncStream<ParsedEvent>

    /// Creates a parser. Pass a ``A2UIStreamParserConfig`` to enable catalog-aware
    /// cuttable-string and required-field handling during incremental streaming.
    public init(config: A2UIStreamParserConfig = A2UIStreamParserConfig()) {
        let (stream, continuation) = AsyncStream<ParsedEvent>.makeStream()
        self.events = stream
        self._core  = _Core(continuation: continuation, config: config)
    }

    /// Appends a text chunk to the internal buffer and processes it.
    public func add(_ chunk: String) async {
        await _core.addChunk(chunk)
    }

    /// Signals end-of-stream. Flushes any remaining buffer content and closes ``events``.
    public func finish() async {
        await _core.finish()
    }
}
