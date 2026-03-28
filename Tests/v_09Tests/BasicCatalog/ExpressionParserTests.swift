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

// Mirrors WebCore basic_catalog/expressions/expression_parser.test.ts

import Testing
import Foundation
@testable import v_09

// MARK: - DynamicValue equality helpers

/// Element-by-element equality for [DynamicValue] — DynamicValue does not conform to Equatable.
private func equal(_ lhs: [DynamicValue], _ rhs: [DynamicValue]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    return zip(lhs, rhs).allSatisfy(equalValues)
}

private func equalValues(_ lhs: DynamicValue, _ rhs: DynamicValue) -> Bool {
    switch (lhs, rhs) {
    case (.string(let a), .string(let b)):
        return a == b
    case (.number(let a), .number(let b)):
        return a == b
    case (.bool(let a), .bool(let b)):
        return a == b
    case (.dataBinding(let a), .dataBinding(let b)):
        return a == b
    case (.functionCall(let a), .functionCall(let b)):
        return a.call == b.call && a.returnType == b.returnType && a.args == b.args
    case (.array(let a), .array(let b)):
        return a == b
    default:
        return false
    }
}

// MARK: - ExpressionParserTests

@Suite("ExpressionParser")
struct ExpressionParserTests {

    private let parser = ExpressionParser()

    // MARK: - parse

    @Test("parses literal strings unchanged")
    func parsesLiteralStringsUnchanged() throws {
        let result = try parser.parse("hello world")
        #expect(equal(result, [.string("hello world")]))
    }

    @Test("parses simple interpolation")
    func parsesSimpleInterpolation() throws {
        let result = try parser.parse("hello ${foo}")
        #expect(equal(result, [.string("hello "), .dataBinding(path: "foo")]))
    }

    @Test("parses number interpolation")
    func parsesNumberInterpolation() throws {
        let result = try parser.parse("number is ${num}")
        #expect(equal(result, [.string("number is "), .dataBinding(path: "num")]))
    }

    @Test("parses nested interpolation")
    func parsesNestedInterpolation() throws {
        // ${${nested}} — the outer interpolation wraps an inner ${nested}.
        // The inner content is the path "nested"; the result is a dataBinding.
        let result = try parser.parse("val is ${${nested}}")
        #expect(equal(result, [.string("val is "), .dataBinding(path: "nested")]))
    }

    @Test("handles escaped interpolation")
    func handlesEscapedInterpolation() throws {
        // \${foo} — the backslash-dollar is treated as a literal "${", leaving "foo}" as plain text.
        let result = try parser.parse("escaped \\${foo}")
        #expect(equal(result, [.string("escaped "), .string("${"), .string("foo}")]))
    }

    @Test("parses function calls")
    func parsesFunctionCalls() throws {
        let result = try parser.parse("sum is ${add(a: 10, b: 20)}")
        let expected: [DynamicValue] = [
            .string("sum is "),
            .functionCall(FunctionCall(call: "add", args: ["a": .number(10), "b": .number(20)], returnType: .any)),
        ]
        #expect(equal(result, expected))
    }

    @Test("parses function calls with string literals")
    func parsesFunctionCallsWithStringLiterals() throws {
        let result = try parser.parse("case is ${upper(text: \"hello\")}")
        let expected: [DynamicValue] = [
            .string("case is "),
            .functionCall(FunctionCall(call: "upper", args: ["text": .string("hello")], returnType: .any)),
        ]
        #expect(equal(result, expected))
    }

    @Test("parses keywords")
    func parsesKeywords() throws {
        // parse("${true} ${false} ${null}")
        // null → .string("") which is filtered out by the empty-string filter.
        // Result: [.bool(true), .string(" "), .bool(false), .string(" ")]
        let result = try parser.parse("${true} ${false} ${null}")
        let expected: [DynamicValue] = [
            .bool(true),
            .string(" "),
            .bool(false),
            .string(" "),
        ]
        #expect(equal(result, expected))
    }

    @Test("returns error on max depth exceeded")
    func returnsErrorOnMaxDepthExceeded() {
        #expect(throws: A2uiExpressionError.self) {
            try parser.parse("depth", depth: 11)
        }
    }

    @Test("handles deep recursion gracefully")
    func handlesDeepRecursionGracefully() throws {
        // ${${"hello"}} — inner expression is a string literal "hello",
        // nested parse resolves it to .string("hello").
        let result = try parser.parse("${${\"hello\"}}")
        #expect(equal(result, [.string("hello")]))
    }

    @Test("returns error on unclosed interpolation")
    func returnsErrorOnUnclosedInterpolation() {
        #expect(throws: A2uiExpressionError.self) {
            try parser.parse("hello ${world")
        }
    }

    @Test("returns error on invalid function syntax")
    func returnsErrorOnInvalidFunctionSyntax() {
        // Missing closing ')': ${add(a: 1, b: 2}
        #expect(throws: A2uiExpressionError.self) {
            try parser.parse("${add(a: 1, b: 2}")
        }
    }

    @Test("returns error on unexpected characters at end")
    func returnsErrorOnUnexpectedCharactersAtEnd() {
        // ${true false} — "true" is consumed as keyword, " false" remains
        #expect(throws: A2uiExpressionError.self) {
            try parser.parse("${true false}")
        }
    }

    // MARK: - parseExpression

    @Test("handles empty identifiers")
    func handlesEmptyIdentifiers() throws {
        // parse("${()}") → [.functionCall(FunctionCall(call: "", args: [:], returnType: "any"))]
        let parseResult = try parser.parse("${()}")
        let expectedParse: [DynamicValue] = [
            .functionCall(FunctionCall(call: "", args: [:], returnType: .any)),
        ]
        #expect(equal(parseResult, expectedParse))

        // parseExpression("") → .string("")
        let emptyExpr = try parser.parseExpression("")
        #expect(equalValues(emptyExpr, .string("")))

        // parseExpression("()") → .functionCall(FunctionCall(call: "", args: [:], returnType: "any"))
        let funcExpr = try parser.parseExpression("()")
        #expect(equalValues(funcExpr, .functionCall(FunctionCall(call: "", args: [:], returnType: .any))))
    }

    @Test("handles string literals with escaped characters")
    func handlesStringLiteralsWithEscapedCharacters() throws {
        // Single-quoted string with \n, \t, \r, \', \\ escape sequences
        let result = try parser.parseExpression("'line1\\nline2\\t\\r\\'\\\\x'")
        #expect(equalValues(result, .string("line1\nline2\t\r'\\x")))
    }

    @Test("handles parsing paths with special characters")
    func handlesParsingPathsWithSpecialCharacters() throws {
        // Path identifiers may include hyphens and underscores
        let result = try parser.parseExpression("my-path.with_underscores")
        #expect(equalValues(result, .dataBinding(path: "my-path.with_underscores")))
    }

    @Test("returns error on missing colon in function args")
    func returnsErrorOnMissingColonInFunctionArgs() {
        // add(a 10, b: 20) — missing ':' after argument name 'a'
        #expect(throws: A2uiExpressionError.self) {
            try parser.parseExpression("add(a 10, b: 20)")
        }
    }
}
