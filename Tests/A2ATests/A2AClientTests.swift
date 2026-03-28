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
import Foundation
@testable import A2A
// MARK: - A2AClient Tests
// Mirrors Dart `test/a2a/client/a2a_client_test.dart`

@Suite("A2AClient")
struct A2AClientTests {

    @Test("getAgentCard returns an AgentCard on success")
    func getAgentCardSuccess() async throws {
        let agentCardDict: [String: Any] = [
            "protocolVersion": "0.1.0",
            "name": "Test Agent",
            "description": "A test agent.",
            "url": "https://example.com/a2a",
            "version": "1.0.0",
            "capabilities": [
                "streaming": false,
                "pushNotifications": false,
                "stateTransitionHistory": false,
            ] as [String: Any],
            "defaultInputModes": [String](),
            "defaultOutputModes": [String](),
            "skills": [[String: Any]](),
        ]
        let transport = FakeTransport(response: agentCardDict)
        let client = A2AClient(url: "http://localhost:8080", transport: transport)
        let result = try await client.getAgentCard()
        #expect(result.name == "Test Agent")
    }

    @Test("messageSend returns a Task on success")
    func messageSendSuccess() async throws {
        let taskDict: [String: Any] = [
            "kind": "task", "id": "123", "contextId": "456",
            "status": ["state": "submitted"] as [String: Any],
        ]
        let transport = FakeTransport(response: ["result": taskDict])
        let client = A2AClient(url: "http://localhost:8080", transport: transport)
        let message = A2AMessage(role: .user, parts: [.text(text: "Hello")], messageId: "1")
        let result = try await client.messageSend(message)
        #expect(result.id == "123")
    }

    @Test("messageStream returns a stream of Events on success")
    func messageStreamSuccess() async throws {
        let transport = FakeTransport()
        let client = A2AClient(url: "http://localhost:8080", transport: transport)
        let message = A2AMessage(role: .user, parts: [.text(text: "Hello")], messageId: "1")
        let stream = client.messageStream(message)

        let eventDict: [String: Any] = [
            "kind": "task-status-update", "taskId": "123", "contextId": "456",
            "status": ["state": "working"] as [String: Any], "final": false,
        ]

        let received = try await drainStream(stream) {
            transport.addEvent(eventDict)
            transport.finishStream()
        }

        #expect(received.count == 1)
        if case .taskStatusUpdate(let taskId, _, _, _) = received[0] {
            #expect(taskId == "123")
        } else {
            Issue.record("Expected taskStatusUpdate, got \(received[0])")
        }
        #expect(transport.streamRequests.count == 1)
        #expect(transport.streamRequests[0]["id"] != nil)
    }

    @Test("request IDs are incremented for each request")
    func requestIdIncrement() async throws {
        let taskDict: [String: Any] = [
            "kind": "task", "id": "123", "contextId": "456",
            "status": ["state": "submitted"] as [String: Any],
        ]
        let transport = FakeTransport(response: ["result": taskDict])
        let client = A2AClient(url: "http://localhost:8080", transport: transport)
        let message = A2AMessage(role: .user, parts: [.text(text: "Hello")], messageId: "1")
        _ = try await client.messageSend(message)
        _ = try await client.getTask("123")
        _ = try await client.cancelTask("123")
        #expect(transport.requests.count == 3)
        #expect(transport.requests[0]["id"] as? Int == 0)
        #expect(transport.requests[1]["id"] as? Int == 1)
        #expect(transport.requests[2]["id"] as? Int == 2)
    }

    @Test("messageStream handles 'task' kind events by converting to statusUpdate")
    func messageStreamTaskKindConversion() async throws {
        let transport = FakeTransport()
        let client = A2AClient(url: "http://localhost:8080", transport: transport)
        let taskDict: [String: Any] = [
            "kind": "task", "id": "123", "contextId": "456",
            "status": ["state": "working"] as [String: Any],
        ]
        let message = A2AMessage(role: .user, parts: [.text(text: "Hello")], messageId: "1")
        let stream = client.messageStream(message)

        let received = try await drainStream(stream) {
            transport.addEvent(taskDict)
            transport.finishStream()
        }

        #expect(received.count == 1)
        if case .statusUpdate(let taskId, let contextId, let status, _) = received[0] {
            #expect(taskId == "123")
            #expect(contextId == "456")
            #expect(status.state == .working)
        } else {
            Issue.record("Expected statusUpdate, got \(received[0])")
        }
    }

    @Test("messageStream includes extensions in params if present in message")
    func messageStreamExtensionsInParams() async throws {
        let transport = FakeTransport()
        let client = A2AClient(url: "http://localhost:8080", transport: transport)
        let message = A2AMessage(
            role: .user, parts: [.text(text: "Hello")],
            extensions: ["ext1", "ext2"], messageId: "1"
        )
        let stream = client.messageStream(message)
        // Finish the stream so the consumer loop exits.
        transport.finishStream()
        for try await _ in stream {}

        #expect(transport.streamRequests.count == 1)
        let params = transport.streamRequests[0]["params"] as? [String: Any]
        #expect(params?["extensions"] as? [String] == ["ext1", "ext2"])
    }

    @Test("messageStream handles 'status-update' kind events")
    func messageStreamStatusUpdateKind() async throws {
        let transport = FakeTransport()
        let client = A2AClient(url: "http://localhost:8080", transport: transport)
        let statusUpdateDict: [String: Any] = [
            "kind": "status-update", "taskId": "123", "contextId": "456",
            "status": ["state": "working"] as [String: Any], "final": false,
        ]
        let message = A2AMessage(role: .user, parts: [.text(text: "Hello")], messageId: "1")
        let stream = client.messageStream(message)

        let received = try await drainStream(stream) {
            transport.addEvent(statusUpdateDict)
            transport.finishStream()
        }

        #expect(received.count == 1)
        if case .statusUpdate(let taskId, let contextId, let status, _) = received[0] {
            #expect(taskId == "123")
            #expect(contextId == "456")
            #expect(status.state == .working)
        } else {
            Issue.record("Expected statusUpdate, got \(received[0])")
        }
    }
}

// MARK: - drainStream helper

/// Drains `stream` while concurrently calling `feed()` to supply events.
private func drainStream(
    _ stream: AsyncThrowingStream<A2AEvent, Error>,
    feed: () -> Void
) async throws -> [A2AEvent] {
    var events: [A2AEvent] = []
    // Start consuming before feeding, so events are not missed.
    let consumeTask = Task {
        var collected: [A2AEvent] = []
        for try await e in stream { collected.append(e) }
        return collected
    }
    feed()
    events = try await consumeTask.value
    return events
}
