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

    // NOTE: WebCore's "handles errors thrown by listeners" test does not apply in Swift.
    // WebCore (TypeScript) listeners are not constrained by the type system and can throw arbitrary runtime exceptions,
    // so EventEmitter.emit needs try-catch handling and logs through console.error.
    // Swift's type system requires listener closures to be declared as (T) -> Void (non-throwing);
    // throwing inside a listener is a compile-time error, so there is no runtime case to catch.

    /// Swift-specific: verifies EventEmitter's multi-cast semantics: all subscribers receive the same event.
    /// WebCore layers implicitly depend on this behavior, such as onUpdated being subscribable by multiple views, but do not assert it separately.
    /// Swift verifies it explicitly to prevent accidentally changing the implementation to unicast, where one listener overwrites another.
    @Test("multiple subscribers all receive emitted value")
    func multipleSubscribers() {
        let emitter = EventEmitter<Int>()
        var results: [Int] = []
        emitter.subscribe { results.append($0) }
        emitter.subscribe { results.append($0 * 2) }

        emitter.emit(5)
        #expect(results == [5, 10])
    }

    /// Swift-specific: verifies dispose() removes all listeners at once and prevents future callbacks.
    /// WebCore manages lifetimes implicitly through GC and does not need dispose.
    /// Swift needs explicit dispose() calls to clean up subscriptions, release memory, and prevent callback leaks.
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

    /// Swift-specific: verifies the correctness of the emit-time snapshot mechanism.
    /// EventEmitter should snapshot the listener list before iterating during emit,
    /// ensuring that calling emit again from inside a listener does not cause infinite recursion or crashes.
    /// WebCore provides the same guarantee but does not pin it with a test; Swift verifies it explicitly.
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

    /// Swift-specific: verifies the snapshot mechanism prevents listeners added during emit
    /// from receiving the current event.
    /// The snapshot is taken when emit starts, so new listeners only appear in the next emit snapshot,
    /// preventing the same event from being processed unexpectedly more than once.
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
