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

@testable import A2UISwiftCore
import Testing
import Foundation

// MARK: - Helpers

private let testData: [String: AnyCodable] = [
    "user": .dictionary([
        "name": .string("Alice"),
        "address": .dictionary(["city": .string("Wonderland")]),
    ]),
    "list": .array([.string("a"), .string("b")]),
]

@Suite("DataContext")
struct DataContextTests {

    // MARK: - resolveDynamicValue (路径解析)

    @Test("resolves relative paths")
    func resolvesRelativePaths() {
        let ctx = createTestDataContext(data: testData, path: "/user")
        #expect(ctx.resolveDynamicValue(DynamicValue.dataBinding(path: "name")) == .string("Alice"))
    }

    @Test("resolves absolute paths")
    func resolvesAbsolutePaths() {
        let ctx = DataContext(surface: makeSurface(data: testData), path: "/user")
        #expect(ctx.resolveDynamicValue(DynamicValue.dataBinding(path: "/list/0")) == .string("a"))
    }

    @Test("resolves nested paths")
    func resolvesNestedPaths() {
        let ctx = DataContext(surface: makeSurface(data: testData), path: "/user")
        #expect(ctx.resolveDynamicValue(DynamicValue.dataBinding(path: "address/city")) == .string("Wonderland"))
    }

    // MARK: - set

    @Test("updates data via relative path")
    func setRelativePath() throws {
        let surface = makeSurface(data: testData)
        let ctx = DataContext(surface: surface, path: "/user")
        try ctx.set("name", value: .string("Bob"))
        #expect(surface.dataModel.get("/user/name") == .string("Bob"))
    }

    // MARK: - nested

    @Test("creates nested context")
    func nestedContext() {
        let ctx = DataContext(surface: makeSurface(data: testData), path: "/user")
        let addressCtx = ctx.nested("address")
        #expect(addressCtx.path == "/user/address")
        #expect(addressCtx.resolveDynamicValue(DynamicValue.dataBinding(path: "city")) == .string("Wonderland"))
    }

    @Test("handles root context")
    func nestedFromRoot() {
        let ctx = DataContext(surface: makeSurface(data: testData), path: "/")
        #expect(ctx.resolveDynamicValue(DynamicValue.dataBinding(path: "user/name")) == .string("Alice"))
    }

    // MARK: - subscribeDynamicValue

    @Test("subscribes relative path")
    func subscribesRelativePath() throws {
        let surface = makeSurface(data: testData)
        let ctx = DataContext(surface: surface, path: "/user")
        var called = false
        let sub = ctx.subscribeDynamicValue(DynamicValue.dataBinding(path: "name")) { val in
            #expect(val == .string("Charlie"))
            called = true
        }
        try ctx.set("name", value: .string("Charlie"))
        #expect(called == true)
        sub.unsubscribe()
    }

    // MARK: - resolveDynamicValue (字面量)

    @Test("resolves using resolveDynamicValue with literals")
    func resolvesLiterals() {
        let ctx = DataContext(surface: makeSurface(data: testData), path: "/user")
        // Literal
        #expect(ctx.resolveDynamicValue(DynamicValue.string("literal")) == .string("literal"))
        // Path
        #expect(ctx.resolveDynamicValue(DynamicValue.dataBinding(path: "name")) == .string("Alice"))
        // Absolute Path
        #expect(ctx.resolveDynamicValue(DynamicValue.dataBinding(path: "/list/0")) == .string("a"))
    }

    @Test("resolves literal arrays as static")
    func resolvesLiteralArrays() {
        let ctx = DataContext(surface: makeSurface(), path: "/user")
        #expect(ctx.resolveDynamicValue(DynamicValue.array([.string("literal"), .string("array")])) == .array([.string("literal"), .string("array")]))
    }

    @Test("subscribes literal arrays as static")
    func subscribesLiteralArraysAsStatic() throws {
        let surface = makeSurface(data: testData)
        let ctx = DataContext(surface: surface, path: "/user")
        var called = false
        let sub = ctx.subscribeDynamicValue(DynamicValue.array([.string("literal"), .string("array")])) { _ in
            called = true
        }
        #expect(sub.value == .array([.string("literal"), .string("array")]))
        try ctx.set("name", value: .string("Charlie"))
        #expect(called == false)
        sub.unsubscribe()
    }

    // MARK: - 函数调用

    @Test("resolves function calls synchronously")
    func resolvesFunctionCallSync() {
        let catalog = Catalog(
            id: "test",
            functions: [
                "add": { _, args, _ in
                    let a = args["a"]?.numberValue ?? 0
                    let b = args["b"]?.numberValue ?? 0
                    return .number(a + b)
                }
            ]
        )
        let surface = SurfaceModel(id: "s1", catalog: catalog)
        let ctx = DataContext(surface: surface, path: "/user")
        let result = ctx.resolveDynamicValue(
            DynamicValue.functionCall(FunctionCall(call: "add", args: ["a": .number(1), "b": .number(2)]))
        )
        #expect(result == .number(3))
    }

    @Test("dispatches generic error on function call failure synchronously")
    func dispatchesGenericErrorOnFunctionCallFailure() {
        let catalog = Catalog(
            id: "test",
            functions: [
                "fail": { _, _, _ in throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Function invoker is not configured"]) }
            ]
        )
        let surface = SurfaceModel(id: "s1", catalog: catalog)
        var dispatchedError: A2uiClientError?
        surface.onError.subscribe { dispatchedError = $0 }
        let ctx = DataContext(surface: surface, path: "/user")

        let result = ctx.resolveDynamicValue(
            DynamicValue.functionCall(FunctionCall(call: "fail", args: [:]))
        )
        #expect(result == nil)
        #expect(dispatchedError != nil)
        #expect(dispatchedError?.code == "EXPRESSION_ERROR")
    }

    // MARK: - 对象不递归解析

    @Test("does not resolve arbitrary objects recursively")
    func doesNotResolveArbitraryObjectsRecursively() {
        let ctx = DataContext(surface: makeSurface(data: testData), path: "/user")
        // NOTE: WebCore passes a plain JS object { foo: "bar", nested: { path: "name" } }
        // directly to resolveDynamicValue (typed as `any`), and verifies the whole object
        // is returned unchanged — nested {path:} dicts are NOT resolved recursively.
        //
        // In Swift, DynamicValue has no .dictionary case; a non-{path:} dict becomes
        // .string("") when converted to DynamicValue. The equivalent test in Swift is:
        // a DynamicValue.array whose items include dict-like AnyCodable entries (including
        // a {path:} shaped dict) should be returned as-is — items are NOT resolved.
        let arr = DynamicValue.array([
            .dictionary(["foo": .string("bar"), "nested": .dictionary(["path": .string("name")])]),
            .string("literal"),
        ])
        #expect(ctx.resolveDynamicValue(arr) == .array([
            .dictionary(["foo": .string("bar"), "nested": .dictionary(["path": .string("name")])]),
            .string("literal"),
        ]))
    }

    // MARK: - path resolution edge cases

    @Test("handles path resolution edge cases")
    func pathResolutionEdgeCases() {
        let ctx = DataContext(surface: makeSurface(), path: "/user")
        #expect(ctx.nested("").path == "/user")
        #expect(ctx.nested(".").path == "/user")

        let rootCtx = DataContext(surface: makeSurface(), path: "/")
        #expect(rootCtx.nested("test").path == "/test")

        let trailingCtx = DataContext(surface: makeSurface(), path: "/user/")
        #expect(trailingCtx.nested("test").path == "/user/test")
    }

    @Test("subscribes to function calls with no args")
    func subscribesToFunctionCallsWithNoArgs() {
        let catalog = Catalog(
            id: "test",
            functions: [
                "getPi": { _, _, _ in return .number(Double.pi) }
            ]
        )
        let surface = SurfaceModel(id: "s1", catalog: catalog)
        let ctx = DataContext(surface: surface, path: "/")

        var called = false
        let sub = ctx.subscribeDynamicValue(
            DynamicValue.functionCall(FunctionCall(call: "getPi", args: [:]))
        ) { _ in called = true }

        // 初始值正确，但不因无关数据变化而重新调用
        #expect(sub.value == .number(Double.pi))
        #expect(called == false)
        sub.unsubscribe()
    }

    // MARK: - resolveAction

    @Test("resolves event actions non-recursively")
    func resolveActionEvent() {
        let ctx = DataContext(surface: makeSurface(data: testData), path: "/user")
        let action = Action.event(
            name: "save",
            context: [
                "id": DynamicValue.dataBinding(path: "name"),
                "count": DynamicValue.number(42),
            ]
        )
        let result = ctx.resolveAction(action)
        if case .dictionary(let outer) = result,
           case .dictionary(let event) = outer["event"],
           case .dictionary(let context) = event["context"] {
            // data binding 被解析
            #expect(context["id"] == .string("Alice"))
            // 数字字面量原样保留
            #expect(context["count"] == .number(42))
        } else {
            Issue.record("resolveAction did not return expected shape")
        }
    }

    @Test("resolves functionCall actions")
    func resolveActionFunctionCall() {
        let catalog = Catalog(
            id: "test",
            functions: [
                "greet": { _, args, _ in
                    let name = args["name"]?.stringValue ?? ""
                    return .string("Hello \(name)")
                }
            ]
        )
        let surface = SurfaceModel(id: "s1", catalog: catalog)
        try! surface.dataModel.set("/", value: .dictionary(testData))
        let ctx = DataContext(surface: surface, path: "/user")

        let action = Action.functionCall(FunctionCall(
            call: "greet",
            args: ["name": .dictionary(["path": .string("name")])]
        ))
        let result = ctx.resolveAction(action)
        #expect(result == .string("Hello Alice"))
    }

    // MARK: - Error Handling

    @Test("dispatches A2uiExpressionError to surface")
    func dispatchesA2uiExpressionError() {
        let catalog = Catalog(
            id: "test",
            functions: [
                "fail": { _, _, _ in throw A2uiExpressionError("Custom expr error", expression: "custom_func") }
            ]
        )
        let surface = SurfaceModel(id: "s1", catalog: catalog)
        var dispatchedError: A2uiClientError?
        surface.onError.subscribe { dispatchedError = $0 }
        let ctx = DataContext(surface: surface, path: "/")

        let result = ctx.resolveDynamicValue(
            DynamicValue.functionCall(FunctionCall(call: "fail", args: [:]))
        )

        #expect(result == nil)
        #expect(dispatchedError != nil)
        #expect(dispatchedError?.code == "EXPRESSION_ERROR")
        #expect(dispatchedError?.message == "Custom expr error")
    }

    @Test("dispatches generic Error as EXPRESSION_ERROR to surface")
    func dispatchesGenericError() {
        let catalog = Catalog(
            id: "test",
            functions: [
                "fail": { _, _, _ in throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Generic failure"]) }
            ]
        )
        let surface = SurfaceModel(id: "s1", catalog: catalog)
        var dispatchedError: A2uiClientError?
        surface.onError.subscribe { dispatchedError = $0 }
        let ctx = DataContext(surface: surface, path: "/")

        let result = ctx.resolveDynamicValue(
            DynamicValue.functionCall(FunctionCall(call: "fail", args: [:]))
        )

        #expect(result == nil)
        #expect(dispatchedError != nil)
        #expect(dispatchedError?.code == "EXPRESSION_ERROR")
    }

    // NOTE: WebCore 中 "translates ZodError into A2uiExpressionError" 测试
    // 以及 signal/computed 响应式错误传播测试（"handles errors thrown during reactive
    // argument resolution" 等）仅适用于 TypeScript 实现：
    // - ZodError 是 Zod 验证库专属，Swift 端用 Codable/类型系统替代；
    // - signal/computed 的响应式错误传播是 @preact/signals-core 专属机制，
    //   Swift 端通过 PathSlot + @Observable 实现，错误在同步调用时即被捕获。
}
