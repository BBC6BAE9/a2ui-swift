// Copyright 2025 GenUI Authors.

import Foundation

/// Categories of finish status of a response from model or agent.
public enum FinishCategory: String, Hashable, Sendable {
    /// The response is not finished.
    case notFinished

    /// The response is finished as completed.
    case completed

    /// The response is finished as result of interruption.
    case interrupted
}

/// The finish status of a model or agent response.
public struct FinishStatus: Equatable, Hashable, Sendable {
    /// The finish category.
    public let category: FinishCategory

    /// Optional details about the finish status.
    public let details: String?

    public init(category: FinishCategory, details: String? = nil) {
        self.category = category
        self.details = details
    }

    /// Creates a "not finished" status.
    public static func notFinished() -> FinishStatus {
        FinishStatus(category: .notFinished)
    }

    /// Creates a "completed" status.
    public static func completed() -> FinishStatus {
        FinishStatus(category: .completed)
    }

    /// Creates an "interrupted" status with optional details.
    public static func interrupted(details: String? = nil) -> FinishStatus {
        FinishStatus(category: .interrupted, details: details)
    }

    // MARK: - JSON Serialization

    private enum JsonKey {
        static let category = "category"
        static let details = "details"
    }

    /// Serializes the finish status to JSON.
    public func toJson() -> [String: Any?] {
        var json: [String: Any?] = [JsonKey.category: category.rawValue]
        if let details = details {
            json[JsonKey.details] = details
        }
        return json
    }

    /// Deserializes a finish status from JSON.
    public static func fromJson(_ json: [String: Any?]) throws -> FinishStatus {
        guard let categoryStr = json[JsonKey.category] as? String,
              let category = FinishCategory(rawValue: categoryStr) else {
            throw PartError.invalidFormat("FinishStatus requires valid 'category'")
        }
        let details = json[JsonKey.details] as? String
        return FinishStatus(category: category, details: details)
    }
}

// MARK: - CustomStringConvertible

extension FinishStatus: CustomStringConvertible {
    public var description: String {
        "FinishStatus(category: \(category), details: \(details as Any))"
    }
}
