// Copyright 2025 GenUI Authors.

import Foundation

// MARK: - ChatMessageRole

/// The role of a message author.
///
/// The role indicates the source of the message or the intended perspective.
public enum ChatMessageRole: String, Hashable, Sendable {
    /// A message from the system that sets context or instructions for the model.
    case system

    /// A message from the end user to the model ("user prompt").
    case user

    /// A message from the model to the user ("model response").
    case model
}

// MARK: - ChatMessage

/// A chat message.
public struct ChatMessage: Sendable {
    /// The role of the message author.
    public let role: ChatMessageRole

    /// The content parts of the message.
    public let parts: [StandardPart]

    /// Optional metadata associated with this message.
    ///
    /// This can include information like suppressed content, warnings, etc.
    public let metadata: [String: JSONValue]

    /// The finish status of the message.
    ///
    /// When `nil`, finish status is unknown.
    public let finishStatus: FinishStatus?

    /// Creates a new message.
    public init(
        role: ChatMessageRole,
        parts: [StandardPart] = [],
        metadata: [String: JSONValue] = [:],
        finishStatus: FinishStatus? = nil
    ) {
        self.role = role
        self.parts = parts
        self.metadata = metadata
        self.finishStatus = finishStatus
    }

    // MARK: - Named constructors

    private static func partsFromText(_ text: String, parts: [StandardPart]) -> [StandardPart] {
        if text.isEmpty { return parts }
        return [.text(text)] + parts
    }

    /// Creates a system message.
    ///
    /// If `text` is not empty, converts it to a TextPart and puts it as the
    /// first member of the parts list.
    public static func system(
        _ text: String,
        parts: [StandardPart] = [],
        metadata: [String: JSONValue] = [:],
        finishStatus: FinishStatus? = nil
    ) -> ChatMessage {
        ChatMessage(
            role: .system,
            parts: partsFromText(text, parts: parts),
            metadata: metadata,
            finishStatus: finishStatus
        )
    }

    /// Creates a user message.
    ///
    /// If `text` is not empty, converts it to a TextPart and puts it as the
    /// first member of the parts list.
    public static func user(
        _ text: String,
        parts: [StandardPart] = [],
        metadata: [String: JSONValue] = [:],
        finishStatus: FinishStatus? = nil
    ) -> ChatMessage {
        ChatMessage(
            role: .user,
            parts: partsFromText(text, parts: parts),
            metadata: metadata,
            finishStatus: finishStatus
        )
    }

    /// Creates a model message.
    ///
    /// If `text` is not empty, converts it to a TextPart and puts it as the
    /// first member of the parts list.
    public static func model(
        _ text: String,
        parts: [StandardPart] = [],
        metadata: [String: JSONValue] = [:],
        finishStatus: FinishStatus? = nil
    ) -> ChatMessage {
        ChatMessage(
            role: .model,
            parts: partsFromText(text, parts: parts),
            metadata: metadata,
            finishStatus: finishStatus
        )
    }

    // MARK: - Computed properties

    private var _parts: Parts { Parts(parts) }

    /// Concatenated TextPart text.
    public var text: String { _parts.text }

    /// Whether this message contains any tool calls.
    public var hasToolCalls: Bool { !_parts.toolCalls.isEmpty }

    /// Gets all tool calls in this message.
    public var toolCalls: [ToolPartContent] { _parts.toolCalls }

    /// Whether this message contains any tool results.
    public var hasToolResults: Bool { !_parts.toolResults.isEmpty }

    /// Gets all tool results in this message.
    public var toolResults: [ToolPartContent] { _parts.toolResults }

    // MARK: - copyWith

    /// Creates a copy of this message with optional fields replaced.
    public func copyWith(
        role: ChatMessageRole? = nil,
        parts: [StandardPart]? = nil,
        metadata: [String: JSONValue]? = nil,
        finishStatus: FinishStatus? = nil
    ) -> ChatMessage {
        ChatMessage(
            role: role ?? self.role,
            parts: parts ?? self.parts,
            metadata: metadata ?? self.metadata,
            finishStatus: finishStatus ?? self.finishStatus
        )
    }

    // MARK: - concatenate

    /// Concatenates this message with another message.
    ///
    /// - Throws: `ArgumentError` if roles differ, finish statuses conflict,
    ///   or metadata sets differ.
    public func concatenate(_ other: ChatMessage) throws -> ChatMessage {
        guard role == other.role else {
            throw ChatMessageError.roleMismatch
        }

        if finishStatus != nil && other.finishStatus != nil &&
            finishStatus != other.finishStatus {
            throw ChatMessageError.conflictingFinishStatus
        }

        guard metadata == other.metadata else {
            throw ChatMessageError.metadataMismatch(
                lhs: metadata, rhs: other.metadata
            )
        }

        return copyWith(
            parts: parts + other.parts,
            finishStatus: finishStatus ?? other.finishStatus
        )
    }

    // MARK: - JSON Serialization

    private enum JsonKey {
        static let parts = "parts"
        static let role = "role"
        static let metadata = "metadata"
        static let finishStatus = "finishStatus"
    }

    /// Serializes the message to JSON.
    public func toJson() -> [String: Any?] {
        var json: [String: Any?] = [
            JsonKey.parts: Parts(parts).toJson(),
            JsonKey.metadata: metadata.mapValues { $0.anyValue },
            JsonKey.role: role.rawValue,
        ]
        if let finishStatus = finishStatus {
            json[JsonKey.finishStatus] = finishStatus.toJson()
        }
        return json
    }

    /// Deserializes a message from JSON.
    public static func fromJson(_ json: [String: Any?]) throws -> ChatMessage {
        guard let roleStr = json[JsonKey.role] as? String,
              let role = ChatMessageRole(rawValue: roleStr) else {
            throw PartError.invalidFormat("ChatMessage requires valid 'role'")
        }

        let parts: [StandardPart]
        if let partsJson = json[JsonKey.parts] as? [Any?] {
            parts = try partsJson.map { item in
                guard let dict = item as? [String: Any?] else {
                    throw PartError.invalidFormat("Part JSON must be a dictionary")
                }
                return try StandardPart.fromJson(dict)
            }
        } else {
            parts = []
        }

        let metadata: [String: JSONValue]
        if let metaDict = json[JsonKey.metadata] as? [String: Any?] {
            var result: [String: JSONValue] = [:]
            for (k, v) in metaDict {
                if let jv = JSONValue(v) {
                    result[k] = jv
                }
            }
            metadata = result
        } else {
            metadata = [:]
        }

        let finishStatus: FinishStatus?
        if let fsJson = json[JsonKey.finishStatus] as? [String: Any?] {
            finishStatus = try FinishStatus.fromJson(fsJson)
        } else {
            finishStatus = nil
        }

        return ChatMessage(
            role: role,
            parts: parts,
            metadata: metadata,
            finishStatus: finishStatus
        )
    }
}

// MARK: - Equatable

extension ChatMessage: Equatable {
    public static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.role == rhs.role &&
        lhs.parts == rhs.parts &&
        lhs.metadata == rhs.metadata &&
        lhs.finishStatus == rhs.finishStatus
    }
}

// MARK: - Hashable

extension ChatMessage: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(role)
        hasher.combine(parts)
        hasher.combine(metadata)
        hasher.combine(finishStatus)
    }
}

// MARK: - CustomStringConvertible

extension ChatMessage: CustomStringConvertible {
    public var description: String {
        "Message(role: \(role), parts: [\(parts.map(\.description).joined(separator: ", "))], metadata: \(metadata), finishStatus: \(finishStatus as Any))"
    }
}

// MARK: - Errors

public enum ChatMessageError: Error, CustomStringConvertible {
    case roleMismatch
    case conflictingFinishStatus
    case metadataMismatch(lhs: [String: JSONValue], rhs: [String: JSONValue])

    public var description: String {
        switch self {
        case .roleMismatch:
            return "Roles must match for concatenation"
        case .conflictingFinishStatus:
            return "Finish statuses must match for concatenation"
        case .metadataMismatch(let lhs, let rhs):
            return "Metadata sets should be equal, but found \(lhs) and \(rhs)"
        }
    }
}
