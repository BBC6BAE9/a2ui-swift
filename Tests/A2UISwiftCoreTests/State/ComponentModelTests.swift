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

@Suite("ComponentModel")
struct ComponentModelTests {

    // -- 初始化 --

    @Test("initializes properties")
    func initialization() {
        let comp = ComponentModel(id: "c1", type: "Button", properties: [
            "label": .string("Click Me")
        ])
        #expect(comp.id == "c1")
        #expect(comp.type == "Button")
        #expect(comp.properties["label"] == .string("Click Me"))
    }

    // -- 属性更新 --

    @Test("updates properties")
    func updateProperties() {
        let comp = ComponentModel(id: "c1", type: "Button", properties: [
            "label": .string("Old")
        ])
        comp.properties = ["label": .string("Clicked")]
        #expect(comp.properties["label"] == .string("Clicked"))
    }

    // -- onUpdated EventEmitter --

    @Test("notifies listeners on update")
    func onUpdatedOnReplacement() {
        let comp = ComponentModel(id: "c1", type: "Button", properties: [
            "label": .string("Initial")
        ])

        var received: ComponentModel?
        comp.onUpdated.subscribe { received = $0 }

        comp.properties = ["label": .string("New")]

        #expect(received === comp)
        #expect(received?.properties["label"] == .string("New"))
    }

    @Test("unsubscribes listeners")
    func onUpdatedUnsubscribe() {
        let comp = ComponentModel(id: "c1", type: "Button")
        var count = 0
        let sub = comp.onUpdated.subscribe { _ in count += 1 }

        comp.properties["x"] = .number(1)
        #expect(count == 1)

        sub.unsubscribe()
        comp.properties["x"] = .number(2)
        #expect(count == 1)
    }

    // -- componentTree --

    @Test("returns component tree representation")
    func componentTree() {
        let comp = ComponentModel(id: "c1", type: "Button", properties: [
            "label": .string("Click Me")
        ])
        let tree = comp.componentTree
        #expect(tree["id"] == .string("c1"))
        #expect(tree["type"] == .string("Button"))
        #expect(tree["label"] == .string("Click Me"))
    }

    // -- @Observable (Swift 专属) --

    /// Swift 专属：验证 @Observable 宏在属性整体替换时触发 observation，
    /// 使 SwiftUI View 能正确重新渲染。WebCore 通过响应式信号系统（Preact signals）
    /// 实现细粒度更新；Swift 端对应机制是 @Observable，需专门验证。
    @Test("observation triggers on properties replacement")
    func observationOnReplacement() {
        let comp = ComponentModel(id: "c1", type: "Button", properties: [
            "label": .string("Click")
        ])

        let flag = ObservationFlag()
        withObservationTracking {
            _ = comp.properties
        } onChange: { [flag] in
            flag.triggered = true
        }

        comp.properties = ["label": .string("New")]
        #expect(flag.triggered == true)
    }

    /// Swift 专属：验证通过下标（subscript）对单个属性的修改也会触发 @Observable 通知。
    /// SwiftUI View 只订阅了 comp.properties 整体，subscript 写入需同样触发通知，
    /// 否则视图将无法感知细粒度属性变化。
    @Test("observation triggers on single property mutation")
    func observationOnMutation() {
        let comp = ComponentModel(id: "c1", type: "Button", properties: [
            "label": .string("Click")
        ])

        let flag = ObservationFlag()
        withObservationTracking {
            _ = comp.properties
        } onChange: { [flag] in
            flag.triggered = true
        }

        comp.properties["label"] = .string("Mutated")
        #expect(flag.triggered == true)
    }
}

/// Sendable wrapper for observation testing.
private final class ObservationFlag: @unchecked Sendable {
    var triggered = false
}
