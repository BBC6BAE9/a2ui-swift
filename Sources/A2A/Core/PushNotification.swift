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

// MARK: - PushNotificationConfig

/// Defines the configuration for setting up push notifications for task updates.
///
/// Mirrors Dart `PushNotificationConfig` in `a2a/core/push_notification.dart`.
public struct PushNotificationConfig: Codable, Sendable, Equatable {

    /// A unique identifier (e.g. UUID) for the push notification configuration.
    public let id: String?

    /// The callback URL where the agent should send push notifications.
    public let url: String

    /// A unique token for this task or session to validate incoming push
    /// notifications.
    public let token: String?

    /// Optional authentication details for the agent to use when calling the
    /// notification URL.
    public let authentication: PushNotificationAuthenticationInfo?

    public init(
        id: String? = nil,
        url: String,
        token: String? = nil,
        authentication: PushNotificationAuthenticationInfo? = nil
    ) {
        self.id = id
        self.url = url
        self.token = token
        self.authentication = authentication
    }
}

// MARK: - PushNotificationAuthenticationInfo

/// Defines authentication details for a push notification endpoint.
///
/// Mirrors Dart `PushNotificationAuthenticationInfo` in `a2a/core/push_notification.dart`.
public struct PushNotificationAuthenticationInfo: Codable, Sendable, Equatable {

    /// A list of supported authentication schemes (e.g., "Basic", "Bearer").
    public let schemes: [String]

    /// Optional credentials required by the push notification endpoint.
    public let credentials: String?

    public init(schemes: [String], credentials: String? = nil) {
        self.schemes = schemes
        self.credentials = credentials
    }
}

// MARK: - TaskPushNotificationConfig

/// A container associating a push notification configuration with a specific task.
///
/// Mirrors Dart `TaskPushNotificationConfig` in `a2a/core/push_notification.dart`.
public struct TaskPushNotificationConfig: Codable, Sendable, Equatable {

    /// The unique identifier (e.g. UUID) of the task.
    public let taskId: String

    /// The push notification configuration for this task.
    public let pushNotificationConfig: PushNotificationConfig

    public init(taskId: String, pushNotificationConfig: PushNotificationConfig) {
        self.taskId = taskId
        self.pushNotificationConfig = pushNotificationConfig
    }
}
