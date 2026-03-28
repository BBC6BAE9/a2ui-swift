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
@testable import A2A
// MARK: - FakeTransport

/// A fake ``A2ATransport`` for use in tests.
///
/// Thread-safe via NSLock; marked `@unchecked Sendable` because
/// `[String: Any]` is not `Sendable` in Swift 6, but all mutations are
/// protected by the lock.
///
/// Events added via `addEvent(_:)` before `sendStream(_:)` is called are
/// buffered and flushed automatically when the continuation is installed.
/// This matches the Dart FakeTransport behaviour and allows the ExampleTests
/// pattern of pre-queuing all events before consuming the stream.
///
/// Mirrors Dart `FakeTransport` in `test/a2a/fakes.dart`.
final class FakeTransport: A2ATransport, @unchecked Sendable {

    // MARK: - A2ATransport

    let authHeaders: [String: String]

    // MARK: - State (protected by _lock)

    private let _lock = NSLock()
    private var _requests: [[String: Any]] = []
    private var _streamRequests: [[String: Any]] = []
    private var _response: [String: Any]
    private var _continuation: AsyncThrowingStream<[String: Any], Error>.Continuation?
    /// Events buffered before sendStream() is called.
    private var _pendingEvents: [[String: Any]] = []
    /// Whether finishStream() was called before sendStream().
    private var _pendingFinish: Bool = false

    var requests: [[String: Any]] { _lock.withLock { _requests } }
    var streamRequests: [[String: Any]] { _lock.withLock { _streamRequests } }
    var response: [String: Any] {
        get { _lock.withLock { _response } }
        set { _lock.withLock { _response = newValue } }
    }

    // MARK: - Init

    init(
        response: [String: Any] = [:],
        authHeaders: [String: String] = [:]
    ) {
        self._response = response
        self.authHeaders = authHeaders
    }

    // MARK: - A2ATransport conformance

    func get(path: String, headers: [String: String] = [:]) async throws -> [String: Any] {
        try jsonRoundTrip(_lock.withLock { _response })
    }

    func send(
        _ request: [String: Any],
        path: String = "",
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        let resp = _lock.withLock { () -> [String: Any] in
            _requests.append(request)
            return _response
        }
        return try jsonRoundTrip(resp)
    }

    func sendStream(
        _ request: [String: Any],
        headers: [String: String] = [:]
    ) -> AsyncThrowingStream<[String: Any], Error> {
        let (stream, continuation) = AsyncThrowingStream<[String: Any], Error>.makeStream()

        // Flush buffered events, then set the live continuation.
        let (buffered, shouldFinish) = _lock.withLock { () -> ([[String: Any]], Bool) in
            _streamRequests.append(request)
            _continuation = continuation
            let b = _pendingEvents
            let f = _pendingFinish
            _pendingEvents = []
            _pendingFinish = false
            return (b, f)
        }

        for event in buffered {
            nonisolated(unsafe) let e = event
            continuation.yield(e)
        }
        if shouldFinish {
            _lock.withLock { _continuation = nil }
            continuation.finish()
        }

        return stream
    }

    func close() {
        let c = _lock.withLock { () -> AsyncThrowingStream<[String: Any], Error>.Continuation? in
            let c = _continuation; _continuation = nil; return c
        }
        c?.finish()
    }

    // MARK: - Test helpers

    func addEvent(_ event: [String: Any]) {
        let c = _lock.withLock { () -> AsyncThrowingStream<[String: Any], Error>.Continuation? in
            if _continuation == nil {
                // sendStream not yet called — buffer the event.
                _pendingEvents.append(event)
                return nil
            }
            return _continuation
        }
        if let c {
            nonisolated(unsafe) let e = event
            c.yield(e)
        }
    }

    func finishStream() {
        let c = _lock.withLock { () -> AsyncThrowingStream<[String: Any], Error>.Continuation? in
            if _continuation == nil {
                // sendStream not yet called — remember to finish when it is.
                _pendingFinish = true
                return nil
            }
            let c = _continuation; _continuation = nil; return c
        }
        c?.finish()
    }
}

// MARK: - JSON round-trip helper

func jsonRoundTrip(_ value: [String: Any]) throws -> [String: Any] {
    let data = try JSONSerialization.data(withJSONObject: value)
    guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw A2ATransportError.parsing(message: "jsonRoundTrip: result is not a dictionary")
    }
    return dict
}
