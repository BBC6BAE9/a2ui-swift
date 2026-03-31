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

// Tests for DataContext+SwiftUI.swift
// Verifies the Binding<T> factory methods and the typed UIKit subscribe helpers.

import Testing
import Foundation
@testable import A2UISwiftCore
@testable import A2UISwiftUI

// MARK: - Helpers

private func makeSurface(data: [String: AnyCodable] = [:]) -> SurfaceModel {
    let surface = SurfaceModel(id: "test", catalog: Catalog(id: "test"))
    if !data.isEmpty {
        try! surface.dataModel.set("/", value: .dictionary(data))
    }
    return surface
}

// MARK: - stringBinding

@Suite("DataContext.stringBinding")
@MainActor
struct StringBindingTests {

    @Test("get returns resolved data binding value")
    func getDataBinding() {
        let surface = makeSurface(data: ["name": .string("Alice")])
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.stringBinding(for: .dataBinding(path: "name"))
        #expect(binding.wrappedValue == "Alice")
    }

    @Test("get returns literal value directly")
    func getLiteral() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.stringBinding(for: .literal("hello"))
        #expect(binding.wrappedValue == "hello")
    }

    @Test("get returns empty string when binding path has no value")
    func getMissingPath() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.stringBinding(for: .dataBinding(path: "missing"))
        #expect(binding.wrappedValue == "")
    }

    @Test("get returns empty string when value is nil")
    func getNilValue() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.stringBinding(for: nil)
        #expect(binding.wrappedValue == "")
    }

    @Test("get returns literal as fallback when value is nil literal")
    func getNilWithLiteralFallback() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        // nil value → empty string fallback
        let binding = dc.stringBinding(for: nil)
        #expect(binding.wrappedValue == "")
    }

    @Test("set writes back to DataModel for data binding")
    func setDataBinding() throws {
        let surface = makeSurface(data: ["name": .string("Alice")])
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.stringBinding(for: .dataBinding(path: "name"))
        binding.wrappedValue = "Bob"
        #expect(surface.dataModel.get("/name") == .string("Bob"))
    }

    @Test("set is no-op for literal")
    func setLiteralNoOp() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.stringBinding(for: .literal("static"))
        binding.wrappedValue = "changed"
        // DataModel untouched — literal has no path to write back to
        #expect(surface.dataModel.get("/") == .dictionary([:]))
    }

    @Test("set is no-op for nil value")
    func setNilNoOp() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.stringBinding(for: nil)
        binding.wrappedValue = "changed"
        #expect(surface.dataModel.get("/") == .dictionary([:]))
    }

    @Test("set respects relative path within nested DataContext")
    func setRelativePath() throws {
        let surface = makeSurface(data: ["user": .dictionary(["name": .string("Alice")])])
        let dc = DataContext(surface: surface, path: "/user")
        let binding = dc.stringBinding(for: .dataBinding(path: "name"))
        binding.wrappedValue = "Charlie"
        #expect(surface.dataModel.get("/user/name") == .string("Charlie"))
    }
}

// MARK: - boolBinding

@Suite("DataContext.boolBinding")
@MainActor
struct BoolBindingTests {

    @Test("get returns resolved data binding value")
    func getDataBinding() {
        let surface = makeSurface(data: ["active": .bool(true)])
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.boolBinding(for: .dataBinding(path: "active"))
        #expect(binding.wrappedValue == true)
    }

    @Test("get returns literal value directly")
    func getLiteral() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.boolBinding(for: .literal(true))
        #expect(binding.wrappedValue == true)
    }

    @Test("get returns false when binding path has no value")
    func getMissingPath() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.boolBinding(for: .dataBinding(path: "missing"))
        #expect(binding.wrappedValue == false)
    }

    @Test("set writes back to DataModel for data binding")
    func setDataBinding() {
        let surface = makeSurface(data: ["active": .bool(false)])
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.boolBinding(for: .dataBinding(path: "active"))
        binding.wrappedValue = true
        #expect(surface.dataModel.get("/active") == .bool(true))
    }

    @Test("set is no-op for literal")
    func setLiteralNoOp() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.boolBinding(for: .literal(false))
        binding.wrappedValue = true
        #expect(surface.dataModel.get("/") == .dictionary([:]))
    }
}

// MARK: - doubleBinding

@Suite("DataContext.doubleBinding")
@MainActor
struct DoubleBindingTests {

    @Test("get returns resolved data binding value")
    func getDataBinding() {
        let surface = makeSurface(data: ["score": .number(0.75)])
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.doubleBinding(for: .dataBinding(path: "score"))
        #expect(binding.wrappedValue == 0.75)
    }

    @Test("get returns literal value directly as fallback")
    func getLiteral() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.doubleBinding(for: .literal(3.14))
        #expect(binding.wrappedValue == 3.14)
    }

    @Test("get returns fallback=0 when path has no value and no literal")
    func getMissingPathDefaultFallback() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.doubleBinding(for: .dataBinding(path: "missing"))
        #expect(binding.wrappedValue == 0.0)
    }

    @Test("get returns custom fallback when path has no value")
    func getMissingPathCustomFallback() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.doubleBinding(for: .dataBinding(path: "missing"), fallback: 10.0)
        #expect(binding.wrappedValue == 10.0)
    }

    @Test("set writes back to DataModel for data binding")
    func setDataBinding() {
        let surface = makeSurface(data: ["score": .number(0.0)])
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.doubleBinding(for: .dataBinding(path: "score"))
        binding.wrappedValue = 0.5
        #expect(surface.dataModel.get("/score") == .number(0.5))
    }

    @Test("set is no-op for literal")
    func setLiteralNoOp() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.doubleBinding(for: .literal(1.0))
        binding.wrappedValue = 99.9
        #expect(surface.dataModel.get("/") == .dictionary([:]))
    }
}

// MARK: - dateBinding

@Suite("DataContext.dateBinding")
@MainActor
struct DateBindingTests {

    private let knownISO = "2024-01-15T12:00:00Z"
    private var knownDate: Date {
        ISO8601DateFormatter().date(from: knownISO)!
    }

    @Test("get parses ISO8601 string from data binding")
    func getDataBinding() {
        let surface = makeSurface(data: ["ts": .string(knownISO)])
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.dateBinding(for: .dataBinding(path: "ts"))
        // Compare with tolerance to avoid sub-second drift
        #expect(abs(binding.wrappedValue.timeIntervalSince(knownDate)) < 1)
    }

    @Test("get falls back to Date() for unparseable string")
    func getUnparseable() {
        let surface = makeSurface(data: ["ts": .string("not-a-date")])
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.dateBinding(for: .dataBinding(path: "ts"))
        let now = Date()
        // Should be approximately current time (within 5 seconds)
        #expect(abs(binding.wrappedValue.timeIntervalSince(now)) < 5)
    }

    @Test("set writes ISO8601 string back to DataModel for data binding")
    func setDataBinding() {
        let surface = makeSurface(data: ["ts": .string(knownISO)])
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.dateBinding(for: .dataBinding(path: "ts"))
        let newDate = knownDate.addingTimeInterval(3600) // +1 hour
        binding.wrappedValue = newDate
        let stored = surface.dataModel.get("/ts")?.stringValue
        #expect(stored != nil)
        if let stored {
            let parsed = ISO8601DateFormatter().date(from: stored)
            #expect(parsed != nil)
            #expect(abs(parsed!.timeIntervalSince(newDate)) < 1)
        }
    }

    @Test("set is no-op for literal")
    func setLiteralNoOp() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let binding = dc.dateBinding(for: .literal(knownISO))
        binding.wrappedValue = Date()
        #expect(surface.dataModel.get("/") == .dictionary([:]))
    }
}

// MARK: - Typed UIKit subscribe helpers

@Suite("DataContext typed subscribe helpers (UIKit)")
struct TypedSubscribeTests {

    @Test("subscribeString receives initial value and updates")
    func subscribeStringUpdates() throws {
        let surface = makeSurface(data: ["name": .string("Alice")])
        let dc = DataContext(surface: surface, path: "/")
        var received: [String] = []
        let sub = dc.subscribeString(for: .dataBinding(path: "name")) { received.append($0) }
        #expect(sub.value == "Alice")
        try surface.dataModel.set("/name", value: .string("Bob"))
        #expect(received == ["Bob"])
        sub.unsubscribe()
        try surface.dataModel.set("/name", value: .string("Charlie"))
        #expect(received == ["Bob"]) // no more updates after unsubscribe
    }

    @Test("subscribeString returns empty string for missing path")
    func subscribeStringMissing() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let sub = dc.subscribeString(for: .dataBinding(path: "missing")) { _ in }
        #expect(sub.value == "")
        sub.unsubscribe()
    }

    @Test("subscribeString is static for literal")
    func subscribeStringLiteral() throws {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        var callCount = 0
        let sub = dc.subscribeString(for: .literal("hello")) { _ in callCount += 1 }
        #expect(sub.value == "hello")
        try surface.dataModel.set("/anything", value: .string("changed"))
        #expect(callCount == 0) // literal: no reactive updates
        sub.unsubscribe()
    }

    @Test("subscribeBool receives initial value and updates")
    func subscribeBoolUpdates() throws {
        let surface = makeSurface(data: ["active": .bool(false)])
        let dc = DataContext(surface: surface, path: "/")
        var received: [Bool] = []
        let sub = dc.subscribeBool(for: .dataBinding(path: "active")) { received.append($0) }
        #expect(sub.value == false)
        try surface.dataModel.set("/active", value: .bool(true))
        #expect(received == [true])
        sub.unsubscribe()
    }

    @Test("subscribeDouble receives initial value and updates")
    func subscribeDoubleUpdates() throws {
        let surface = makeSurface(data: ["score": .number(1.5)])
        let dc = DataContext(surface: surface, path: "/")
        var received: [Double?] = []
        let sub = dc.subscribeDouble(for: .dataBinding(path: "score")) { received.append($0) }
        #expect(sub.value == 1.5)
        try surface.dataModel.set("/score", value: .number(9.9))
        #expect(received == [9.9])
        sub.unsubscribe()
    }

    @Test("subscribeDouble returns nil for missing path")
    func subscribeDoubleMissing() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        let sub = dc.subscribeDouble(for: .dataBinding(path: "missing")) { _ in }
        #expect(sub.value == nil)
        sub.unsubscribe()
    }
}
