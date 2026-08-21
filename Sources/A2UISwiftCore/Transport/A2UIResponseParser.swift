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

// MARK: - A2uiParseError

/// Thrown when a *complete* (non-streaming) agent response cannot be parsed into
/// A2UI parts.
///
/// Mirrors the upstream Python `ParseError` raised by `parser.parse_full` — see
/// `agent_sdks/python/a2ui_agent/src/a2ui/parser/parser.py`. Distinct from the
/// streaming path (``A2UIStreamParser``), which tolerates malformed input by
/// surfacing it as text; the full-response parser is strict because the whole
/// payload is available up front.
public struct A2uiParseError: A2uiError {
    public var code: String { "PARSE_ERROR" }
    public let message: String

    public init(_ message: String) {
        self.message = message
    }
}

// MARK: - A2uiResponsePart

/// One segment of a parsed complete response: leading/trailing prose plus an
/// optional decoded A2UI JSON payload.
///
/// Mirrors upstream `ResponsePart(text, a2ui)`. `a2ui` holds the raw decoded
/// JSON value (an array of message-shaped objects) exactly as it appeared inside
/// the `<a2ui-json>` tags — it is intentionally *not* decoded into
/// ``A2uiMessage`` here, because `parse_full` operates one level below message
/// validation (the conformance payloads such as `[{"id": "test"}]` are not valid
/// server-to-client messages). The value is a `JSONSerialization` result
/// (`[Any]` / `[String: Any]`).
public struct A2uiResponsePart {
    /// Prose that preceded (or, for the final part, followed) the A2UI block.
    /// Trimmed of surrounding whitespace, matching upstream behaviour.
    public let text: String
    /// The decoded raw JSON payload from inside the `<a2ui-json>` tags, or `nil`
    /// for a trailing text-only part.
    public let a2ui: Any?

    public init(text: String, a2ui: Any?) {
        self.text = text
        self.a2ui = a2ui
    }
}

// MARK: - A2UIResponseParser

/// Parses a *complete* agent response (all text available at once) into
/// ``A2uiResponsePart`` values.
///
/// This is the non-streaming counterpart to ``A2UIStreamParser``. Where the
/// streaming parser is lenient (unknown/partial input becomes text so the stream
/// never stalls), the full-response parser is strict and throws
/// ``A2uiParseError`` when the response contains no usable A2UI content or the
/// JSON inside the tags is malformed.
///
/// Mirrors the upstream Python `parser` package (`parse_full`, `fix_payload`,
/// `has_a2ui_parts`) at commit `55d8a8a`.
public enum A2UIResponseParser {

    // Spec delimiter tags (hyphenated v0.9 wire format), matching
    // ``A2UIStreamParser`` and upstream `constants.py`.
    static let openTag  = "<a2ui-json>"
    static let closeTag = "</a2ui-json>"

    // MARK: - has_a2ui_parts

    /// Returns `true` when `response` contains at least one *complete*
    /// `<a2ui-json>` … `</a2ui-json>` block. A lone opening tag does not count.
    ///
    /// Mirrors upstream `has_a2ui_parts`.
    public static func hasA2uiParts(_ response: String) -> Bool {
        guard let openRange = response.range(of: openTag) else { return false }
        return response.range(of: closeTag, range: openRange.upperBound..<response.endIndex) != nil
    }

    // MARK: - parse_full

    /// Parses a complete response into ordered ``A2uiResponsePart`` values.
    ///
    /// Semantics (mirror upstream `parse_full`):
    /// - Text before each `<a2ui-json>` block is trimmed and attached to that
    ///   block's part.
    /// - Any trailing text after the last block becomes a final text-only part.
    /// - Throws ``A2uiParseError`` when no `<a2ui-json>` block is present
    ///   (`"...not found in response"`), when a block is empty
    ///   (`"A2UI JSON part is empty"`), or when the JSON is malformed
    ///   (`"Failed to parse ..."`).
    ///
    /// - Throws: ``A2uiParseError``.
    public static func parseFull(_ response: String) throws -> [A2uiResponsePart] {
        guard hasA2uiParts(response) else {
            throw A2uiParseError("A2UI JSON tags not found in response.")
        }

        var parts: [A2uiResponsePart] = []
        var remainder = Substring(response)

        while let openRange = remainder.range(of: openTag),
              let closeRange = remainder.range(of: closeTag, range: openRange.upperBound..<remainder.endIndex) {

            let leadingText = String(remainder[remainder.startIndex..<openRange.lowerBound])
            let rawBlock = String(remainder[openRange.upperBound..<closeRange.lowerBound])

            let a2ui = try decodeBlock(rawBlock)
            parts.append(A2uiResponsePart(
                text: leadingText.trimmingCharacters(in: .whitespacesAndNewlines),
                a2ui: a2ui
            ))

            remainder = remainder[closeRange.upperBound...]
        }

        // Trailing prose after the final block, if any.
        let trailing = String(remainder).trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            parts.append(A2uiResponsePart(text: trailing, a2ui: nil))
        }

        return parts
    }

    /// Decodes the JSON found inside one `<a2ui-json>` block, applying
    /// ``fixPayload(_:)`` repairs first. Strips a markdown fence if present.
    private static func decodeBlock(_ rawBlock: String) throws -> Any {
        var content = rawBlock.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty {
            throw A2uiParseError("A2UI JSON part is empty.")
        }

        // Strip a ```json … ``` (or ``` … ```) fence if the model wrapped the
        // payload in a markdown code block.
        content = stripMarkdownFence(content)
        if content.isEmpty {
            throw A2uiParseError("A2UI JSON part is empty.")
        }

        let fixed = fixPayload(content)
        guard let data = fixed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            throw A2uiParseError("Failed to parse A2UI JSON part: \(content)")
        }
        return json
    }

    /// Removes a single surrounding markdown code fence (```` ```json ```` / ```` ``` ````)
    /// from `content`, returning the inner text trimmed. Returns `content`
    /// unchanged when no complete fence is present.
    static func stripMarkdownFence(_ content: String) -> String {
        guard content.hasPrefix("```") else { return content }
        // Drop the opening fence line (``` or ```json, up to the first newline).
        guard let firstNewline = content.firstIndex(of: "\n") else { return content }
        let afterOpen = content[content.index(after: firstNewline)...]
        // Drop the trailing closing fence.
        guard let closeRange = afterOpen.range(of: "```", options: .backwards) else { return content }
        let inner = afterOpen[afterOpen.startIndex..<closeRange.lowerBound]
        return inner.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - fix_payload

    /// Repairs common LLM JSON mistakes and returns a payload that is always a
    /// JSON *array* string, ready for `JSONSerialization`.
    ///
    /// Applied fixes (mirror upstream `fix_payload`):
    /// 1. Normalise smart/curly quotes to straight quotes.
    /// 2. Remove trailing commas before `]` or `}` (respecting string literals).
    /// 3. Auto-wrap a single top-level JSON object in an array.
    ///
    /// Commas *inside* string literals are preserved.
    public static func fixPayload(_ payload: String) -> String {
        var s = normalizeSmartQuotes(payload)
        s = removeTrailingCommas(s)
        s = autoWrapObject(s)
        return s
    }

    /// Replaces curly/smart quotes with their straight ASCII equivalents.
    ///
    /// Curly double quotes (`“` `”`) → `"`; curly single quotes / apostrophes
    /// (`‘` `’`) → `'`. Mirrors upstream smart-quote normalisation.
    static func normalizeSmartQuotes(_ s: String) -> String {
        var result = s
        for (curly, straight) in [
            ("\u{201C}", "\""),  // “ left double
            ("\u{201D}", "\""),  // ” right double
            ("\u{2018}", "'"),   // ‘ left single
            ("\u{2019}", "'"),   // ’ right single / apostrophe
        ] {
            result = result.replacingOccurrences(of: curly, with: straight)
        }
        return result
    }

    /// Removes trailing commas that appear immediately before a closing `]` or
    /// `}` (ignoring intervening whitespace). Commas inside string literals are
    /// left untouched by tracking string/escape state.
    static func removeTrailingCommas(_ s: String) -> String {
        var out = String()
        out.reserveCapacity(s.count)

        let chars = Array(s)
        var inString = false
        var isEscaped = false

        var i = 0
        while i < chars.count {
            let c = chars[i]

            if inString {
                out.append(c)
                if isEscaped {
                    isEscaped = false
                } else if c == "\\" {
                    isEscaped = true
                } else if c == "\"" {
                    inString = false
                }
                i += 1
                continue
            }

            if c == "\"" {
                inString = true
                out.append(c)
                i += 1
                continue
            }

            if c == "," {
                // Look ahead past whitespace: drop the comma if the next
                // non-whitespace character closes an array or object.
                var j = i + 1
                while j < chars.count, chars[j].isWhitespace { j += 1 }
                if j < chars.count, chars[j] == "]" || chars[j] == "}" {
                    // Skip the comma (and the whitespace up to the closer, so the
                    // output stays tidy).
                    i = j
                    continue
                }
            }

            out.append(c)
            i += 1
        }

        return out
    }

    /// Wraps a bare top-level JSON object `{…}` in an array so downstream
    /// consumers always receive a list. Leaves an existing array unchanged.
    static func autoWrapObject(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
            return "[\(trimmed)]"
        }
        return trimmed
    }
}
