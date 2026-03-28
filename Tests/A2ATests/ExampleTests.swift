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
// MARK: - Example end-to-end test
// Mirrors Dart `test/a2a/example_test.dart`

@Suite("Example")
struct ExampleTests {

    @Test("example client and server – countdown then liftoff")
    func countdownLiftoff() async throws {
        let transport = FakeTransport()
        let client = A2AClient(url: "http://localhost/", transport: transport)
        defer { client.close() }

        let message = A2AMessage(
            role: .user,
            parts: [.text(text: "start 10")],
            messageId: UUID().uuidString
        )

        let stream = client.messageStream(message)

        var collectedTexts: [String] = []
        var taskId: String?

        // Feed all events before draining (FakeTransport queues events added
        // before sendStream is called, then flushes them when the stream is consumed).
        transport.addEvent([
            "kind": "task-status-update",
            "taskId": "task-123",
            "contextId": "context-123",
            "status": ["state": "working"] as [String: Any],
            "final": false,
        ])

        for i in stride(from: 10, through: 0, by: -1) {
            transport.addEvent([
                "kind": "artifact-update",
                "taskId": "task-123",
                "contextId": "context-123",
                "artifact": [
                    "artifactId": "artifact-\(i)",
                    "parts": [["kind": "text", "text": "Countdown at \(i)!"] as [String: Any]],
                ] as [String: Any],
                "append": false,
                "lastChunk": i == 0,
            ])
        }

        transport.addEvent([
            "kind": "task-status-update",
            "taskId": "task-123",
            "contextId": "context-123",
            "status": ["state": "completed"] as [String: Any],
            "final": true,
        ])

        transport.addEvent([
            "kind": "artifact-update",
            "taskId": "task-123",
            "contextId": "context-123",
            "artifact": [
                "artifactId": "artifact-liftoff",
                "parts": [["kind": "text", "text": "Liftoff!"] as [String: Any]],
            ] as [String: Any],
            "append": false,
            "lastChunk": true,
        ])

        transport.finishStream()

        // Drain stream.
        for try await event in stream {
            if taskId == nil {
                switch event {
                case .taskStatusUpdate(let id, _, _, _): taskId = id
                case .statusUpdate(let id, _, _, _): taskId = id
                case .artifactUpdate(let id, _, _, _, _): taskId = id
                }
            }
            if case .artifactUpdate(_, _, let artifact, _, _) = event {
                for part in artifact.parts {
                    if case .text(let text, _) = part {
                        collectedTexts.append(text)
                        if text.contains("Countdown at 5") {
                            let pauseMessage = A2AMessage(
                                role: .user,
                                parts: [.text(text: "pause")],
                                messageId: UUID().uuidString,
                                taskId: taskId
                            )
                            _ = try? await client.messageSend(pauseMessage)
                        }
                    }
                }
            }
        }

        let joined = collectedTexts.joined(separator: "\n")
        #expect(joined.contains("Countdown at 5!"))
        #expect(joined.contains("Liftoff!"))
    }
}
