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
import Observation

// Test data matching TypeScript's beforeEach:
// {
//   user: { name: "Alice", settings: { theme: "dark" } },
//   items: ["a", "b", "c"]
// }
private func makeModel() -> DataModel {
    DataModel([
        "user": .dictionary([
            "name": .string("Alice"),
            "settings": .dictionary([
                "theme": .string("dark")
            ])
        ]),
        "items": .array([.string("a"), .string("b"), .string("c")])
    ])
}

// MARK: - Initialization

@Suite("Initialization")
struct DataModelInitTests {
    @Test("initializes with empty data if not provided")
    func emptyInit() {
        let model = DataModel()
        #expect(model.get("/") == .dictionary([:]))
    }
}

// MARK: - Basic Retrieval

@Suite("Basic Retrieval")
struct DataModelGetTests {
    @Test("retrieves root data")
    func getRoot() {
        let model = makeModel()
        let root = model.get("/")
        let expected: AnyCodable = .dictionary([
            "user": .dictionary([
                "name": .string("Alice"),
                "settings": .dictionary(["theme": .string("dark")])
            ]),
            "items": .array([.string("a"), .string("b"), .string("c")])
        ])
        #expect(root == expected)
    }

    @Test("retrieves nested path")
    func getNestedPath() {
        let model = makeModel()
        #expect(model.get("/user/name") == .string("Alice"))
        #expect(model.get("/user/settings/theme") == .string("dark"))
    }

    @Test("retrieves array items")
    func getArrayItems() {
        let model = makeModel()
        #expect(model.get("/items/0") == .string("a"))
        #expect(model.get("/items/1") == .string("b"))
    }

    @Test("returns undefined for non-existent paths")
    func getNonExistent() {
        let model = makeModel()
        #expect(model.get("/user/age") == nil)
        #expect(model.get("/unknown/path") == nil)
    }

    @Test("returns undefined when traversing through undefined/null segments")
    func getThroughNull() throws {
        let model = makeModel()
        try model.set("/nullable", value: .null)
        #expect(model.get("/nullable/deep/path") == nil)
    }
}

// MARK: - Updates

@Suite("Updates")
struct DataModelSetTests {
    @Test("sets value at existing path")
    func setExisting() throws {
        let model = makeModel()
        try model.set("/user/name", value: .string("Bob"))
        #expect(model.get("/user/name") == .string("Bob"))
    }

    @Test("sets value at new path")
    func setNew() throws {
        let model = makeModel()
        try model.set("/user/age", value: .number(30))
        #expect(model.get("/user/age") == .number(30))
    }

    @Test("creates intermediate objects")
    func createIntermediateObjects() throws {
        let model = makeModel()
        try model.set("/a/b/c", value: .string("foo"))
        #expect(model.get("/a/b/c") == .string("foo"))
        #expect(model.get("/a/b") != nil)
    }

    @Test("removes keys when value is undefined")
    func removeKey() throws {
        let model = makeModel()
        try model.set("/user/name", value: nil)
        #expect(model.get("/user/name") == nil)
        let user = model.get("/user")?.dictionaryValue
        #expect(user?.keys.contains("name") == false)
    }

    // NOTE: WebCore 同时测试了订阅者在 root 替换时触发一次（callCount == 1），
    // 以及 get("") 等价 get("/")。Swift 将订阅行为独立放在 Subscriptions suite，
    // 这里只验证数据写入正确，保持 Updates suite 职责单一。
    @Test("replaces root object on root update")
    func replaceRoot() throws {
        let model = makeModel()
        try model.set("/", value: .dictionary(["newRoot": .string("foo")]))
        #expect(model.get("") == .dictionary(["newRoot": .string("foo")]))
    }
}

// MARK: - Array / List Handling

@Suite("Array / List Handling")
struct DataModelArrayTests {
    @Test("List: set and get")
    func listSetAndGet() throws {
        let model = makeModel()
        try model.set("/list/0", value: .string("hello"))
        #expect(model.get("/list/0") == .string("hello"))
        #expect(model.get("/list")?.arrayValue != nil)
    }

    @Test("List: append and get")
    func listAppendAndGet() throws {
        let model = makeModel()
        try model.set("/list/0", value: .string("hello"))
        try model.set("/list/1", value: .string("world"))
        #expect(model.get("/list/0") == .string("hello"))
        #expect(model.get("/list/1") == .string("world"))
        #expect(model.get("/list")?.arrayValue?.count == 2)
    }

    @Test("List: update existing index")
    func listUpdateIndex() throws {
        let model = makeModel()
        try model.set("/items/1", value: .string("updated"))
        #expect(model.get("/items/1") == .string("updated"))
    }

    @Test("Nested structures are created automatically")
    func nestedAutoCreate() throws {
        let model = makeModel()

        // Should create { a: { b: [ { c: 123 } ] } }
        try model.set("/a/b/0/c", value: .number(123))
        #expect(model.get("/a/b/0/c") == .number(123))
        #expect(model.get("/a/b")?.arrayValue != nil)
        #expect(model.get("/a/b/0")?.dictionaryValue != nil)

        // Should create nested maps
        try model.set("/x/y/z", value: .string("hello"))
        #expect(model.get("/x/y/z") == .string("hello"))

        // Should create nested lists
        try model.set("/nestedList/0/0", value: .string("inner"))
        #expect(model.get("/nestedList/0/0") == .string("inner"))
        #expect(model.get("/nestedList")?.arrayValue != nil)
        #expect(model.get("/nestedList/0")?.arrayValue != nil)
    }
}

// MARK: - Subscriptions

@Suite("Subscriptions")
struct DataModelSubscriptionTests {

    @Test("returns a subscription object")
    func subscriptionObject() throws {
        let model = makeModel()
        try model.set("/a", value: .number(1))
        var updatedValue: AnyCodable?
        let sub = model.slot(for: "/a")
        sub.onChange.subscribe { updatedValue = $0 }
        #expect(sub.value == .number(1))

        try model.set("/a", value: .number(2))
        #expect(sub.value == .number(2))
        #expect(updatedValue == .number(2))

        sub.onChange.dispose()
        try model.set("/a", value: .number(3))
        #expect(updatedValue == .number(2))
    }

    @Test("notifies subscribers on exact match")
    func notifiesOnExactMatch() throws {
        let model = makeModel()
        var called = false
        model.slot(for: "/user/name").onChange.subscribe { val in
            #expect(val == .string("Charlie"))
            called = true
        }
        try model.set("/user/name", value: .string("Charlie"))
        #expect(called == true)
    }

    @Test("notifies ancestor subscribers (Container Semantics)")
    func notifiesAncestorSubscribers() throws {
        let model = makeModel()
        var called = false
        model.slot(for: "/user").onChange.subscribe { val in
            #expect(val?.dictionaryValue?["name"] == .string("Dave"))
            called = true
        }
        try model.set("/user/name", value: .string("Dave"))
        #expect(called == true)
    }

    @Test("notifies descendant subscribers")
    func notifiesDescendantSubscribers() throws {
        let model = makeModel()
        var called = false
        model.slot(for: "/user/settings/theme").onChange.subscribe { val in
            #expect(val == .string("light"))
            called = true
        }
        try model.set("/user/settings", value: .dictionary(["theme": .string("light")]))
        #expect(called == true)
    }

    @Test("notifies root subscriber")
    func notifiesRootSubscriber() throws {
        let model = makeModel()
        var called = false
        model.slot(for: "/").onChange.subscribe { val in
            #expect(val?.dictionaryValue?["newProp"] == .string("test"))
            called = true
        }
        try model.set("/newProp", value: .string("test"))
        #expect(called == true)
    }

    @Test("notifies parent when child updates")
    func notifiesParentOnChild() throws {
        let model = makeModel()
        try model.set("/parent", value: .dictionary(["child": .string("initial")]))
        var parentValue: AnyCodable?
        model.slot(for: "/parent").onChange.subscribe { parentValue = $0 }
        try model.set("/parent/child", value: .string("updated"))
        #expect(parentValue?.dictionaryValue?["child"] == .string("updated"))
    }

    @Test("stops notifying after dispose")
    func stopsNotifyingAfterDispose() throws {
        let model = makeModel()
        var count = 0
        model.slot(for: "/").onChange.subscribe { _ in count += 1 }
        model.dispose()
        try model.set("/foo", value: .string("bar"))
        #expect(count == 0)
    }

    @Test("supports multiple subscribers to the same path")
    func multipleSubscribers() throws {
        let model = makeModel()
        var callCount1 = 0
        var callCount2 = 0
        let slot = model.slot(for: "/user/name")
        slot.onChange.subscribe { _ in callCount1 += 1 }
        slot.onChange.subscribe { _ in callCount2 += 1 }
        try model.set("/user/name", value: .string("Eve"))
        #expect(callCount1 == 1)
        #expect(callCount2 == 1)
        #expect(slot.value == .string("Eve"))
    }

    @Test("allows unsubscribing individual listeners")
    func unsubscribeIndividual() throws {
        let model = makeModel()
        var callCount1 = 0
        var callCount2 = 0
        let slot = model.slot(for: "/user/name")
        let sub1 = slot.onChange.subscribe { _ in callCount1 += 1 }
        slot.onChange.subscribe { _ in callCount2 += 1 }
        sub1.unsubscribe()
        try model.set("/user/name", value: .string("Frank"))
        #expect(callCount1 == 0)
        #expect(callCount2 == 1)
        #expect(slot.value == .string("Frank"))
    }

    @Test("handles subscription to non-existent path")
    func subscribeNonExistentPath() throws {
        let model = makeModel()
        var val: AnyCodable?
        let slot = model.slot(for: "/non/existent")
        #expect(slot.value == nil)
        slot.onChange.subscribe { val = $0 }
        try model.set("/non/existent", value: .string("exists now"))
        #expect(slot.value == .string("exists now"))
        #expect(val == .string("exists now"))
    }

    @Test("handles updates to undefined")
    func updatesToUndefined() throws {
        let model = makeModel()
        try model.set("/foo", value: .string("bar"))
        var received: AnyCodable?
        let slot = model.slot(for: "/foo")
        slot.onChange.subscribe { received = $0 }
        try model.set("/foo", value: nil)
        #expect(slot.value == nil)
        #expect(received == .some(.null) || received == nil)
    }

    @Test("throws when trying to set nested property through a primitive")
    func setThroughPrimitive() throws {
        let model = makeModel()
        try model.set("/user/name", value: .string("not an object"))
        #expect(model.get("/user/name") == .string("not an object"))

        #expect(throws: A2uiDataError.self) {
            try model.set("/user/name/first", value: .string("Alice"))
        }
    }

    @Test("throws when using non-numeric segment on an array")
    func nonNumericOnArray() {
        let model = makeModel()
        #expect(throws: A2uiDataError.self) {
            try model.set("/items/foo", value: .string("bar"))
        }
    }

    @Test("throws when using non-numeric segment on an array (intermediate)")
    func nonNumericOnArrayIntermediate() throws {
        let model = DataModel()
        try model.set("/", value: .dictionary([
            "items": .array([.number(1), .number(2), .number(3)])
        ]))
        #expect(throws: A2uiDataError.self) {
            try model.set("/items/foo/bar", value: .string("value"))
        }
    }

    @Test("normalizes trailing slashes")
    func trailingSlash() throws {
        let model = makeModel()
        var callCount = 0
        model.slot(for: "/foo").onChange.subscribe { _ in callCount += 1 }
        try model.set("/foo/", value: .string("bar"))
        #expect(model.get("/foo/") == .string("bar"))
        #expect(callCount == 1)
    }

    @Test("replaces root object on root update")
    func replaceRootNotifiesSubscriber() throws {
        let model = makeModel()
        var callCount = 0
        model.slot(for: "/").onChange.subscribe { _ in callCount += 1 }
        try model.set("/", value: .dictionary(["newRoot": .string("foo")]))
        #expect(model.get("") == .dictionary(["newRoot": .string("foo")]))
        #expect(callCount == 1)
    }

    // NOTE: WebCore 测试 "throws when path is null or undefined" 以及
    // "calculates descendants against root path" 在 Swift 中不适用：
    // Swift 类型系统在编译期禁止传 nil 给 String 参数，不存在需要运行时抛错的场景；
    // isDescendant 是内部实现细节，测试私有方法在 Swift 中需破坏封装，不适用。
}

// MARK: - PathSlot Observation (Swift 专属)

/// Swift 专属：PathSlot 是对 WebCore DataModel.subscribe() 返回的订阅对象的 Swift 封装，
/// 额外支持 @Observable 宏，使 SwiftUI View 可以直接读取 slot.value 并在数据变更时
/// 自动重新渲染，无需手动管理回调。这些测试验证 PathSlot 的 @Observable 行为符合预期。
@Suite("PathSlot Observation")
struct DataModelSlotObservationTests {

    /// 验证 slot 是懒创建且被缓存的——对同一路径多次调用 slot(for:) 返回同一实例。
    /// SwiftUI View 可能在 body 中多次读取同一路径的 slot，若每次创建新实例则会
    /// 丢失已订阅的 onChange 监听，导致视图失去响应性。
    @Test("slot is lazily created and cached")
    func slotIdentity() {
        let model = makeModel()
        let slot1 = model.slot(for: "/user/name")
        let slot2 = model.slot(for: "/user/name")
        #expect(slot1 === slot2)
    }

    /// 验证 @Observable 的细粒度精度：只有被访问路径的 slot 变化才会触发 onChange，
    /// 与该路径无关的 slot 不应触发，确保 SwiftUI View 不会因不相关数据变化而重渲染。
    @Test("observation only triggers for the accessed slot")
    func observationGranularity() throws {
        let model = makeModel()
        let nameSlot = model.slot(for: "/user/name")
        let ageSlot = model.slot(for: "/user/age")

        let nameFlag = ObservationFlag()
        withObservationTracking {
            _ = nameSlot.value
        } onChange: { [nameFlag] in
            nameFlag.triggered = true
        }

        let ageFlag = ObservationFlag()
        withObservationTracking {
            _ = ageSlot.value
        } onChange: { [ageFlag] in
            ageFlag.triggered = true
        }

        try model.set("/user/name", value: .string("Frank"))

        #expect(nameFlag.triggered == true)
        #expect(ageFlag.triggered == false)
    }
}

private final class ObservationFlag: @unchecked Sendable {
    var triggered = false
}
