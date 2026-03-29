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

// MARK: - DataSubscription

/// A live binding to a DynamicValue.
/// Mirrors WebCore `DataSubscription<V>`.
public final class DataSubscription<V> {
    /// The last-resolved value.
    public private(set) var value: V?

    private let _unsubscribe: () -> Void

    init(initialValue: V?, unsubscribe: @escaping () -> Void) {
        self.value = initialValue
        self._unsubscribe = unsubscribe
    }

    /// Updates the stored value (called internally by the slot observer).
    func update(_ newValue: V?) {
        self.value = newValue
    }

    /// Removes this subscription and stops reactive updates.
    public func unsubscribe() {
        _unsubscribe()
    }
}

// MARK: - SlotObserver

/// Bridges @Observable PathSlot → onChange callback using withObservationTracking.
/// Uses a class so it can be held by reference from the DataSubscription cleanup closure.
private final class SlotObserver: @unchecked Sendable {
    private let slot: PathSlot
    private let onChange: (AnyCodable?) -> Void
    private var active = true

    init(slot: PathSlot, onChange: @escaping (AnyCodable?) -> Void) {
        self.slot = slot
        self.onChange = onChange
    }

    func start() {
        observeNext()
    }

    func stop() {
        active = false
    }

    private func observeNext() {
        guard active else { return }
        withObservationTracking {
            _ = self.slot.value
        } onChange: { [weak self] in
            guard let self, self.active else { return }
            let newValue = self.slot.value
            self.onChange(newValue)
            self.observeNext()
        }
    }
}

// MARK: - DataContext

/// A contextual view of the main DataModel, serving as the unified interface for resolving
/// DynamicValues (literals, data paths, function calls) within a specific scope.
///
/// Components use `DataContext` instead of interacting with the `DataModel` directly.
/// It automatically handles resolving relative paths against the component's current scope
/// and provides tools for evaluating complex, reactive expressions.
///
/// Mirrors WebCore `DataContext`.
public final class DataContext {
    /// The shared, global DataModel instance for the entire UI surface.
    public let dataModel: DataModel
    /// The base path this context is scoped to.
    public let path: String
    /// The function invoker from the surface's catalog.
    public let functionInvoker: FunctionInvoker?

    private let surface: SurfaceModel

    /// Creates a DataContext scoped to a surface and path.
    /// The `functionInvoker` is taken from the surface's catalog.
    public init(surface: SurfaceModel, path: String) {
        self.surface = surface
        self.dataModel = surface.dataModel
        self.path = path
        self.functionInvoker = surface.catalog.invoker
    }

    // MARK: - resolvePath

    /// Resolves a path: absolute paths pass through; relative paths are joined with the base path.
    /// Mirrors WebCore `private resolvePath(path)`.
    public func resolvePath(_ inputPath: String) -> String {
        if inputPath.hasPrefix("/") { return inputPath }
        if inputPath.isEmpty || inputPath == "." { return path }

        var base = path
        if base.hasSuffix("/") && base.count > 1 {
            base = String(base.dropLast())
        }
        if base == "/" { base = "" }
        return "\(base)/\(inputPath)"
    }

    // MARK: - set

    /// Writes a value into the DataModel at the given path (relative paths resolved against base).
    /// Mirrors WebCore `DataContext.set(path, value)`.
    public func set(_ path: String, value: AnyCodable?) throws {
        let absolutePath = resolvePath(path)
        try dataModel.set(absolutePath, value: value)
    }

    // MARK: - resolveDynamicValue

    /// Resolves a `DynamicValue` into its concrete runtime value.
    ///
    /// For `dataBinding`, reads `PathSlot.value` — which is `@Observable`.
    /// When called inside a SwiftUI `body`, SwiftUI automatically tracks the
    /// PathSlot as a dependency and re-renders the view when that path changes.
    /// This is the Swift equivalent of WebCore's Preact Signal subscription;
    /// no explicit subscribe/binder mechanism is needed.
    ///
    /// Mirrors WebCore `DataContext.resolveDynamicValue<V>(value)`.
    public func resolveDynamicValue(_ value: DynamicValue) -> AnyCodable? {
        switch value {
        case .string(let s): return .string(s)
        case .number(let n): return .number(n)
        case .bool(let b): return .bool(b)
        case .array(let a): return .array(a)
        case .dataBinding(let pathStr):
            // Read PathSlot.value (@Observable) so SwiftUI builds a per-path dependency.
            // Only views whose specific path changes will re-render.
            return dataModel.slot(for: resolvePath(pathStr)).value
        case .functionCall(let fc):
            // Mirrors WebCore: each arg value is passed through resolveDynamicValue
            // before being forwarded to the invoker, so data bindings like
            // { path: "name" } inside args are resolved to their concrete values.
            var resolvedArgs: [String: AnyCodable] = [:]
            for (key, argVal) in fc.args {
                let dv = DynamicValue(from: argVal)
                resolvedArgs[key] = resolveDynamicValue(dv) ?? argVal
            }
            do {
                return try functionInvoker?(fc.call, resolvedArgs, self)
            } catch {
                dispatchExpressionError(error, functionName: fc.call)
                return nil
            }
        }
    }

    // MARK: - Typed resolve helpers (for use in SwiftUI View body)

    /// Resolves a `DynamicString` to a `String`. Reads PathSlot reactively in SwiftUI body.
    public func resolve(_ value: DynamicString) -> String {
        resolveDynamicValue(toDynamicValue(value))?.stringValue ?? ""
    }

    /// Resolves a `DynamicString?` to a `String`. Returns empty string if nil.
    public func resolve(_ value: DynamicString?) -> String {
        guard let value else { return "" }
        return resolve(value)
    }

    /// Resolves a `DynamicNumber` to a `Double?`.
    public func resolve(_ value: DynamicNumber) -> Double? {
        resolveDynamicValue(toDynamicValue(value))?.numberValue
    }

    /// Resolves a `DynamicBoolean` to a `Bool`. Defaults to `false`.
    public func resolve(_ value: DynamicBoolean) -> Bool {
        resolveDynamicValue(toDynamicValue(value))?.boolValue ?? false
    }

    /// Resolves a `DynamicStringList` to `[String]`. Defaults to empty array.
    public func resolve(_ value: DynamicStringList) -> [String] {
        guard let raw = resolveDynamicValue(toDynamicValue(value)) else { return [] }
        if let arr = raw.arrayValue { return arr.compactMap(\.stringValue) }
        return []
    }

    /// Evaluates a list of CheckRules and returns the message of the first failing check.
    /// Returns nil if all checks pass or the list is empty.
    /// Reactive in SwiftUI body — reads PathSlots via resolve(DynamicBoolean).
    public func firstFailingCheckMessage(_ checks: [CheckRule]?) -> String? {
        guard let checks, !checks.isEmpty else { return nil }
        return checks.first(where: { !resolve($0.condition) })?.message
    }

    /// Returns true when `value` is a data-binding whose path has no value yet in the model.
    /// Used by views to decide whether to show a redacted placeholder (Spec §206, §395-396).
    /// Reactive in SwiftUI body — reads PathSlot.value (@Observable).
    public func isUnresolvedBinding(_ value: DynamicString) -> Bool {
        guard case .dataBinding(let pathStr) = value else { return false }
        let absolutePath = resolvePath(pathStr)
        return dataModel.slot(for: absolutePath).value == nil
    }

    /// Converts a `Dynamic<T>` to the untyped `DynamicValue` enum for uniform resolution.
    private func toDynamicValue<T: LiteralDecodable>(_ d: Dynamic<T>) -> DynamicValue {
        switch d {
        case .dataBinding(let path): return .dataBinding(path: path)
        case .functionCall(let fc): return .functionCall(fc)
        case .literal(let v):
            // Encode via AnyCodable so we preserve the concrete type (String/Double/Bool/[String]).
            if let s = v as? String  { return .string(s) }
            if let n = v as? Double  { return .number(n) }
            if let b = v as? Bool    { return .bool(b) }
            if let arr = v as? [String] { return .array(arr.map { .string($0) }) }
            return .string("")
        }
    }

    // MARK: - resolveSignal (PathSlot-based)

    /// Returns the `PathSlot` for the given path binding — the Swift equivalent of a Preact Signal.
    /// For non-path DynamicValues (literals, function calls), returns nil.
    /// Mirrors WebCore `DataContext.resolveSignal<V>(value)` — path bindings only.
    /// Internal — consumers use resolveDynamicValue() or subscribeDynamicValue().
    func resolveSlot(for binding: DynamicValue) -> PathSlot? {
        guard case .dataBinding(let pathStr) = binding else { return nil }
        let absolutePath = resolvePath(pathStr)
        return dataModel.slot(for: absolutePath)
    }

    // MARK: - subscribeDynamicValue

    /// Creates a reactive subscription to a `DynamicValue`.
    /// The `onChange` callback is called whenever the underlying data changes.
    /// Returns a `DataSubscription` with the initial value and an `unsubscribe()` method.
    /// Mirrors WebCore `DataContext.subscribeDynamicValue<V>(value, onChange)`.
    public func subscribeDynamicValue(
        _ value: DynamicValue,
        onChange: @escaping (AnyCodable?) -> Void
    ) -> DataSubscription<AnyCodable> {
        switch value {
        case .dataBinding(let pathStr):
            let absolutePath = resolvePath(pathStr)
            let slot = dataModel.slot(for: absolutePath)
            let sub = slot.onChange.subscribe { newVal in
                onChange(newVal)
            }
            return DataSubscription<AnyCodable>(initialValue: slot.value) {
                sub.unsubscribe()
            }

        default:
            // Literals and function calls: evaluate once, no reactive updates.
            let currentValue = resolveDynamicValue(value)
            return DataSubscription<AnyCodable>(initialValue: currentValue, unsubscribe: {})
        }
    }

    // MARK: - nested

    /// Creates a child `DataContext` scoped to a deeper path.
    /// Mirrors WebCore `DataContext.nested(relativePath)`.
    public func nested(_ relativePath: String) -> DataContext {
        let newPath = resolvePath(relativePath)
        return DataContext(surface: surface, path: newPath)
    }

    // MARK: - resolveAction

    /// Resolves an `Action` by evaluating its context values one level deep.
    /// For event actions: resolves each context value to a concrete AnyCodable.
    /// For functionCall actions: evaluates the function call.
    /// Mirrors WebCore `DataContext.resolveAction(action)`.
    public func resolveAction(_ action: Action) -> AnyCodable {
        switch action {
        case .event(let name, let ctx):
            var resolvedContext: [String: AnyCodable] = [:]
            if let ctx = ctx {
                for (key, dv) in ctx {
                    resolvedContext[key] = resolveDynamicValue(dv) ?? .null
                }
            }
            let eventDict: [String: AnyCodable] = [
                "name": .string(name),
                "context": .dictionary(resolvedContext),
            ]
            return .dictionary(["event": .dictionary(eventDict)])

        case .functionCall(let fc):
            let result = resolveDynamicValue(.functionCall(fc))
            return result ?? .null
        }
    }

    // MARK: - Error dispatching

    private func dispatchExpressionError(_ error: Error, functionName: String) {
        // Route through the typed A2uiError path first so callers can read `.code`.
        if let exprError = error as? A2uiExpressionError {
            surface.dispatchError(
                code: exprError.code,
                message: exprError.message,
                details: exprError.details
            )
        } else if let a2uiError = error as? any A2uiError {
            // Any other A2UI error surfaced during expression evaluation.
            surface.dispatchError(
                code: a2uiError.code,
                message: a2uiError.message
            )
        } else {
            surface.dispatchError(
                code: "EXPRESSION_ERROR",
                message: error.localizedDescription
            )
        }
    }
}
