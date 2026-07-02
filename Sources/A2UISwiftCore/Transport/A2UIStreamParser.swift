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

// MARK: - A2UIStreamParser

/// Transforms a stream of raw LLM text chunks into a sequence of ``ParsedEvent`` values.
///
/// Mirrors Flutter's `A2uiParserTransformer` / `_A2uiParserStream` pair, reimplemented
/// with Swift native concurrency (`AsyncStream` / `actor`).
///
/// Parsing is **tag-first with a structural fallback**:
/// - **Primary — `<a2ui-json>` … `</a2ui-json>` delimiter.** This is the spec's
///   text↔UI mode switch: prose *outside* the tags is emitted as ``ParsedEvent/text(_:)``,
///   JSON *inside* the tags is decoded into ``ParsedEvent/message(_:)``. Multiple blocks
///   per stream are supported, and a tag split across chunk boundaries is buffered
///   (a trailing prefix of a tag is held back rather than emitted as text). Mirrors the
///   upstream Python `streaming.py` / Kotlin `StreamingParser.kt` state machine.
/// - **Fallback — structural detection** (used only when no `<a2ui-json>` tag is present):
///   a markdown JSON block (` ```json … ``` ` or ` ``` … ``` `) or a bare balanced-brace
///   `{…}` object. Preserves the original Flutter tolerance for un-tagged input.
///
/// Feed chunks via ``add(_:)``, signal end-of-stream with ``finish()``,
/// and consume results from ``events``.
public final class A2UIStreamParser: Sendable {

    // MARK: Internal actor (owns all mutable state)

    private actor _Core {
        private var buffer: String = ""
        /// `true` while inside an `<a2ui-json>` block (hunting for the close tag); `false`
        /// in text mode (hunting for the open tag). Mirrors upstream `_found_delimiter`.
        private var inA2uiBlock = false
        private let continuation: AsyncStream<ParsedEvent>.Continuation

        // Spec delimiter tags (hyphen — the v0.9 wire format). See upstream
        // `constants.py` `A2UI_OPEN_TAG` / `A2UI_CLOSE_TAG`.
        private static let openTag  = "<a2ui-json>"
        private static let closeTag = "</a2ui-json>"

        init(continuation: AsyncStream<ParsedEvent>.Continuation) {
            self.continuation = continuation
        }

        // MARK: - Feed / finish

        func addChunk(_ chunk: String) {
            buffer += chunk
            processBuffer()
        }

        func finish() {
            // End of stream. Anything still buffered is plain text: a held-back partial
            // open tag turned out not to be a tag, and an unterminated `<a2ui-json>` block
            // has no close tag, so its contents are surfaced as text rather than dropped.
            if !buffer.isEmpty {
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
                inA2uiBlock = true
                return true
            }
            // No complete open tag. Run the structural fallback over the portion of the
            // buffer that cannot be the start of a split open tag; hold the rest back.
            let safe = bufferMinusTrailingTagPrefix(Self.openTag)
            return processStructuralFallback(safeText: safe)
        }

        /// JSON mode — hunting for `</a2ui-json>`. Returns `true` to continue the loop,
        /// `false` to wait for more input.
        private func processJsonMode() -> Bool {
            guard let closeRange = buffer.range(of: Self.closeTag) else {
                // No close tag yet — wait. This parser only emits complete JSON, so there
                // is nothing to flush incrementally; the close tag (or more data) completes it.
                return false
            }
            let fragment = String(buffer[..<closeRange.lowerBound])
            parseBlockFragment(fragment)
            buffer = String(buffer[closeRange.upperBound...])
            inA2uiBlock = false
            return true
        }

        /// Parses the JSON inside an `<a2ui-json>` block. The spec wraps a JSON array (or a
        /// single object / markdown fence); reuse the structural matchers and the array-aware
        /// ``emitMessage(_:)``. Whitespace around the payload is tolerated.
        private func parseBlockFragment(_ fragment: String) {
            let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if let m = findMarkdownJson(trimmed) {
                if let decoded = decodeJSON(m.content) { emitMessage(decoded) }
                else { emitText(m.original) }
            } else if let decoded = decodeJSON(trimmed) {
                emitMessage(decoded)
            } else {
                // Not parseable as a complete value — surface as text rather than stall.
                emitText(trimmed)
            }
        }

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
                // Emit the safe prefix, then re-enter the loop to attempt parsing the JSON
                // that now starts the buffer.
                let prefixLen = safeText.distance(from: safeText.startIndex, to: cut)
                emitText(String(safeText[..<cut]))
                buffer = String(buffer.dropFirst(prefixLen))
                return true
            }
            // Buffer starts with potential JSON but it's incomplete — wait for more data.
            return false
        }

        /// Returns the buffer with its longest trailing substring that is a *proper prefix*
        /// of `tag` removed, so a tag split across a chunk boundary is never emitted as text.
        /// Mirrors the upstream split-tag guard (longest prefix-that-is-a-suffix).
        private func bufferMinusTrailingTagPrefix(_ tag: String) -> String {
            var keep = 0
            // Longest first: the largest proper prefix of `tag` that the buffer ends with.
            for i in stride(from: tag.count - 1, through: 1, by: -1) {
                if buffer.hasSuffix(tag.prefix(i)) { keep = i; break }
            }
            guard keep > 0 else { return buffer }
            return String(buffer.dropLast(keep))
        }

        /// Emits the text before a match, then emits the match content (as message or text),
        /// then advances the buffer past the match.
        /// Extracted to eliminate the duplicate emit+advance pattern for markdown and balanced JSON.
        private func consumeMatch(_ m: _Match) {
            emitBefore(m.start)
            if let decoded = decodeJSON(m.content) {
                emitMessage(decoded)
            } else {
                // Invalid JSON — emit as text to avoid stalling the stream.
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

        // A2UI message-type keys derived from the wire protocol.
        // Used to distinguish "malformed A2UI message" from "unrelated JSON object".
        private static let a2uiKeys: Set<String> = [
            "createSurface", "updateComponents", "updateDataModel", "deleteSurface"
        ]
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

        // MARK: - Emit helpers (mirror Flutter `_emitBefore`, `_emitText`, `_emitMessage`)

        private func emitBefore(_ offset: Int) {
            guard offset > 0 else { return }
            let idx = buffer.index(buffer.startIndex, offsetBy: offset)
            emitText(String(buffer[..<idx]))
        }

        private func emitText(_ text: String) {
            // The `<a2ui-json>` tags are stripped by the state machine before reaching here,
            // so no tag cleanup is needed.
            guard !text.isEmpty else { return }
            continuation.yield(.text(text))
        }

        private func decodeJSON(_ string: String) -> Any? {
            guard let data = string.data(using: .utf8) else { return nil }
            return try? JSONSerialization.jsonObject(with: data)
        }

        private func emitMessage(_ json: Any) {
            if let dict = json as? [String: Any] {
                tryEmitA2uiMessage(dict)
            } else if let array = json as? [Any] {
                for item in array {
                    if let dict = item as? [String: Any] {
                        tryEmitA2uiMessage(dict)
                    }
                }
            }
        }

        private func tryEmitA2uiMessage(_ dict: [String: Any]) {
            guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
            let looksLikeA2ui = !Self.a2uiKeys.isDisjoint(with: dict.keys)
            do {
                let message = try JSONDecoder().decode(A2uiMessage.self, from: data)
                continuation.yield(.message(message))
            } catch {
                // Swift Codable throws DecodingError; use key-presence like Flutter's two-branch catch.
                if looksLikeA2ui {
                    continuation.yield(.error(error))
                } else if let text = String(data: data, encoding: .utf8) {
                    continuation.yield(.text(text))
                }
            }
        }

        // MARK: - Helpers

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

    public init() {
        let (stream, continuation) = AsyncStream<ParsedEvent>.makeStream()
        self.events = stream
        self._core  = _Core(continuation: continuation)
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
