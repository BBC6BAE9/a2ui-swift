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
    /// A fully validated A2UI server-to-client message extracted from the stream.
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
/// Three A2UI wire formats are detected:
/// - **Markdown JSON block** — ` ```json … ``` ` or ` ``` … ``` `
/// - **Bare JSON object** — balanced-brace matching starting at `{`
/// - **XML wrapper** — `<a2ui_message>…</a2ui_message>` (tags stripped; inner JSON parsed)
///
/// Feed chunks via ``add(_:)``, signal end-of-stream with ``finish()``,
/// and consume results from ``events``.
public final class A2UIStreamParser: Sendable {

    // MARK: Internal actor (owns all mutable state)

    private actor _Core {
        private var buffer: String = ""
        private let continuation: AsyncStream<ParsedEvent>.Continuation

        init(continuation: AsyncStream<ParsedEvent>.Continuation) {
            self.continuation = continuation
        }

        // MARK: - Feed / finish

        func addChunk(_ chunk: String) {
            buffer += chunk
            processBuffer()
        }

        func finish() {
            // If there's anything left in the buffer that looks like text, emit it.
            if !buffer.isEmpty {
                emitText(buffer)
                buffer = ""
            }
            continuation.finish()
        }

        // MARK: - Core buffer-processing loop (mirrors Flutter `_processBuffer`)

        private func processBuffer() {
            while !buffer.isEmpty {
                // 1. Check for Markdown JSON block
                if let m = findMarkdownJson(buffer) {
                    consumeMatch(m)
                    continue
                }

                // 2. Check for Balanced JSON
                if let m = findBalancedJson(buffer) {
                    consumeMatch(m)
                    continue
                }

                // 3. Fallback / Wait logic
                let markdownRange = buffer.range(of: "```")
                let braceRange    = buffer.range(of: "{")

                let firstPotentialStart: String.Index?
                switch (markdownRange, braceRange) {
                case let (.some(md), .some(br)):
                    firstPotentialStart = md.lowerBound < br.lowerBound ? md.lowerBound : br.lowerBound
                case let (.some(md), nil):
                    firstPotentialStart = md.lowerBound
                case let (nil, .some(br)):
                    firstPotentialStart = br.lowerBound
                case (nil, nil):
                    // No potential JSON start. Emit all.
                    emitText(buffer)
                    buffer = ""
                    return
                }

                guard let cut = firstPotentialStart else {
                    emitText(buffer); buffer = ""; return
                }

                if cut > buffer.startIndex {
                    // Emit safe prefix, then re-enter loop to attempt parsing the
                    // JSON that now starts the buffer.
                    emitText(String(buffer[..<cut]))
                    buffer = String(buffer[cut...])
                    continue
                }
                // Buffer starts with potential JSON but it's incomplete — wait for more data.
                return
            }
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

        private func emitText(_ raw: String) {
            // Clean up protocol tags that might leak into text stream
            let text = raw
                .replacingOccurrences(of: "<a2ui_message>",  with: "")
                .replacingOccurrences(of: "</a2ui_message>", with: "")
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
            // SPEC v0.9 / renderer_guide: validate against `server_to_client.json` before decode → state.
            if looksLikeA2ui {
                do {
                    try V09JSONSchemaValidation.validateServerToClientMessage(dict)
                } catch {
                    continuation.yield(.error(error))
                    return
                }
            }
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
