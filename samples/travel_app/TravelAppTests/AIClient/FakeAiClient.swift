// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import A2UISwiftCore
import Primitives@testable import TravelApp

/// A fake implementation of `AiClient` for testing.
///
/// Mirrors Flutter's `FakeAiClient` from `fake_ai_client.dart`.
/// Provides controllable streams for A2UI messages and text responses,
/// and tracks `sendRequest` calls for verification in tests.
final class FakeAiClient: AiClient {
    private let a2uiMessageContinuation: AsyncStream<A2uiMessage>.Continuation
    private let textResponseContinuation: AsyncStream<String>.Continuation

    let a2uiMessageStream: AsyncStream<A2uiMessage>
    let textResponseStream: AsyncStream<String>

    var sendRequestCallCount = 0

    /// When non-nil, `sendRequest` will suspend until this continuation is
    /// resumed by the test. Mirrors Flutter's `sendRequestCompleter`.
    var sendRequestContinuation: CheckedContinuation<Void, Never>?

    init() {
        var a2uiCont: AsyncStream<A2uiMessage>.Continuation!
        a2uiMessageStream = AsyncStream { a2uiCont = $0 }
        a2uiMessageContinuation = a2uiCont

        var textCont: AsyncStream<String>.Continuation!
        textResponseStream = AsyncStream { textCont = $0 }
        textResponseContinuation = textCont
    }

    func sendRequest(
        _ message: Primitives.ChatMessage,
        history: [Primitives.ChatMessage]?,
        clientDataModel: [String: Any]?
    ) async throws {
        sendRequestCallCount += 1
        if sendRequestContinuation != nil {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                sendRequestContinuation = cont
            }
        }
    }

    func addA2uiMessage(_ message: A2uiMessage) {
        a2uiMessageContinuation.yield(message)
    }

    func addTextResponse(_ text: String) {
        textResponseContinuation.yield(text)
    }

    func dispose() {
        a2uiMessageContinuation.finish()
        textResponseContinuation.finish()
    }
}
