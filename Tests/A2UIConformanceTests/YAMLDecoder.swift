// Tests/A2UIConformanceTests/YAMLDecoder.swift
// Minimal YAML parser sufficient for the A2UI conformance suite files.
// Handles: top-level sequences of mappings, nested block mappings/sequences,
// block scalars (| and >), flow sequences/mappings (possibly spanning multiple
// lines), single- and double-quoted strings, and string/int/bool/null scalars.
// Does NOT handle anchors, aliases, explicit tags, or directives.

import Foundation

enum YAMLError: Error {
    case parse(String)
}

/// Parse a YAML document. Returns the top-level value, typically `[Any]` for
/// conformance suite files (a top-level sequence of test-case mappings).
func parseYAML(_ text: String) throws -> Any {
    var scanner = YAMLScanner(text)
    return try scanner.parseTopLevel()
}

// MARK: - Scanner

private struct YAMLScanner {
    let source: [Character]
    var pos: Int = 0

    init(_ text: String) {
        source = Array(text)
    }

    // MARK: Helpers

    mutating func parseTopLevel() throws -> Any {
        skipBlankLines()
        guard pos < source.count else { return NSNull() }
        let lineIndent = peekLineIndent()
        let firstChar = charAtLineStart()
        if firstChar == "-" {
            return try parseBlockSequence(atIndent: lineIndent)
        }
        if firstChar == "[" {
            advancePastIndent()
            return try parseFlowSequence()
        }
        if firstChar == "{" {
            advancePastIndent()
            return try parseFlowMapping()
        }
        if lineHasMappingKey() {
            return try parseBlockMapping(atIndent: lineIndent)
        }
        advancePastIndent()
        let raw = collectScalar()
        return parseScalar(raw)
    }

    /// Indent of the next line without moving pos.
    func peekLineIndent() -> Int {
        var i = pos
        var col = 0
        while i < source.count && source[i] == " " { col += 1; i += 1 }
        return col
    }

    /// First non-space char on the current line.
    func charAtLineStart() -> Character? {
        var i = pos
        while i < source.count && source[i] == " " { i += 1 }
        guard i < source.count else { return nil }
        return source[i]
    }

    /// Move pos past leading spaces.
    mutating func advancePastIndent() {
        while pos < source.count && source[pos] == " " { pos += 1 }
    }

    /// Does the current line look like a mapping key (key: value)?
    func lineHasMappingKey() -> Bool {
        var i = pos
        while i < source.count && source[i] == " " { i += 1 }
        return lookaheadIsMappingKey(from: i)
    }

    func lookaheadIsMappingKey(from start: Int) -> Bool {
        var i = start
        if i < source.count && (source[i] == "\"" || source[i] == "'") {
            let q = source[i]; i += 1
            while i < source.count && source[i] != q { i += 1 }
            i += 1
            while i < source.count && source[i] == " " { i += 1 }
            return i < source.count && source[i] == ":"
        }
        while i < source.count && source[i] != "\n" {
            let ch = source[i]
            if ch == ":" {
                let next = (i + 1 < source.count) ? source[i + 1] : "\0"
                if next == " " || next == "\n" || next == "\t" { return true }
            }
            i += 1
        }
        return false
    }

    /// Skip blank lines and comment-only lines, leaving pos at next content.
    mutating func skipBlankLines() {
        while pos < source.count {
            let start = pos
            while pos < source.count && (source[pos] == " " || source[pos] == "\t") { pos += 1 }
            if pos < source.count {
                if source[pos] == "\n" { pos += 1; continue }
                if source[pos] == "\r" { pos += 1; continue }
                if source[pos] == "#" {
                    while pos < source.count && source[pos] != "\n" { pos += 1 }
                    if pos < source.count { pos += 1 }
                    continue
                }
            }
            pos = start; break
        }
    }

    mutating func skipLineWhitespace() {
        while pos < source.count && (source[pos] == " " || source[pos] == "\t") { pos += 1 }
        if pos < source.count && source[pos] == "#" {
            while pos < source.count && source[pos] != "\n" { pos += 1 }
        }
    }

    mutating func consumeNewline() {
        if pos < source.count && source[pos] == "\n" { pos += 1 }
        else if pos < source.count && source[pos] == "\r" {
            pos += 1
            if pos < source.count && source[pos] == "\n" { pos += 1 }
        }
    }

    mutating func consumeRestOfLine() {
        while pos < source.count && source[pos] != "\n" { pos += 1 }
        consumeNewline()
    }

    // MARK: Block sequence

    mutating func parseBlockSequence(atIndent seqIndent: Int) throws -> [Any] {
        var result: [Any] = []
        while pos < source.count {
            skipBlankLines()
            guard pos < source.count else { break }
            let lineIndent = peekLineIndent()
            if lineIndent < seqIndent { break }
            if lineIndent > seqIndent { break }

            // Must be a "- " or "-\n" entry.
            var look = pos
            while look < source.count && source[look] == " " { look += 1 }
            guard look < source.count && source[look] == "-" else { break }
            let next = (look + 1 < source.count) ? source[look + 1] : "\0"
            guard next == " " || next == "\n" || next == "\t" else { break }

            pos = look + 1  // past "-"
            if pos < source.count && (source[pos] == " " || source[pos] == "\t") { pos += 1 }

            skipLineWhitespace()

            if pos >= source.count || source[pos] == "\n" {
                consumeNewline()
                skipBlankLines()
                if pos < source.count {
                    let childIndent = peekLineIndent()
                    if childIndent > seqIndent {
                        result.append(try parseValue(atIndent: childIndent))
                    } else {
                        result.append(NSNull())
                    }
                } else {
                    result.append(NSNull())
                }
            } else {
                // Inline content.
                let ch = source[pos]
                if ch == "[" {
                    result.append(try parseFlowSequence())
                    consumeRestOfLine()
                } else if ch == "{" {
                    result.append(try parseFlowMapping())
                    consumeRestOfLine()
                } else if ch == "|" || ch == ">" {
                    result.append(try parseBlockScalar(keyIndent: seqIndent + 2))
                } else if lookaheadIsMappingKey(from: pos) {
                    // Inline mapping: first key starts here, continuation lines
                    // are at seqIndent + 2.
                    result.append(try parseInlineBlockMapping(keyIndent: seqIndent + 2))
                } else {
                    let raw = collectScalar()
                    result.append(parseScalar(raw))
                    consumeRestOfLine()
                }
            }
        }
        return result
    }

    // MARK: Block mapping

    mutating func parseBlockMapping(atIndent mapIndent: Int) throws -> [String: Any] {
        var result: [String: Any] = [:]
        while pos < source.count {
            skipBlankLines()
            guard pos < source.count else { break }
            let lineIndent = peekLineIndent()
            if lineIndent < mapIndent { break }
            if lineIndent > mapIndent { break }  // unexpected deeper indent

            var look = pos
            while look < source.count && source[look] == " " { look += 1 }
            guard look < source.count else { break }

            // Sequence item in this context? Stop.
            if source[look] == "-" {
                let nx = (look + 1 < source.count) ? source[look + 1] : "\0"
                if nx == " " || nx == "\n" { break }
            }

            pos = look
            let (key, value) = try parseKeyValuePair(mapIndent: mapIndent)
            result[key] = value
        }
        return result
    }

    /// Parse a single key: value pair starting at current pos (already
    /// positioned at the key character, no leading spaces).
    /// `mapIndent` is used to determine when nested block values end.
    mutating func parseKeyValuePair(mapIndent: Int) throws -> (String, Any) {
        let key = try parseKey()
        skipLineWhitespace()
        guard pos < source.count && source[pos] == ":" else {
            return (key, NSNull())
        }
        pos += 1  // consume ":"

        if pos < source.count && (source[pos] == " " || source[pos] == "\t") { pos += 1 }
        skipLineWhitespace()

        let value: Any
        if pos >= source.count || source[pos] == "\n" {
            consumeNewline()
            skipBlankLines()
            if pos < source.count {
                let childIndent = peekLineIndent()
                if childIndent > mapIndent {
                    value = try parseValue(atIndent: childIndent)
                } else {
                    value = NSNull()
                }
            } else {
                value = NSNull()
            }
        } else {
            let ch = source[pos]
            if ch == "[" {
                value = try parseFlowSequence()
                consumeRestOfLine()
            } else if ch == "{" {
                value = try parseFlowMapping()
                consumeRestOfLine()
            } else if ch == "|" || ch == ">" {
                value = try parseBlockScalar(keyIndent: mapIndent + 2)
            } else {
                let raw = collectScalar()
                value = parseScalar(raw)
                consumeRestOfLine()
            }
        }
        return (key, value)
    }

    /// Parse a block mapping where the first key starts inline (e.g. after "- ").
    /// Continuation keys must be at `keyIndent`.
    mutating func parseInlineBlockMapping(keyIndent: Int) throws -> [String: Any] {
        var result: [String: Any] = [:]
        // First key-value is on the current line (pos already at first char).
        let (k0, v0) = try parseKeyValuePair(mapIndent: keyIndent)
        result[k0] = v0
        // Collect additional keys at keyIndent.
        while pos < source.count {
            skipBlankLines()
            guard pos < source.count else { break }
            let lineIndent = peekLineIndent()
            if lineIndent < keyIndent { break }
            if lineIndent > keyIndent { break }

            var look = pos
            while look < source.count && source[look] == " " { look += 1 }
            guard look < source.count else { break }
            if source[look] == "-" { break }

            pos = look
            let (key, value) = try parseKeyValuePair(mapIndent: keyIndent)
            result[key] = value
        }
        return result
    }

    // MARK: Dispatch

    mutating func parseValue(atIndent indent: Int) throws -> Any {
        skipBlankLines()
        guard pos < source.count else { return NSNull() }

        let lineIndent = peekLineIndent()
        var look = pos
        while look < source.count && source[look] == " " { look += 1 }
        guard look < source.count else { return NSNull() }
        let ch = source[look]

        if ch == "-" {
            let nx = (look + 1 < source.count) ? source[look + 1] : "\0"
            if nx == " " || nx == "\n" {
                return try parseBlockSequence(atIndent: lineIndent)
            }
        }
        if ch == "[" {
            pos = look
            return try parseFlowSequence()
        }
        if ch == "{" {
            pos = look
            return try parseFlowMapping()
        }
        if lookaheadIsMappingKey(from: look) {
            return try parseBlockMapping(atIndent: lineIndent)
        }
        pos = look
        let raw = collectScalar()
        return parseScalar(raw)
    }

    // MARK: Block scalar

    mutating func parseBlockScalar(keyIndent: Int) throws -> String {
        let indicator = source[pos]; pos += 1

        var chompStrip = false
        while pos < source.count && source[pos] != "\n" {
            if source[pos] == "-" { chompStrip = true }
            pos += 1
        }
        consumeNewline()

        var blockIndent = -1
        var lines: [String] = []
        while pos < source.count {
            var i = pos
            var lineCol = 0
            while i < source.count && source[i] == " " { lineCol += 1; i += 1 }
            let lineIsBlank = (i >= source.count || source[i] == "\n" || source[i] == "\r")
            if lineIsBlank {
                lines.append("")
                while pos < source.count && source[pos] != "\n" { pos += 1 }
                consumeNewline()
                continue
            }
            if blockIndent == -1 { blockIndent = lineCol }
            if lineCol < blockIndent { break }
            pos += blockIndent
            var chars: [Character] = []
            while pos < source.count && source[pos] != "\n" {
                chars.append(source[pos]); pos += 1
            }
            consumeNewline()
            lines.append(String(chars))
        }

        // Remove trailing blank lines for clip (default) or strip.
        if chompStrip {
            while lines.last == "" { lines.removeLast() }
        }

        if indicator == "|" {
            var result = lines.joined(separator: "\n")
            if !chompStrip { result += "\n" }
            return result
        } else {
            var parts: [String] = []
            for line in lines {
                if line.isEmpty {
                    parts.append("\n")
                } else if let last = parts.last, !last.hasSuffix("\n") {
                    parts[parts.count - 1] = last + " " + line
                } else {
                    parts.append(line)
                }
            }
            var result = parts.joined()
            if !chompStrip { result += "\n" }
            return result
        }
    }

    // MARK: Flow sequence

    mutating func parseFlowSequence() throws -> [Any] {
        guard pos < source.count && source[pos] == "[" else {
            throw YAMLError.parse("Expected '['")
        }
        pos += 1
        var result: [Any] = []
        skipFlowWhitespace()
        if pos < source.count && source[pos] == "]" { pos += 1; return result }
        while pos < source.count {
            skipFlowWhitespace()
            if pos < source.count && source[pos] == "]" { pos += 1; break }
            result.append(try parseFlowValue())
            skipFlowWhitespace()
            if pos < source.count && source[pos] == "," { pos += 1 }
            skipFlowWhitespace()
            if pos < source.count && source[pos] == "]" { pos += 1; break }
        }
        return result
    }

    // MARK: Flow mapping

    mutating func parseFlowMapping() throws -> [String: Any] {
        guard pos < source.count && source[pos] == "{" else {
            throw YAMLError.parse("Expected '{'")
        }
        pos += 1
        var result: [String: Any] = [:]
        skipFlowWhitespace()
        if pos < source.count && source[pos] == "}" { pos += 1; return result }
        while pos < source.count {
            skipFlowWhitespace()
            if pos < source.count && source[pos] == "}" { pos += 1; break }
            let key: String
            if pos < source.count && source[pos] == "\"" {
                key = try parseDoubleQuotedString()
            } else if pos < source.count && source[pos] == "'" {
                key = parseSingleQuotedString()
            } else {
                var chars: [Character] = []
                while pos < source.count {
                    let c = source[pos]
                    if c == ":" || c == "," || c == "}" || c == "\n" { break }
                    chars.append(c); pos += 1
                }
                key = String(chars).trimmingCharacters(in: .whitespaces)
            }
            skipFlowWhitespace()
            if pos < source.count && source[pos] == ":" { pos += 1 }
            skipFlowWhitespace()
            result[key] = try parseFlowValue()
            skipFlowWhitespace()
            if pos < source.count && source[pos] == "," { pos += 1 }
            skipFlowWhitespace()
            if pos < source.count && source[pos] == "}" { pos += 1; break }
        }
        return result
    }

    mutating func skipFlowWhitespace() {
        while pos < source.count {
            let ch = source[pos]
            if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
                pos += 1
            } else if ch == "#" {
                while pos < source.count && source[pos] != "\n" { pos += 1 }
            } else {
                break
            }
        }
    }

    mutating func parseFlowValue() throws -> Any {
        skipFlowWhitespace()
        guard pos < source.count else { return NSNull() }
        let ch = source[pos]
        if ch == "[" { return try parseFlowSequence() }
        if ch == "{" { return try parseFlowMapping() }
        if ch == "\"" { return try parseDoubleQuotedString() }
        if ch == "'" { return parseSingleQuotedString() }
        var chars: [Character] = []
        while pos < source.count {
            let c = source[pos]
            if c == "," || c == "]" || c == "}" { break }
            if c == "\n" || c == "\r" {
                pos += 1
                skipFlowWhitespace()
                if !chars.isEmpty { chars.append(" ") }
                continue
            }
            if c == "#" {
                while pos < source.count && source[pos] != "\n" { pos += 1 }
                continue
            }
            chars.append(c); pos += 1
        }
        let raw = String(chars).trimmingCharacters(in: .whitespaces)
        return parseScalar(raw)
    }

    // MARK: Quoted strings

    mutating func parseDoubleQuotedString() throws -> String {
        guard pos < source.count && source[pos] == "\"" else {
            throw YAMLError.parse("Expected '\"'")
        }
        pos += 1
        var chars: [Character] = []
        while pos < source.count {
            let c = source[pos]; pos += 1
            if c == "\"" { break }
            if c == "\\" && pos < source.count {
                let esc = source[pos]; pos += 1
                switch esc {
                case "n": chars.append("\n")
                case "t": chars.append("\t")
                case "r": chars.append("\r")
                case "\"": chars.append("\"")
                case "\\": chars.append("\\")
                case "/": chars.append("/")
                case "b": chars.append("\u{08}")
                case "f": chars.append("\u{0C}")
                case "u":
                    var hex = ""
                    for _ in 0..<4 {
                        if pos < source.count { hex.append(source[pos]); pos += 1 }
                    }
                    if let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) {
                        chars.append(Character(scalar))
                    }
                default: chars.append(esc)
                }
            } else {
                chars.append(c)
            }
        }
        return String(chars)
    }

    mutating func parseSingleQuotedString() -> String {
        guard pos < source.count && source[pos] == "'" else { return "" }
        pos += 1
        var chars: [Character] = []
        while pos < source.count {
            let c = source[pos]; pos += 1
            if c == "'" {
                if pos < source.count && source[pos] == "'" {
                    chars.append("'"); pos += 1
                } else {
                    break
                }
            } else {
                chars.append(c)
            }
        }
        return String(chars)
    }

    // MARK: Key parsing

    mutating func parseKey() throws -> String {
        guard pos < source.count else { throw YAMLError.parse("Expected key") }
        let ch = source[pos]
        if ch == "\"" { return try parseDoubleQuotedString() }
        if ch == "'" { return parseSingleQuotedString() }
        var chars: [Character] = []
        while pos < source.count {
            let c = source[pos]
            if c == ":" {
                let nx = (pos + 1 < source.count) ? source[pos + 1] : "\0"
                if nx == " " || nx == "\n" || nx == "\t" { break }
            }
            if c == "\n" { break }
            chars.append(c); pos += 1
        }
        return String(chars).trimmingCharacters(in: .whitespaces)
    }

    // MARK: Scalar

    mutating func collectScalar() -> String {
        var chars: [Character] = []
        while pos < source.count {
            let c = source[pos]
            if c == "\n" { break }
            if c == "#" {
                if let last = chars.last, last == " " || last == "\t" { break }
                if chars.isEmpty { break }
            }
            chars.append(c); pos += 1
        }
        return String(chars).trimmingCharacters(in: .whitespaces)
    }

    func parseScalar(_ s: String) -> Any {
        if s == "null" || s == "~" || s.isEmpty { return NSNull() }
        if s == "true" || s == "True" || s == "TRUE" { return true }
        if s == "false" || s == "False" || s == "FALSE" { return false }
        if let i = Int(s) { return i }
        if let d = Double(s) { return d }
        if s.count >= 2 {
            let first = s.first!, last = s.last!
            if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                return String(s.dropFirst().dropLast())
            }
        }
        return s
    }
}
