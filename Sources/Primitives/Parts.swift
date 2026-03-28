// Copyright 2025 GenUI Authors.

import Foundation

/// A collection of parts.
///
/// Parts is an immutable collection that wraps an array of `StandardPart`.
/// It provides convenient computed properties for accessing text content,
/// tool calls, and tool results.
public struct Parts: Sendable {
    private let _parts: [StandardPart]

    /// Creates a new collection of parts.
    public init(_ parts: [StandardPart]) {
        self._parts = parts
    }

    /// Creates a collection of parts from text and optional other parts.
    ///
    /// If `text` is not empty, converts it to a `TextPart` and puts it as the
    /// first member of the `parts` list.
    public static func fromText(_ text: String, parts: [StandardPart] = []) -> Parts {
        if text.isEmpty {
            return Parts(parts)
        }
        return Parts([.text(text)] + parts)
    }

    /// Deserializes parts from a JSON array.
    public static func fromJson(
        _ json: [Any?],
        converterRegistry: [String: JsonToPartConverter] = defaultPartConverterRegistry
    ) throws -> Parts {
        let parts: [StandardPart] = try json.map { item in
            guard let dict = item as? [String: Any?] else {
                throw PartError.invalidFormat("Part JSON must be a dictionary")
            }
            return try StandardPart.fromJson(dict)
        }
        return Parts(parts)
    }

    /// Serializes parts to a JSON array.
    public func toJson() -> [Any?] {
        _parts.map { $0.toJson() }
    }

    /// The number of parts.
    public var count: Int { _parts.count }

    /// Whether the collection is empty.
    public var isEmpty: Bool { _parts.isEmpty }

    /// Accesses the part at the given index.
    public subscript(index: Int) -> StandardPart { _parts[index] }

    /// The first part, or `nil` if empty.
    public var first: StandardPart? { _parts.first }

    /// The last part, or `nil` if empty.
    public var last: StandardPart? { _parts.last }

    /// All parts as an array.
    public var items: [StandardPart] { _parts }

    /// Extracts and concatenates all text content from TextPart instances.
    ///
    /// Returns a single string with all text content concatenated together
    /// without any separators.
    public var text: String {
        _parts.compactMap { part -> String? in
            if case .text(let t) = part { return t }
            return nil
        }.joined()
    }

    /// Extracts all tool call parts.
    ///
    /// Returns only `ToolPartContent` instances where `kind == .call`.
    public var toolCalls: [ToolPartContent] {
        _parts.compactMap { part -> ToolPartContent? in
            if case .tool(let content) = part, content.kind == .call {
                return content
            }
            return nil
        }
    }

    /// Extracts all tool result parts.
    ///
    /// Returns only `ToolPartContent` instances where `kind == .result`.
    public var toolResults: [ToolPartContent] {
        _parts.compactMap { part -> ToolPartContent? in
            if case .tool(let content) = part, content.kind == .result {
                return content
            }
            return nil
        }
    }
}

// MARK: - Equatable

extension Parts: Equatable {
    public static func == (lhs: Parts, rhs: Parts) -> Bool {
        lhs._parts == rhs._parts
    }
}

// MARK: - Hashable

extension Parts: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_parts)
    }
}

// MARK: - RandomAccessCollection

extension Parts: RandomAccessCollection {
    public var startIndex: Int { _parts.startIndex }
    public var endIndex: Int { _parts.endIndex }

    public func index(after i: Int) -> Int {
        _parts.index(after: i)
    }

    public func index(before i: Int) -> Int {
        _parts.index(before: i)
    }
}

// MARK: - CustomStringConvertible

extension Parts: CustomStringConvertible {
    public var description: String {
        "[\(_parts.map(\.description).joined(separator: ", "))]"
    }
}
