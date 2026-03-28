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
// MARK: - Data Models Tests
// Mirrors Dart `test/a2a/core/data_models_test.dart`

@Suite("Data Models")
struct DataModelsTests {

    // MARK: AgentCard

    @Test("AgentCard can be serialized and deserialized")
    func agentCardRoundTrip() throws {
        let agentCard = AgentCard(
            protocolVersion: "1.0",
            name: "Test Agent",
            description: "An agent for testing",
            url: "https://example.com/agent",
            version: "1.0.0",
            capabilities: AgentCapabilities(),
            defaultInputModes: ["text"],
            defaultOutputModes: ["text"],
            skills: []
        )
        let encoded = try JSONEncoder().encode(agentCard)
        let decoded = try JSONDecoder().decode(AgentCard.self, from: encoded)

        #expect(decoded == agentCard)
        #expect(decoded.name == "Test Agent")
    }

    @Test("AgentCard with optional fields null can be serialized and deserialized")
    func agentCardOptionalFieldsRoundTrip() throws {
        let agentCard = AgentCard(
            protocolVersion: "1.0",
            name: "Test Agent",
            description: "An agent for testing",
            url: "https://example.com/agent",
            version: "1.0.0",
            capabilities: AgentCapabilities(),
            defaultInputModes: [],
            defaultOutputModes: [],
            skills: []
        )
        let encoded = try JSONEncoder().encode(agentCard)
        let decoded = try JSONDecoder().decode(AgentCard.self, from: encoded)

        #expect(decoded == agentCard)
    }

    // MARK: Message

    @Test("Message can be serialized and deserialized")
    func messageRoundTrip() throws {
        let message = A2AMessage(
            role: .user,
            parts: [.text(text: "Hello, agent!")],
            messageId: "12345"
        )
        let encoded = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(A2AMessage.self, from: encoded)

        #expect(decoded == message)
        #expect(decoded.role == .user)
    }

    @Test("Message with empty parts can be serialized and deserialized")
    func messageEmptyPartsRoundTrip() throws {
        let message = A2AMessage(
            role: .user,
            parts: [],
            messageId: "12345"
        )
        let encoded = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(A2AMessage.self, from: encoded)

        #expect(decoded == message)
    }

    @Test("Message with multiple parts can be serialized and deserialized")
    func messageMultiplePartsRoundTrip() throws {
        let message = A2AMessage(
            role: .user,
            parts: [
                .text(text: "Hello"),
                .file(file: .uri(uri: "file:///path/to/file.txt", name: nil, mimeType: "text/plain")),
                .data(data: ["key": AnyCodable("value")])
            ],
            messageId: "12345"
        )
        let encoded = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(A2AMessage.self, from: encoded)

        #expect(decoded == message)
    }

    // MARK: Task

    @Test("Task can be serialized and deserialized")
    func taskRoundTrip() throws {
        let task = A2ATask(
            id: "task-123",
            contextId: "context-456",
            status: TaskStatus(state: .working),
            artifacts: [
                Artifact(
                    artifactId: "artifact-1",
                    parts: [.text(text: "Hello")]
                )
            ]
        )
        let encoded = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(A2ATask.self, from: encoded)

        #expect(decoded == task)
        #expect(decoded.id == "task-123")
    }

    @Test("Task with optional fields null can be serialized and deserialized")
    func taskOptionalFieldsRoundTrip() throws {
        let task = A2ATask(
            id: "task-123",
            contextId: "context-456",
            status: TaskStatus(state: .working)
        )
        let encoded = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(A2ATask.self, from: encoded)

        #expect(decoded == task)
    }

    // MARK: Part

    @Test("Part can be serialized and deserialized")
    func partRoundTrip() throws {
        // text
        let partText = Part.text(text: "Hello")
        let encodedText = try JSONEncoder().encode(partText)
        let decodedText = try JSONDecoder().decode(Part.self, from: encodedText)
        #expect(decodedText == partText)

        // file uri
        let partFileUri = Part.file(
            file: .uri(uri: "file:///path/to/file.txt", name: nil, mimeType: "text/plain")
        )
        let encodedFileUri = try JSONEncoder().encode(partFileUri)
        let decodedFileUri = try JSONDecoder().decode(Part.self, from: encodedFileUri)
        #expect(decodedFileUri == partFileUri)

        // file bytes
        let partFileBytes = Part.file(
            file: .bytes(bytes: "aGVsbG8=", name: "hello.txt", mimeType: nil)
        )
        let encodedFileBytes = try JSONEncoder().encode(partFileBytes)
        let decodedFileBytes = try JSONDecoder().decode(Part.self, from: encodedFileBytes)
        #expect(decodedFileBytes == partFileBytes)

        // data
        let partData = Part.data(data: ["key": AnyCodable("value")])
        let encodedData = try JSONEncoder().encode(partData)
        let decodedData = try JSONDecoder().decode(Part.self, from: encodedData)
        #expect(decodedData == partData)
    }

    // MARK: SecurityScheme

    @Test("SecurityScheme can be serialized and deserialized")
    func securitySchemeRoundTrip() throws {
        let scheme = SecurityScheme.apiKey(
            description: nil,
            name: "test_key",
            in: "header"
        )
        let encoded = try JSONEncoder().encode(scheme)
        let decoded = try JSONDecoder().decode(SecurityScheme.self, from: encoded)

        #expect(decoded == scheme)
    }

    // MARK: PushNotificationConfig

    @Test("PushNotificationConfig can be serialized and deserialized")
    func pushNotificationConfigRoundTrip() throws {
        let config = PushNotificationConfig(
            id: "config-1",
            url: "https://example.com/push",
            authentication: PushNotificationAuthenticationInfo(
                schemes: ["Bearer"],
                credentials: "test-token"
            )
        )
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(PushNotificationConfig.self, from: encoded)

        #expect(decoded == config)
    }

    @Test("TaskPushNotificationConfig can be serialized and deserialized")
    func taskPushNotificationConfigRoundTrip() throws {
        let taskConfig = TaskPushNotificationConfig(
            taskId: "task-123",
            pushNotificationConfig: PushNotificationConfig(
                id: "config-1",
                url: "https://example.com/push"
            )
        )
        let encoded = try JSONEncoder().encode(taskConfig)
        let decoded = try JSONDecoder().decode(TaskPushNotificationConfig.self, from: encoded)

        #expect(decoded == taskConfig)
    }
}
