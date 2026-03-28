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

import Testing
@testable import v_09

@Suite("Events")
struct EventsTests {

    @Test("subscribe and emit delivers value to listener")
    func subscribeAndEmit() {
        let emitter = EventEmitter<String>()
        var received = ""
        emitter.subscribe { received = $0 }
        emitter.emit("hello")
        #expect(received == "hello")
    }

    @Test("unsubscribe stops listener from receiving events")
    func unsubscribe() {
        let emitter = EventEmitter<String>()
        var callCount = 0
        var lastValue = ""
        let sub = emitter.subscribe { val in
            callCount += 1
            lastValue = val
        }

        emitter.emit("hello")
        #expect(callCount == 1)
        #expect(lastValue == "hello")

        sub.unsubscribe()

        emitter.emit("world")
        #expect(callCount == 1)  // unchanged
        #expect(lastValue == "hello")  // unchanged
    }

    // NOTE: WebCore 测试 "handles errors thrown by listeners" 在 Swift 中不适用。
    // WebCore（TypeScript）的 listener 是无类型约束的，运行时可能抛出任意异常，
    // 因此 EventEmitter.emit 需要 try-catch 捕获并通过 console.error 记录。
    // Swift 的类型系统要求 listener 闭包声明为 (T) -> Void（不可抛出），
    // listener 内部使用 throw 是编译期错误，不存在需要运行时捕获的场景。

    /// Swift 专属：验证 EventEmitter 的多播（multi-cast）语义——所有订阅者均收到同一事件。
    /// WebCore 各层代码隐式依赖此行为（如 onUpdated 可被多个视图订阅），但未单独断言。
    /// Swift 需明确验证，以防止误将实现改为单播（单一 listener 覆盖）。
    @Test("multiple subscribers all receive emitted value")
    func multipleSubscribers() {
        let emitter = EventEmitter<Int>()
        var results: [Int] = []
        emitter.subscribe { results.append($0) }
        emitter.subscribe { results.append($0 * 2) }

        emitter.emit(5)
        #expect(results == [5, 10])
    }

    /// Swift 专属：验证 dispose() 可一次性移除所有 listener，之后不再触发任何回调。
    /// WebCore 通过 GC 隐式管理生命周期，无需 dispose。
    /// Swift 需要主动调用 dispose() 清理订阅以释放内存、防止回调泄漏。
    @Test("dispose removes all listeners")
    func disposeRemovesAll() {
        let emitter = EventEmitter<Int>()
        var count = 0
        emitter.subscribe { _ in count += 1 }
        emitter.subscribe { _ in count += 1 }

        emitter.dispose()
        emitter.emit(1)
        #expect(count == 0)
    }

    /// Swift 专属：验证迭代快照（emit-time snapshot）机制的正确性。
    /// EventEmitter 在 emit 前应先对 listener 列表做快照再迭代，
    /// 从而保证 listener 内部再次调用 emit 不会造成无限递归或崩溃。
    /// WebCore 的实现有相同保证，但未通过测试明确约束；Swift 端需显式验证。
    @Test("emit during iteration does not crash")
    func emitDuringIteration() {
        let emitter = EventEmitter<Int>()
        var count = 0
        emitter.subscribe { _ in
            count += 1
            // Emit again from within listener — snapshot prevents infinite loop
            if count == 1 {
                emitter.emit(2)
            }
        }
        emitter.emit(1)
        #expect(count == 2)
    }

    /// Swift 专属：验证快照机制确保在 emit 执行期间新注册的 listener
    /// 不会接收到当次 emit 的事件。
    /// 快照在 emit 开始时拍摄，新 listener 只出现在下一次 emit 的快照中，
    /// 避免同一事件被意外重复处理。
    @Test("new subscriber added during emit does not receive current emit")
    func subscribeDuringEmit() {
        let emitter = EventEmitter<Int>()
        var lateCount = 0
        emitter.subscribe { _ in
            // Add a new subscriber from within the handler
            emitter.subscribe { _ in lateCount += 1 }
        }
        emitter.emit(1)
        // The late subscriber was added AFTER the snapshot was taken
        #expect(lateCount == 0)
    }
}
