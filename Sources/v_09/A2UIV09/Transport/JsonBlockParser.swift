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

// MARK: - JsonBlockParser

/// Utility for extracting and stripping JSON blocks from raw LLM text.
///
/// Mirrors Flutter's `JsonBlockParser` in
/// `packages/genui/lib/src/utils/json_block_parser.dart`.
///
/// Two wire formats are supported:
/// - **Markdown code block** — ` ```json … ``` ` or ` ``` … ``` `
/// - **Bare balanced JSON** — `{…}` detected via balanced-brace matching
///
/// Markdown blocks are tried first (higher confidence); raw JSON is the fallback.
public enum JsonBlockParser {

    // MARK: - Public API

    /// Extracts all valid JSON objects or arrays found in `text`.
    ///
    /// Mirrors Flutter `JsonBlockParser.parseJsonBlocks`.
    ///
    /// - Parameter text: Raw LLM output that may contain JSON blocks.
    /// - Returns: Decoded JSON values (`[String: Any]` or `[Any]`).
    ///   Empty if no valid JSON block is found.
    public static func parseJsonBlocks(_ text: String) -> [Any] {
        var results: [Any] = []

        // 1. Try markdown code blocks first (```json … ``` or ``` … ```)
        let range = NSRange(text.startIndex..., in: text)
        let matches = markdownRegex.matches(in: text, range: range)
        for match in matches {
            if let captureRange = Range(match.range(at: 1), in: text) {
                let content = String(text[captureRange])
                if let data = content.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) {
                    results.append(json)
                }
            }
        }
        if !results.isEmpty { return results }

        // 2. Fallback: find the first balanced raw JSON block
        if let block = parseFirstJsonBlock(text) {
            results.append(block)
        }
        return results
    }

    /// Strips all JSON blocks from `text`, returning only the prose portions.
    ///
    /// Mirrors Flutter `JsonBlockParser.stripJsonBlock`.
    ///
    /// - Parameter text: Raw LLM output that may contain JSON blocks.
    /// - Returns: The text with all markdown-fenced and bare JSON blocks removed,
    ///   trimmed of leading/trailing whitespace.
    public static func stripJsonBlock(_ text: String) -> String {
        var result = text

        // Remove markdown fenced blocks
        let range = NSRange(result.startIndex..., in: result)
        result = markdownStripRegex.stringByReplacingMatches(
            in: result, range: range, withTemplate: ""
        )

        // Remove bare balanced JSON blocks
        let chars = Array(result)
        var stripped = ""
        var i = chars.startIndex
        while i < chars.endIndex {
            let ch = chars[i]
            if ch == "{" || ch == "[" {
                let sub = String(chars[i...])
                if let balanced = extractBalancedJson(sub) {
                    i = chars.index(i, offsetBy: balanced.count)
                    continue
                }
            }
            stripped.append(ch)
            i = chars.index(after: i)
        }

        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Internal helpers

    /// Finds and decodes the first balanced `{…}` or `[…]` block in `text`.
    ///
    /// Mirrors Flutter `JsonBlockParser.parseFirstJsonBlock`.
    static func parseFirstJsonBlock(_ text: String) -> Any? {
        let chars = Array(text)
        for idx in chars.indices {
            let ch = chars[idx]
            guard ch == "{" || ch == "[" else { continue }
            let sub = String(chars[idx...])
            if let balanced = extractBalancedJson(sub),
               let data = balanced.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) {
                return json
            }
        }
        return nil
    }

    /// Returns the shortest balanced JSON string that starts at the beginning of `input`,
    /// or `nil` if the input doesn't start with `{` or `[` or the braces never balance.
    ///
    /// Mirrors Flutter `JsonBlockParser._extractBalancedJson`.
    static func extractBalancedJson(_ input: String) -> String? {
        guard let first = input.first, first == "{" || first == "[" else { return nil }
        let endChar: Character = first == "{" ? "}" : "]"
        var balance   = 0
        var inString  = false
        var isEscaped = false
        for (index, char) in input.enumerated() {
            if isEscaped  { isEscaped = false; continue }
            if char == "\\" { isEscaped = true;  continue }
            if char == "\"" { inString.toggle();  continue }
            if !inString {
                if char == first   { balance += 1 }
                else if char == endChar {
                    balance -= 1
                    if balance == 0 {
                        let end = input.index(input.startIndex, offsetBy: index + 1)
                        return String(input[..<end])
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Compiled regexes (reused across calls)

    /// Captures the inner content of ` ```json … ``` ` or ` ``` … ``` ` blocks.
    private static let markdownRegex = try! NSRegularExpression(
        pattern: #"```(?:json)?\s*([\s\S]*?)\s*```"#
    )

    /// Matches the full ` ```json … ``` ` or ` ``` … ``` ` block for stripping.
    private static let markdownStripRegex = try! NSRegularExpression(
        pattern: #"```(?:json)?\s*[\s\S]*?\s*```"#
    )
}
