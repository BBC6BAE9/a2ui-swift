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

// Mirrors WebCore basic_catalog/functions/basic_functions.test.ts

@testable import A2UISwiftCore
import Testing
import Foundation

// MARK: - Test Fixtures

private func makeContext() throws -> (catalog: Catalog, context: DataContext) {
    let catalog = Catalog(id: "basic", functions: BASIC_FUNCTIONS)
    let surface = SurfaceModel(id: "s1", catalog: catalog)
    try surface.dataModel.set("/", value: .dictionary(["a": .number(10), "b": .number(20)]))
    let context = DataContext(surface: surface, path: "/")
    return (catalog, context)
}

@discardableResult
private func invoke(
    _ name: String,
    _ args: [String: AnyCodable],
    catalog: Catalog,
    context: DataContext
) throws -> AnyCodable? {
    return try catalog.invoker(name, args, context)
}

// MARK: - BASIC_FUNCTIONS

@Suite("BASIC_FUNCTIONS")
struct BasicFunctionsTests {

    // MARK: - Arithmetic

    @Suite("Arithmetic")
    struct ArithmeticTests {

        @Test("add")
        func add() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("add", ["a": .number(1), "b": .number(2)], catalog: catalog, context: context) == .number(3))
            // string coercion: z.coerce.number() converts "1" → 1
            #expect(try invoke("add", ["a": .string("1"), "b": .string("2")], catalog: catalog, context: context) == .number(3))
            // null → throw (null preprocess: null → undefined → ZodError)
            #expect(throws: A2uiExpressionError.self) {
                try invoke("add", ["a": .number(10), "b": .null], catalog: catalog, context: context)
            }
            // missing key → throw
            #expect(throws: A2uiExpressionError.self) {
                try invoke("add", ["a": .number(10)], catalog: catalog, context: context)
            }
        }

        @Test("subtract")
        func subtract() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("subtract", ["a": .number(5), "b": .number(3)], catalog: catalog, context: context) == .number(2))
            #expect(throws: A2uiExpressionError.self) {
                try invoke("subtract", ["a": .number(10), "b": .null], catalog: catalog, context: context)
            }
            #expect(throws: A2uiExpressionError.self) {
                try invoke("subtract", ["a": .number(10)], catalog: catalog, context: context)
            }
        }

        @Test("multiply")
        func multiply() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("multiply", ["a": .number(4), "b": .number(2)], catalog: catalog, context: context) == .number(8))
            #expect(throws: A2uiExpressionError.self) {
                try invoke("multiply", ["a": .number(10), "b": .null], catalog: catalog, context: context)
            }
            #expect(throws: A2uiExpressionError.self) {
                try invoke("multiply", ["a": .number(10)], catalog: catalog, context: context)
            }
        }

        @Test("divide")
        func divide() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("divide", ["a": .number(10), "b": .number(2)], catalog: catalog, context: context) == .number(5))

            // divide(10, 0) → Infinity
            let infResult = try invoke("divide", ["a": .number(10), "b": .number(0)], catalog: catalog, context: context)
            if case .number(let n) = infResult { #expect(n.isInfinite && n > 0) }
            else { Issue.record("Expected .number(Infinity) for divide(10, 0)") }

            // null → throw (null preprocess: null → undefined → ZodError)
            #expect(throws: A2uiExpressionError.self) {
                try invoke("divide", ["a": .number(10), "b": .null], catalog: catalog, context: context)
            }
            // missing → throw
            #expect(throws: A2uiExpressionError.self) {
                try invoke("divide", ["a": .number(10)], catalog: catalog, context: context)
            }
            // invalid string → throw (z.coerce.number() fails on non-numeric string)
            #expect(throws: A2uiExpressionError.self) {
                try invoke("divide", ["a": .number(10), "b": .string("invalid")], catalog: catalog, context: context)
            }

            // NOTE: WebCore's DivideApi uses z.coerce.number() which coerces numeric strings.
            // Swift toDouble() also coerces numeric strings, so "10" / "2" = 5.
            #expect(try invoke("divide", ["a": .string("10"), "b": .string("2")], catalog: catalog, context: context) == .number(5))
        }
    }

    // MARK: - Comparison

    @Suite("Comparison")
    struct ComparisonTests {

        @Test("equals")
        func equals() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("equals", ["a": .number(1), "b": .number(1)], catalog: catalog, context: context) == .bool(true))
            #expect(try invoke("equals", ["a": .number(1), "b": .number(2)], catalog: catalog, context: context) == .bool(false))
            // null is a valid value (any().refine only rejects undefined/missing)
            #expect(try invoke("equals", ["a": .null, "b": .null], catalog: catalog, context: context) == .bool(true))
            // missing key → throw (refine: v !== undefined)
            #expect(throws: A2uiExpressionError.self) {
                try invoke("equals", ["a": .number(1)], catalog: catalog, context: context)
            }
            #expect(throws: A2uiExpressionError.self) {
                try invoke("equals", ["b": .number(1)], catalog: catalog, context: context)
            }
        }

        @Test("not_equals")
        func notEquals() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("not_equals", ["a": .number(1), "b": .number(2)], catalog: catalog, context: context) == .bool(true))
            #expect(throws: A2uiExpressionError.self) {
                try invoke("not_equals", ["a": .number(1)], catalog: catalog, context: context)
            }
            #expect(throws: A2uiExpressionError.self) {
                try invoke("not_equals", ["b": .number(1)], catalog: catalog, context: context)
            }
        }

        @Test("greater_than")
        func greaterThan() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("greater_than", ["a": .number(5), "b": .number(3)], catalog: catalog, context: context) == .bool(true))
            #expect(try invoke("greater_than", ["a": .number(3), "b": .number(5)], catalog: catalog, context: context) == .bool(false))
            // null → throw (null preprocess: null → undefined → ZodError)
            #expect(throws: A2uiExpressionError.self) {
                try invoke("greater_than", ["a": .number(10), "b": .null], catalog: catalog, context: context)
            }
            // invalid string → throw
            #expect(throws: A2uiExpressionError.self) {
                try invoke("greater_than", ["a": .number(10), "b": .string("invalid")], catalog: catalog, context: context)
            }
            // missing → throw
            #expect(throws: A2uiExpressionError.self) {
                try invoke("greater_than", ["a": .number(10)], catalog: catalog, context: context)
            }
            #expect(throws: A2uiExpressionError.self) {
                try invoke("greater_than", ["b": .number(10)], catalog: catalog, context: context)
            }
        }

        @Test("less_than")
        func lessThan() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("less_than", ["a": .number(3), "b": .number(5)], catalog: catalog, context: context) == .bool(true))
            #expect(throws: A2uiExpressionError.self) {
                try invoke("less_than", ["a": .number(3), "b": .null], catalog: catalog, context: context)
            }
            #expect(throws: A2uiExpressionError.self) {
                try invoke("less_than", ["a": .number(3), "b": .string("invalid")], catalog: catalog, context: context)
            }
            #expect(throws: A2uiExpressionError.self) {
                try invoke("less_than", ["a": .number(3)], catalog: catalog, context: context)
            }
            #expect(throws: A2uiExpressionError.self) {
                try invoke("less_than", ["b": .number(3)], catalog: catalog, context: context)
            }
        }
    }

    // MARK: - Logical

    @Suite("Logical")
    struct LogicalTests {

        @Test("and")
        func and() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("and", ["values": .array([.bool(true), .bool(true)])], catalog: catalog, context: context) == .bool(true))
            #expect(try invoke("and", ["values": .array([.bool(true), .bool(false)])], catalog: catalog, context: context) == .bool(false))
            // fewer than 2 items → throw (min(2))
            #expect(throws: A2uiExpressionError.self) {
                try invoke("and", ["values": .array([.bool(true)])], catalog: catalog, context: context)
            }
            // missing values key → throw
            #expect(throws: A2uiExpressionError.self) {
                try invoke("and", [:], catalog: catalog, context: context)
            }
        }

        @Test("or")
        func or() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("or", ["values": .array([.bool(false), .bool(true)])], catalog: catalog, context: context) == .bool(true))
            #expect(try invoke("or", ["values": .array([.bool(false), .bool(false)])], catalog: catalog, context: context) == .bool(false))
            // fewer than 2 items → throw (min(2))
            #expect(throws: A2uiExpressionError.self) {
                try invoke("or", ["values": .array([.bool(true)])], catalog: catalog, context: context)
            }
            // missing values key → throw
            #expect(throws: A2uiExpressionError.self) {
                try invoke("or", [:], catalog: catalog, context: context)
            }
        }

        @Test("not")
        func not() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("not", ["value": .bool(false)], catalog: catalog, context: context) == .bool(true))
            #expect(try invoke("not", ["value": .bool(true)], catalog: catalog, context: context) == .bool(false))
            // null is a valid value — not(null) → true (isTruthy(null) = false)
            #expect(try invoke("not", ["value": .null], catalog: catalog, context: context) == .bool(true))
            // missing key → throw (refine: v !== undefined)
            #expect(throws: A2uiExpressionError.self) {
                try invoke("not", [:], catalog: catalog, context: context)
            }
        }
    }

    // MARK: - String

    @Suite("String")
    struct StringTests {

        @Test("contains")
        func contains() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("contains", ["string": .string("hello world"), "substring": .string("world")], catalog: catalog, context: context) == .bool(true))
            #expect(try invoke("contains", ["string": .string("hello world"), "substring": .string("foo")], catalog: catalog, context: context) == .bool(false))
            // missing key → throw
            #expect(throws: A2uiExpressionError.self) {
                try invoke("contains", ["string": .string("hello")], catalog: catalog, context: context)
            }
            #expect(throws: A2uiExpressionError.self) {
                try invoke("contains", ["substring": .string("hello")], catalog: catalog, context: context)
            }
        }

        @Test("starts_with")
        func startsWith() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("starts_with", ["string": .string("hello"), "prefix": .string("he")], catalog: catalog, context: context) == .bool(true))
            #expect(throws: A2uiExpressionError.self) {
                try invoke("starts_with", ["string": .string("hello")], catalog: catalog, context: context)
            }
            #expect(throws: A2uiExpressionError.self) {
                try invoke("starts_with", ["prefix": .string("he")], catalog: catalog, context: context)
            }
        }

        @Test("ends_with")
        func endsWith() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("ends_with", ["string": .string("hello"), "suffix": .string("lo")], catalog: catalog, context: context) == .bool(true))
            #expect(throws: A2uiExpressionError.self) {
                try invoke("ends_with", ["string": .string("hello")], catalog: catalog, context: context)
            }
            #expect(throws: A2uiExpressionError.self) {
                try invoke("ends_with", ["suffix": .string("lo")], catalog: catalog, context: context)
            }
        }

        // Spec: https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json
        // Example: https://a2ui.org/specification/v0_9/catalogs/minimal/examples/6_capitalized_text.json
        @Test("capitalize")
        func capitalize() throws {
            let (catalog, context) = try makeContext()

            // Basic: first char uppercased, rest unchanged — matches Lit renderer test
            // ("hello world" → "Hello world")
            #expect(try invoke("capitalize", ["value": .string("hello world")], catalog: catalog, context: context) == .string("Hello world"))
            // Already capitalized → unchanged
            #expect(try invoke("capitalize", ["value": .string("Hello")], catalog: catalog, context: context) == .string("Hello"))
            // All uppercase → only first char touched, rest preserved
            #expect(try invoke("capitalize", ["value": .string("HELLO")], catalog: catalog, context: context) == .string("HELLO"))
            // Single char
            #expect(try invoke("capitalize", ["value": .string("a")], catalog: catalog, context: context) == .string("A"))
            // Empty string → ""
            #expect(try invoke("capitalize", ["value": .string("")], catalog: catalog, context: context) == .string(""))
            // null → "" (falsy, same as empty)
            #expect(try invoke("capitalize", ["value": .null], catalog: catalog, context: context) == .string(""))
            // missing key → throw (spec marks value as required)
            #expect(throws: A2uiExpressionError.self) {
                try invoke("capitalize", [:], catalog: catalog, context: context)
            }
        }
    }

    // MARK: - Validation

    @Suite("Validation")
    struct ValidationTests {

        @Test("required")
        func required() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("required", ["value": .string("a")], catalog: catalog, context: context) == .bool(true))
            #expect(try invoke("required", ["value": .string("")], catalog: catalog, context: context) == .bool(false))
            #expect(try invoke("required", ["value": .null], catalog: catalog, context: context) == .bool(false))
            // missing key → throw (refine: v !== undefined)
            #expect(throws: A2uiExpressionError.self) {
                try invoke("required", [:], catalog: catalog, context: context)
            }
        }

        @Test("length")
        func length() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("length", ["value": .string("abc"), "min": .number(2)], catalog: catalog, context: context) == .bool(true))
            #expect(try invoke("length", ["value": .string("abc"), "max": .number(2)], catalog: catalog, context: context) == .bool(false))
            // missing value → throw
            #expect(throws: A2uiExpressionError.self) {
                try invoke("length", ["min": .number(1)], catalog: catalog, context: context)
            }
            // neither min nor max → throw (refine: must provide either min or max)
            #expect(throws: A2uiExpressionError.self) {
                try invoke("length", ["value": .string("abc")], catalog: catalog, context: context)
            }
        }

        @Test("numeric")
        func numeric() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("numeric", ["value": .number(10), "min": .number(5), "max": .number(15)], catalog: catalog, context: context) == .bool(true))
            #expect(try invoke("numeric", ["value": .number(3), "min": .number(5)], catalog: catalog, context: context) == .bool(false))
            // missing value → throw
            #expect(throws: A2uiExpressionError.self) {
                try invoke("numeric", ["min": .number(1)], catalog: catalog, context: context)
            }
            // neither min nor max → throw (refine: must provide either min or max)
            #expect(throws: A2uiExpressionError.self) {
                try invoke("numeric", ["value": .number(10)], catalog: catalog, context: context)
            }
        }

        @Test("email")
        func email() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("email", ["value": .string("test@example.com")], catalog: catalog, context: context) == .bool(true))
            #expect(try invoke("email", ["value": .string("test.name@example.com")], catalog: catalog, context: context) == .bool(true))
            #expect(try invoke("email", ["value": .string("test+label@example.com")], catalog: catalog, context: context) == .bool(true))
            #expect(try invoke("email", ["value": .string("test@example-domain.com")], catalog: catalog, context: context) == .bool(true))
            #expect(try invoke("email", ["value": .string("invalid")], catalog: catalog, context: context) == .bool(false))
            #expect(try invoke("email", ["value": .string("test@test")], catalog: catalog, context: context) == .bool(false))
            #expect(try invoke("email", ["value": .string("test@test.c")], catalog: catalog, context: context) == .bool(false))
            #expect(try invoke("email", ["value": .string("test@.com")], catalog: catalog, context: context) == .bool(false))
            // missing key → throw
            #expect(throws: A2uiExpressionError.self) {
                try invoke("email", [:], catalog: catalog, context: context)
            }
        }

        @Test("regex")
        func regex() throws {
            let (catalog, context) = try makeContext()

            #expect(try invoke("regex", ["value": .string("abc"), "pattern": .string("^[a-z]+$")], catalog: catalog, context: context) == .bool(true))
            #expect(try invoke("regex", ["value": .string("123"), "pattern": .string("^[a-z]+$")], catalog: catalog, context: context) == .bool(false))
        }

        @Test("regex handles invalid pattern")
        func regexInvalidPattern() throws {
            let (catalog, context) = try makeContext()

            #expect(throws: A2uiExpressionError.self) {
                try invoke("regex", ["value": .string("abc"), "pattern": .string("[")], catalog: catalog, context: context)
            }
        }
    }

    // MARK: - Formatting

    @Suite("Formatting")
    struct FormattingTests {

        @Test("formatString (static literal)")
        func formatStringStaticLiteral() throws {
            let (catalog, context) = try makeContext()
            #expect(try invoke("formatString", ["value": .string("hello world")], catalog: catalog, context: context) == .string("hello world"))
        }

        @Test("formatString (with data binding)")
        func formatStringWithDataBinding() throws {
            let catalog = Catalog(id: "basic", functions: BASIC_FUNCTIONS)
            let surface = SurfaceModel(id: "s1", catalog: catalog)
            try surface.dataModel.set("/", value: .dictionary(["a": .number(10)]))
            let context = DataContext(surface: surface, path: "/")
            let result = try invoke("formatString", ["value": .string("Value: ${a}")], catalog: catalog, context: context)
            #expect(result == .string("Value: 10"))
        }

        // MARK: Type-conversion cases — spec §"formatString type conversion"
        // Objects/Arrays MUST be serialised as JSON (not comma-joined or "[object Object]").

        @Test("formatString: array → JSON string")
        func formatStringArray() throws {
            // Spec: `"Tags: ${/tags}"` with tags=["swift","ios"]
            //       → `Tags: ["swift","ios"]`
            let catalog = Catalog(id: "basic", functions: BASIC_FUNCTIONS)
            let surface = SurfaceModel(id: "s1", catalog: catalog)
            try surface.dataModel.set(
                "/", value: .dictionary(["tags": .array([.string("swift"), .string("ios")])]))
            let context = DataContext(surface: surface, path: "/")

            let result = try invoke(
                "formatString", ["value": .string("Tags: ${/tags}")],
                catalog: catalog, context: context)
            #expect(result == .string(#"Tags: ["swift","ios"]"#))
        }

        @Test("formatString: object → JSON string")
        func formatStringObject() throws {
            // Spec: `"User: ${/user}"` with user={name:"Alice",age:30}
            //       → `User: {"name":"Alice","age":30}`  (key order must be stable)
            let catalog = Catalog(id: "basic", functions: BASIC_FUNCTIONS)
            let surface = SurfaceModel(id: "s1", catalog: catalog)
            try surface.dataModel.set(
                "/",
                value: .dictionary([
                    "user": .dictionary(["name": .string("Alice"), "age": .number(30)])
                ]))
            let context = DataContext(surface: surface, path: "/")

            let result = try invoke(
                "formatString", ["value": .string("User: ${/user}")],
                catalog: catalog, context: context)
            // JSONEncoder key order is sorted on Apple platforms, so "age" < "name".
            #expect(result == .string(#"User: {"age":30,"name":"Alice"}"#))
        }

        @Test("formatString: nested array → JSON string")
        func formatStringNestedArray() throws {
            // Spec: `"M = ${/matrix}"` with matrix=[[1,2],[3,4]]
            //       → `M = [[1,2],[3,4]]`   (must NOT flatten to "1,2,3,4")
            let catalog = Catalog(id: "basic", functions: BASIC_FUNCTIONS)
            let surface = SurfaceModel(id: "s1", catalog: catalog)
            try surface.dataModel.set(
                "/",
                value: .dictionary([
                    "matrix": .array([
                        .array([.number(1), .number(2)]),
                        .array([.number(3), .number(4)]),
                    ])
                ]))
            let context = DataContext(surface: surface, path: "/")

            let result = try invoke(
                "formatString", ["value": .string("M = ${/matrix}")],
                catalog: catalog, context: context)
            #expect(result == .string("M = [[1,2],[3,4]]"))
        }

        @Test("formatString: array with null → JSON string")
        func formatStringArrayWithNull() throws {
            // Spec: `"V = ${/vals}"` with vals=[1,null,3]
            //       → `V = [1,null,3]`    (null must NOT be silently dropped as "1,,3")
            let catalog = Catalog(id: "basic", functions: BASIC_FUNCTIONS)
            let surface = SurfaceModel(id: "s1", catalog: catalog)
            try surface.dataModel.set(
                "/",
                value: .dictionary([
                    "vals": .array([.number(1), .null, .number(3)])
                ]))
            let context = DataContext(surface: surface, path: "/")

            let result = try invoke(
                "formatString", ["value": .string("V = ${/vals}")],
                catalog: catalog, context: context)
            #expect(result == .string("V = [1,null,3]"))
        }

        @Test("formatString: scalar null/missing → empty string")
        func formatStringScalarNull() throws {
            // Spec: null/undefined → ""   (unchanged from existing behaviour)
            let catalog = Catalog(id: "basic", functions: BASIC_FUNCTIONS)
            let surface = SurfaceModel(id: "s1", catalog: catalog)
            try surface.dataModel.set("/", value: .dictionary(["x": .null]))
            let context = DataContext(surface: surface, path: "/")

            let result = try invoke(
                "formatString", ["value": .string("x=${/x}")],
                catalog: catalog, context: context)
            #expect(result == .string("x="))
        }

        // NOTE: "formatString (with function call)" is not tested.
        // WebCore's version resolves nested function-call expressions via Preact signals
        // reactive invoker — TypeScript/signals-specific behavior not applicable in Swift.

        @Test("formatNumber")
        func formatNumber() throws {
            let (catalog, context) = try makeContext()
            let result = try invoke("formatNumber", ["value": .number(1234.567), "decimals": .number(1)], catalog: catalog, context: context)
            if case .string(let s) = result {
                #expect(s.contains("1") && s.contains("234"))
            } else {
                Issue.record("Expected a string result from formatNumber")
            }
        }

        @Test("formatCurrency")
        func formatCurrency() throws {
            let (catalog, context) = try makeContext()
            let result = try invoke("formatCurrency", ["value": .number(1234.56), "currency": .string("USD"), "decimals": .number(2)], catalog: catalog, context: context)
            if case .string(let s) = result {
                #expect(s.contains("1") && (s.contains("234") || s.contains("1234")))
                #expect(s.contains("$") || s.contains("USD"))
            } else {
                Issue.record("Expected a string result from formatCurrency")
            }
        }

        @Test("formatDate")
        func formatDate() throws {
            let (catalog, context) = try makeContext()
            #expect(
                try invoke("formatDate", ["value": .string("2025-01-01T12:00:00Z"), "format": .string("yyyy-MM-dd")], catalog: catalog, context: context)
                == .string("2025-01-01")
            )
            #expect(
                try invoke("formatDate", ["value": .string("2025-01-01T12:00:00Z"), "format": .string("ISO")], catalog: catalog, context: context)
                == .string("2025-01-01T12:00:00.000Z")
            )
        }

        @Test("formatDate handles invalid dates")
        func formatDateInvalidDate() throws {
            let (catalog, context) = try makeContext()
            #expect(
                try invoke("formatDate", ["value": .string("invalid-date"), "format": .string("yyyy")], catalog: catalog, context: context)
                == .string("")
            )
        }

        @Test("formatCurrency fallback on formatting error")
        func formatCurrencyFallback() throws {
            let (catalog, context) = try makeContext()
            // NOTE: WebCore expects plain decimal fallback for invalid currency codes.
            // Swift's NumberFormatter still produces a string for unknown codes (e.g. "INV 1,234.56"),
            // so the fallback branch is unreachable on Apple platforms. We verify only that the
            // result is a non-empty string containing the numeric digits.
            let result = try invoke("formatCurrency", ["value": .number(1234.56), "currency": .string("INVALID-CURRENCY"), "decimals": .number(2)], catalog: catalog, context: context)
            if case .string(let s) = result {
                #expect(!s.isEmpty)
                #expect(s.contains("1") && s.contains("56"))
            } else {
                Issue.record("Expected a string result from formatCurrency with invalid currency code")
            }
        }
    }

    // MARK: - Actions

    @Suite("Actions")
    struct ActionsTests {
        // NOTE: "openUrl" is not unit-tested.
        // Requires UIApplication.shared (iOS) or NSWorkspace.shared (macOS) — unavailable
        // in Swift Testing without a running app environment.
    }
}
