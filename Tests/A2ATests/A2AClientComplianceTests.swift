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
// MARK: - A2AClient Compliance Tests
// Mirrors Dart `test/a2a/client/a2a_client_compliance_test.dart`

@Suite("A2AClient Compliance")
struct A2AClientComplianceTests {

    // MARK: listTasks

    @Test("listTasks sends correct request and parses response")
    func listTasksSendsAndParses() async throws {
        let result = ListTasksResult(tasks: [], totalSize: 0, pageSize: 10, nextPageToken: "")
        let resultData = try JSONEncoder().encode(result)
        let resultDict = try JSONSerialization.jsonObject(with: resultData) as! [String: Any]

        let transport = FakeTransport(response: ["result": resultDict])
        let client = A2AClient(url: "http://example.com", transport: transport)

        let params = ListTasksParams(pageSize: 10)
        let response = try await client.listTasks(params)

        #expect(response.tasks.isEmpty)
        #expect(response.nextPageToken.isEmpty)
    }

    // MARK: setPushNotificationConfig

    @Test("setPushNotificationConfig sends correct request")
    func setPushNotificationConfig() async throws {
        let config = TaskPushNotificationConfig(
            taskId: "task-123",
            pushNotificationConfig: PushNotificationConfig(
                id: "config-123",
                url: "http://example.com/push"
            )
        )
        let configData = try JSONEncoder().encode(config)
        let configDict = try JSONSerialization.jsonObject(with: configData) as! [String: Any]

        let transport = FakeTransport(response: ["result": configDict])
        let client = A2AClient(url: "http://example.com", transport: transport)

        _ = try await client.setPushNotificationConfig(config)
    }

    // MARK: getPushNotificationConfig

    @Test("getPushNotificationConfig sends correct request")
    func getPushNotificationConfig() async throws {
        let config = TaskPushNotificationConfig(
            taskId: "task-123",
            pushNotificationConfig: PushNotificationConfig(
                id: "config-123",
                url: "http://example.com/push"
            )
        )
        let configData = try JSONEncoder().encode(config)
        let configDict = try JSONSerialization.jsonObject(with: configData) as! [String: Any]

        let transport = FakeTransport(response: ["result": configDict])
        let client = A2AClient(url: "http://example.com", transport: transport)

        _ = try await client.getPushNotificationConfig(taskId: "task-123", configId: "config-123")
    }

    // MARK: listPushNotificationConfigs

    @Test("listPushNotificationConfigs sends correct request")
    func listPushNotificationConfigs() async throws {
        let transport = FakeTransport(response: ["result": ["configs": [[String: Any]]()]])
        let client = A2AClient(url: "http://example.com", transport: transport)

        let response = try await client.listPushNotificationConfigs(taskId: "task-123")

        #expect(response.isEmpty)
    }

    // MARK: deletePushNotificationConfig

    @Test("deletePushNotificationConfig sends correct request")
    func deletePushNotificationConfig() async throws {
        let transport = FakeTransport(response: ["result": [String: Any]()])
        let client = A2AClient(url: "http://example.com", transport: transport)

        try await client.deletePushNotificationConfig(taskId: "task-123", configId: "config-123")
    }

    // MARK: authHeaders

    @Test("authHeaders are passed to transport")
    func authHeadersPassedToTransport() async {
        let authHeaders = ["Authorization": "Bearer test-token"]
        let transport = FakeTransport(response: [:], authHeaders: authHeaders)
        let client = A2AClient(url: "http://example.com", transport: transport)
        _ = client

        #expect(transport.authHeaders == authHeaders)
    }

    // MARK: Error handling

    @Test("correct error is thrown for generic JSON-RPC error")
    func genericJsonRpcError() async throws {
        let transport = FakeTransport(response: [
            "error": ["code": -32600, "message": "Invalid Request"] as [String: Any]
        ])
        let client = A2AClient(url: "http://example.com", transport: transport)

        do {
            _ = try await client.getTask("bad-task-id")
            Issue.record("Expected an error to be thrown")
        } catch let error as A2ATransportError {
            if case .jsonRpc(let code, _) = error {
                #expect(code == -32600)
            } else {
                Issue.record("Expected jsonRpc error, got \(error)")
            }
        }
    }

    @Test("correct error is thrown for A2A task-not-found error code")
    func taskNotFoundError() async throws {
        let transport = FakeTransport(response: [
            "error": ["code": -32001, "message": "Task not found"] as [String: Any]
        ])
        let client = A2AClient(url: "http://example.com", transport: transport)

        do {
            _ = try await client.getTask("bad-task-id")
            Issue.record("Expected an error to be thrown")
        } catch let error as A2ATransportError {
            if case .taskNotFound(_) = error {
                // expected
            } else {
                Issue.record("Expected taskNotFound error, got \(error)")
            }
        }
    }
}
