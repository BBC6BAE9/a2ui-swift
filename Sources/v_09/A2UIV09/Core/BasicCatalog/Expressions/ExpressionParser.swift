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

// MARK: - ExpressionParser

/// A parser for A2UI expressions, supporting string interpolation and functional calls.
///
/// The parser converts strings with `${...}` placeholders into arrays of `DynamicValue`s.
/// It supports literals (strings, numbers, booleans), path-based data bindings, and
/// nested function calls with named arguments.
///
/// Mirrors WebCore `ExpressionParser` in basic_catalog/expressions/expression_parser.ts.
public final class ExpressionParser {

    /// The maximum allowed recursion depth for nested expressions to prevent stack overflows.
    private static let maxDepth = 10

    public init() {}

    // MARK: - Public API

    /// Parses an input string into an array of DynamicValues.
    /// If the input contains no interpolation, it returns the raw string as a single literal.
    public func parse(_ input: String, depth: Int = 0) throws -> [DynamicValue] {
        if depth > ExpressionParser.maxDepth {
            throw A2uiExpressionError("Max recursion depth reached in parse")
        }
        guard !input.isEmpty, input.contains("${") else {
            return [.string(input)]
        }

        var parts: [DynamicValue] = []
        let scanner = Scanner(input)

        while !scanner.isAtEnd {
            if scanner.matches("${") {
                scanner.advance(2)
                let content = try extractInterpolationContent(scanner)
                let parsed = try parseExpression(content, depth: depth + 1)
                parts.append(parsed)
            } else if scanner.peek() == "\\" && scanner.peek(1) == "$" && scanner.peek(2) == "{" {
                scanner.advance()
                parts.append(.string("${"))
                scanner.advance(2)
            } else {
                let start = scanner.pos
                while !scanner.isAtEnd {
                    if scanner.matches("${") { break }
                    if scanner.peek() == "\\" && scanner.peek(1) == "$" && scanner.peek(2) == "{" { break }
                    scanner.advance()
                }
                let text = scanner.substring(from: start, to: scanner.pos)
                if !text.isEmpty {
                    parts.append(.string(text))
                }
            }
        }

        // Filter out empty strings (mirrors TS: filter p !== null && p !== "")
        return parts.filter {
            if case .string(let s) = $0 { return !s.isEmpty }
            return true
        }
    }

    /// Parses a single expression string (the content inside `${...}`) into a DynamicValue.
    public func parseExpression(_ expr: String, depth: Int = 0) throws -> DynamicValue {
        let trimmed = expr.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .string("") }

        let scanner = Scanner(trimmed)
        let result = try parseExpressionInternal(scanner, depth: depth)
        if !scanner.isAtEnd {
            throw A2uiExpressionError(
                "Unexpected characters at end of expression: '\(scanner.substring(from: scanner.pos, to: scanner.input.count))'",
                expression: expr
            )
        }
        return result
    }

    // MARK: - Private Parsing

    private func extractInterpolationContent(_ scanner: Scanner) throws -> String {
        let start = scanner.pos
        var braceBalance = 1

        while !scanner.isAtEnd && braceBalance > 0 {
            let char = scanner.advanceChar()
            if char == "{" {
                braceBalance += 1
            } else if char == "}" {
                braceBalance -= 1
            } else if char == "'" || char == "\"" {
                let quote = char
                while !scanner.isAtEnd {
                    let c = scanner.advanceChar()
                    if c == "\\" {
                        scanner.advance() // skip escaped char
                    } else if c == quote {
                        break
                    }
                }
            }
        }

        if braceBalance > 0 {
            throw A2uiExpressionError("Unclosed interpolation: missing '}'")
        }

        // pos is now past the closing `}`, so content is start..<(pos-1)
        return scanner.substring(from: start, to: scanner.pos - 1)
    }

    private func parseExpressionInternal(_ scanner: Scanner, depth: Int) throws -> DynamicValue {
        scanner.skipWhitespace()
        guard !scanner.isAtEnd else { return .string("") }

        // 0. Nested interpolation block: ${...}
        if scanner.matches("${") {
            scanner.advance(2)
            let content = try extractInterpolationContent(scanner)
            return try parseExpression(content, depth: depth + 1)
        }

        // 1. String literal: '...' or "..."
        if scanner.peek() == "'" || scanner.peek() == "\"" {
            let s = parseStringLiteral(scanner)
            return .string(s)
        }

        // 2. Number literal
        if isDigit(scanner.peek()) {
            let n = parseNumberLiteral(scanner)
            return .number(n)
        }

        // 3. Boolean / null keywords
        if scanner.matchesKeyword("true") { return .bool(true) }
        if scanner.matchesKeyword("false") { return .bool(false) }
        if scanner.matchesKeyword("null") { return .string("") }

        // 4. Identifier / path / function call
        let token = scanPathOrIdentifier(scanner)
        scanner.skipWhitespace()

        if scanner.peek() == "(" {
            let fc = try parseFunctionCall(name: token, scanner: scanner, depth: depth)
            return .functionCall(fc)
        } else {
            if token.isEmpty { return .string("") }
            return .dataBinding(path: token)
        }
    }

    private func scanPathOrIdentifier(_ scanner: Scanner) -> String {
        let start = scanner.pos
        while !scanner.isAtEnd {
            let c = scanner.peek()
            if isAlnum(c) || c == "/" || c == "." || c == "_" || c == "-" {
                scanner.advance()
            } else {
                break
            }
        }
        return scanner.substring(from: start, to: scanner.pos)
    }

    private func parseFunctionCall(name: String, scanner: Scanner, depth: Int) throws -> FunctionCall {
        scanner.match("(")
        scanner.skipWhitespace()

        var args: [String: AnyCodable] = [:]

        while !scanner.isAtEnd && scanner.peek() != ")" {
            let argName = scanIdentifier(scanner)
            scanner.skipWhitespace()
            if !scanner.match(":") {
                throw A2uiExpressionError(
                    "Expected ':' after argument name '\(argName)' in function '\(name)'",
                    expression: name
                )
            }
            scanner.skipWhitespace()

            let argValue = try parseExpressionInternal(scanner, depth: depth)
            args[argName] = dynamicValueToAnyCodable(argValue)

            scanner.skipWhitespace()
            if scanner.peek() == "," {
                scanner.advance()
                scanner.skipWhitespace()
            }
        }

        if !scanner.match(")") {
            throw A2uiExpressionError(
                "Expected ')' after function arguments for '\(name)'",
                expression: name
            )
        }

        return FunctionCall(call: name, args: args, returnType: .any)
    }

    private func scanIdentifier(_ scanner: Scanner) -> String {
        let start = scanner.pos
        while !scanner.isAtEnd && (isAlnum(scanner.peek()) || scanner.peek() == "_") {
            scanner.advance()
        }
        return scanner.substring(from: start, to: scanner.pos)
    }

    private func parseStringLiteral(_ scanner: Scanner) -> String {
        let quote = scanner.advanceChar()
        var result = ""
        while !scanner.isAtEnd {
            let c = scanner.advanceChar()
            if c == "\\" {
                let next = scanner.advanceChar()
                switch next {
                case "n": result += "\n"
                case "t": result += "\t"
                case "r": result += "\r"
                default: result += String(next)
                }
            } else if c == quote {
                break
            } else {
                result += String(c)
            }
        }
        return result
    }

    private func parseNumberLiteral(_ scanner: Scanner) -> Double {
        let start = scanner.pos
        while !scanner.isAtEnd && (isDigit(scanner.peek()) || scanner.peek() == ".") {
            scanner.advance()
        }
        let numStr = scanner.substring(from: start, to: scanner.pos)
        return Double(numStr) ?? Double.nan
    }

    // MARK: - Helpers

    /// Converts a DynamicValue produced during argument parsing into an AnyCodable
    /// so it can be stored in FunctionCall.args.
    private func dynamicValueToAnyCodable(_ value: DynamicValue) -> AnyCodable {
        switch value {
        case .string(let s): return .string(s)
        case .number(let n): return .number(n)
        case .bool(let b):   return .bool(b)
        case .array(let a):  return .array(a)
        case .dataBinding(let path):
            return .dictionary(["path": .string(path)])
        case .functionCall(let fc):
            var dict: [String: AnyCodable] = [
                "call": .string(fc.call),
                "args": .dictionary(fc.args)
            ]
            if let rt = fc.returnType { dict["returnType"] = .string(rt.rawValue) }
            return .dictionary(dict)
        }
    }

    private func isAlnum(_ c: Character) -> Bool {
        return c.isLetter || c.isNumber
    }

    private func isDigit(_ c: Character) -> Bool {
        return c >= "0" && c <= "9"
    }
}

// MARK: - Scanner

/// Character-by-character scanner used by ExpressionParser.
/// Mirrors the `Scanner` helper class in the TypeScript expression_parser.ts.
private final class Scanner {
    let input: [Character]
    var pos: Int = 0

    init(_ string: String) {
        self.input = Array(string)
    }

    var isAtEnd: Bool { pos >= input.count }

    func peek(_ offset: Int = 0) -> Character {
        let idx = pos + offset
        guard idx < input.count else { return "\0" }
        return input[idx]
    }

    /// Advance by `count` positions.
    func advance(_ count: Int = 1) {
        pos += count
    }

    /// Advance by one and return the consumed character.
    @discardableResult
    func advanceChar() -> Character {
        let c = input[pos]
        pos += 1
        return c
    }

    /// If the current character equals `expected`, consume it and return true.
    @discardableResult
    func match(_ expected: Character) -> Bool {
        guard !isAtEnd, input[pos] == expected else { return false }
        pos += 1
        return true
    }

    /// Returns true if the input at the current position starts with `prefix`.
    func matches(_ prefix: String) -> Bool {
        let chars = Array(prefix)
        guard pos + chars.count <= input.count else { return false }
        return input[pos..<(pos + chars.count)].elementsEqual(chars)
    }

    /// Advance and consume `keyword` if it appears at current position and is not
    /// followed by an alphanumeric character or underscore.
    @discardableResult
    func matchesKeyword(_ keyword: String) -> Bool {
        let chars = Array(keyword)
        let end = pos + chars.count
        guard end <= input.count, input[pos..<end].elementsEqual(chars) else { return false }
        // Ensure it's not followed by [a-zA-Z0-9_]
        if end < input.count {
            let next = input[end]
            if next.isLetter || next.isNumber || next == "_" { return false }
        }
        pos = end
        return true
    }

    func skipWhitespace() {
        while !isAtEnd && input[pos].isWhitespace {
            pos += 1
        }
    }

    /// Returns a String from index `from` up to (not including) `to`.
    func substring(from: Int, to: Int) -> String {
        guard from < to, from >= 0, to <= input.count else { return "" }
        return String(input[from..<to])
    }
}
