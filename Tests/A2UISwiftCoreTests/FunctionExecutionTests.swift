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

// Mirrors WebCore test/function_execution.spec.ts
//
// WebCore's function_execution tests verify two reactive behaviors of
// DataContext.subscribeDynamicValue when the function invoker returns a
// Preact Signal (a reactive stream):
//
//   1. "resolves and subscribes to metronome function" —
//      The invoker returns a `signal<string>` that is updated by `setInterval`.
//      The test subscribes and asserts that values "tick 0", "tick 1", "tick 2"
//      are received in sequence over time. Relies on:
//        - `@preact/signals-core` signal/computed primitives
//        - `AbortSignal` for cancellation
//        - `setInterval` / Promise-based async timing
//
//   2. "updates function output when arguments change" —
//      The invoker returns a plain string, but the arguments contain a data
//      binding ({ path: "/msg" }). The test verifies that when the bound path
//      changes, subscribeDynamicValue re-invokes the function and emits the new
//      value. Relies on Preact Signals computed values automatically tracking
//      argument dependencies and re-evaluating the function.
//
// Neither test is applicable to Swift for the following reasons:
//
// 1. No Preact Signals in Swift:
//    Swift DataContext uses PathSlot + @Observable instead of signal/computed.
//    There is no concept of "a function returning a reactive signal stream".
//    A function invoker (`FunctionInvoker`) is a synchronous throwing closure
//    that returns `AnyCodable?`, not a signal.
//
// 2. No async stream / AbortSignal pattern:
//    Swift uses Swift Concurrency (async/await, AsyncSequence) for async
//    streams, not a callback-based AbortSignal mechanism. Implementing a
//    "metronome" function would require a different API contract that does not
//    exist in the current Swift DataContext.
//
// 3. Re-evaluation on argument change:
//    In Swift, subscribeDynamicValue for a function call resolves arguments
//    synchronously at call time and subscribes to each argument's PathSlot.
//    When a bound argument changes, the callback fires with the new resolved
//    value. This behavior is already covered by DataContextTests.swift
//    ("subscribes relative path" and "subscribes to function calls with no args").
//
// This file exists solely to maintain file-level parity with WebCore.

@testable import A2UISwiftCore