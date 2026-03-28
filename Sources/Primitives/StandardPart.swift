// Copyright 2025 GenUI Authors.

import Foundation

// MARK: - Default Converter Registry

/// Converter registry for standard parts.
///
/// The key of a map entry is the part type string.
/// The value is a converter closure that knows how to convert that part type.
///
/// To add support for additional part types, merge this with your custom map.
public let defaultPartConverterRegistry: [String: JsonToPartConverter] = [
    TextPart.type: { json in try TextPart.fromJson(json) },
    DataPart.type: { json in try DataPart.fromJson(json) },
    LinkPart.type: { json in try LinkPart.fromJson(json) },
    ToolPart.type: { json in try ToolPart.fromJson(json) },
    ThinkingPart.type: { json in try ThinkingPart.fromJson(json) },
]

// MARK: - JSON keys

private enum JsonKey {
    static let content = "content"
    static let mimeType = "mimeType"
    static let name = "name"
    static let bytes = "bytes"
    static let url = "url"
    static let id = "id"
    static let arguments = "arguments"
    static let result = "result"
}

// MARK: - StandardPart

/// Base type for parts that became de-facto standard for AI messages.
///
/// This is an enum (sealed) to prevent extensions. Use `Part` protocol
/// for custom part types.
public enum StandardPart: Part, Hashable, Sendable {
    case text(String)
    case data(DataPartContent)
    case link(LinkPartContent)
    case tool(ToolPartContent)
    case thinking(String)

    public func toJson() -> [String: Any?] {
        switch self {
        case .text(let text):
            return TextPart.toJson(text)
        case .data(let content):
            return DataPart.toJson(content)
        case .link(let content):
            return LinkPart.toJson(content)
        case .tool(let content):
            return ToolPart.toJson(content)
        case .thinking(let text):
            return ThinkingPart.toJson(text)
        }
    }

    /// Deserializes a StandardPart from a JSON dictionary.
    public static func fromJson(_ json: [String: Any?]) throws -> StandardPart {
        guard let type = json[partTypeKey] as? String else {
            throw PartError.missingTypeKey
        }
        switch type {
        case TextPart.type:
            return try TextPart.fromJson(json)
        case DataPart.type:
            return try DataPart.fromJson(json)
        case LinkPart.type:
            return try LinkPart.fromJson(json)
        case ToolPart.type:
            return try ToolPart.fromJson(json)
        case ThinkingPart.type:
            return try ThinkingPart.fromJson(json)
        default:
            throw PartError.unknownType(type)
        }
    }
}

// MARK: - CustomStringConvertible

extension StandardPart: CustomStringConvertible {
    public var description: String {
        switch self {
        case .text(let text):
            return "TextPart(\(text))"
        case .data(let content):
            return "DataPart(mimeType: \(content.mimeType), name: \(content.name as Any), bytes: \(content.bytes.count))"
        case .link(let content):
            return "LinkPart(url: \(content.url), mimeType: \(content.mimeType as Any), name: \(content.name as Any))"
        case .tool(let content):
            if content.kind == .call {
                return "ToolPart.call(callId: \(content.callId), toolName: \(content.toolName), arguments: \(content.arguments as Any))"
            } else {
                return "ToolPart.result(callId: \(content.callId), toolName: \(content.toolName), result: \(content.result as Any))"
            }
        case .thinking(let text):
            return "ThinkingPart(text: \(text))"
        }
    }
}

// MARK: - TextPart

/// Namespace for TextPart factory methods and constants.
public enum TextPart {
    public static let type = "Text"

    /// Creates a text StandardPart.
    public static func create(_ text: String) -> StandardPart {
        .text(text)
    }

    static func toJson(_ text: String) -> [String: Any?] {
        [partTypeKey: type, JsonKey.content: text]
    }

    static func fromJson(_ json: [String: Any?]) throws -> StandardPart {
        guard let content = json[JsonKey.content] as? String else {
            throw PartError.invalidFormat("TextPart requires string 'content'")
        }
        return .text(content)
    }
}

// MARK: - DataPartContent

/// Content for a data part containing binary data (e.g., images).
public struct DataPartContent: Hashable, Sendable {
    /// The binary data.
    public let bytes: Data

    /// The MIME type of the data.
    public let mimeType: String

    /// Optional name for the data.
    public let name: String?

    public init(bytes: Data, mimeType: String, name: String? = nil) {
        self.bytes = bytes
        self.mimeType = mimeType
        self.name = name ?? DataPart.nameFromMimeType(mimeType)
    }
}

/// Namespace for DataPart factory methods and utilities.
public enum DataPart {
    public static let type = "Data"

    /// The default MIME type for unknown data.
    public static let defaultMimeType = "application/octet-stream"

    /// Creates a data StandardPart.
    public static func create(_ bytes: Data, mimeType: String, name: String? = nil) -> StandardPart {
        .data(DataPartContent(bytes: bytes, mimeType: mimeType, name: name))
    }

    /// Creates a data part from a file URL.
    public static func fromFile(url: URL) throws -> StandardPart {
        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        let ext = url.pathExtension
        let mime: String
        if !ext.isEmpty {
            mime = mimeTypeForFile(fileName, headerBytes: data.prefix(16))
        } else {
            mime = mimeTypeForFile(fileName, headerBytes: data.prefix(16))
        }
        return .data(DataPartContent(bytes: data, mimeType: mime, name: fileName.isEmpty ? nil : fileName))
    }

    // MARK: - MIME utilities

    /// Built-in extension → MIME mapping.
    private static let extensionToMime: [String: String] = [
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "gif": "image/gif",
        "webp": "image/webp",
        "svg": "image/svg+xml",
        "bmp": "image/bmp",
        "ico": "image/x-icon",
        "tiff": "image/tiff",
        "tif": "image/tiff",
        "pdf": "application/pdf",
        "json": "application/json",
        "xml": "application/xml",
        "zip": "application/zip",
        "gz": "application/gzip",
        "tar": "application/x-tar",
        "txt": "text/plain",
        "html": "text/html",
        "htm": "text/html",
        "css": "text/css",
        "js": "application/javascript",
        "csv": "text/csv",
        "md": "text/markdown",
        "rtf": "application/rtf",
        "mp3": "audio/mpeg",
        "wav": "audio/wav",
        "ogg": "audio/ogg",
        "mp4": "video/mp4",
        "avi": "video/x-msvideo",
        "mov": "video/quicktime",
        "webm": "video/webm",
        "doc": "application/msword",
        "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "xls": "application/vnd.ms-excel",
        "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "ppt": "application/vnd.ms-powerpoint",
        "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ]

    /// Reverse mapping from MIME to extension.
    private static let mimeToExtension: [String: String] = {
        var result: [String: String] = [:]
        // Build reverse map, preferring shorter extensions
        for (ext, mime) in extensionToMime {
            if let existing = result[mime] {
                if ext.count < existing.count {
                    result[mime] = ext
                }
            } else {
                result[mime] = ext
            }
        }
        return result
    }()

    /// Gets the MIME type for a file path based on extension and optional header bytes.
    public static func mimeTypeForFile(_ path: String, headerBytes: Data? = nil) -> String {
        // Try header bytes first (magic number detection)
        if let header = headerBytes, header.count >= 4 {
            if header.count >= 8 {
                let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
                if header.prefix(8).elementsEqual(pngSignature) {
                    return "image/png"
                }
            }
            let pdfSignature: [UInt8] = [0x25, 0x50, 0x44, 0x46]
            if header.prefix(4).elementsEqual(pdfSignature) {
                return "application/pdf"
            }
            // JPEG
            if header.prefix(2).elementsEqual([0xFF, 0xD8]) {
                return "image/jpeg"
            }
            // GIF
            if header.prefix(3).elementsEqual([0x47, 0x49, 0x46]) {
                return "image/gif"
            }
        }

        // Try extension
        let ext: String
        if let dotIndex = path.lastIndex(of: ".") {
            ext = String(path[path.index(after: dotIndex)...]).lowercased()
        } else {
            ext = ""
        }

        if !ext.isEmpty, let mime = extensionToMime[ext] {
            return mime
        }

        return defaultMimeType
    }

    /// Gets a default name for a given MIME type.
    public static func nameFromMimeType(_ mimeType: String) -> String {
        let ext = extensionFromMimeType(mimeType) ?? "bin"
        return mimeType.hasPrefix("image/") ? "image.\(ext)" : "file.\(ext)"
    }

    /// Gets the file extension for a given MIME type.
    ///
    /// Returns `nil` if the MIME type is unknown.
    public static func extensionFromMimeType(_ mimeType: String) -> String? {
        return mimeToExtension[mimeType]
    }

    // MARK: - JSON serialization

    static func toJson(_ content: DataPartContent) -> [String: Any?] {
        let base64 = content.bytes.base64EncodedString()
        var contentDict: [String: Any?] = [
            JsonKey.mimeType: content.mimeType,
            JsonKey.bytes: "data:\(content.mimeType);base64,\(base64)",
        ]
        if let name = content.name {
            contentDict[JsonKey.name] = name
        }
        return [partTypeKey: type, JsonKey.content: contentDict]
    }

    static func fromJson(_ json: [String: Any?]) throws -> StandardPart {
        guard let content = json[JsonKey.content] as? [String: Any?] else {
            throw PartError.invalidFormat("DataPart requires 'content' dictionary")
        }
        guard let mimeType = content[JsonKey.mimeType] as? String else {
            throw PartError.invalidFormat("DataPart requires 'mimeType'")
        }
        guard let dataUri = content[JsonKey.bytes] as? String else {
            throw PartError.invalidFormat("DataPart requires 'bytes'")
        }

        // Parse data URI: data:mime;base64,XXXXX
        let bytes: Data
        if let commaIndex = dataUri.firstIndex(of: ",") {
            let base64String = String(dataUri[dataUri.index(after: commaIndex)...])
            guard let decoded = Data(base64Encoded: base64String) else {
                throw PartError.invalidFormat("Invalid base64 in DataPart")
            }
            bytes = decoded
        } else {
            throw PartError.invalidFormat("Invalid data URI in DataPart")
        }

        let name = content[JsonKey.name] as? String
        return .data(DataPartContent(bytes: bytes, mimeType: mimeType, name: name))
    }
}

// MARK: - LinkPartContent

/// Content for a link part referencing external content.
public struct LinkPartContent: Hashable, Sendable {
    /// The URL of the external content.
    public let url: URL

    /// Optional MIME type of the linked content.
    public let mimeType: String?

    /// Optional name for the link.
    public let name: String?

    public init(url: URL, mimeType: String? = nil, name: String? = nil) {
        self.url = url
        self.mimeType = mimeType
        self.name = name
    }
}

/// Namespace for LinkPart factory methods.
public enum LinkPart {
    public static let type = "Link"

    /// Creates a link StandardPart.
    public static func create(_ url: URL, mimeType: String? = nil, name: String? = nil) -> StandardPart {
        .link(LinkPartContent(url: url, mimeType: mimeType, name: name))
    }

    static func toJson(_ content: LinkPartContent) -> [String: Any?] {
        var contentDict: [String: Any?] = [
            JsonKey.url: content.url.absoluteString,
        ]
        if let name = content.name {
            contentDict[JsonKey.name] = name
        }
        if let mimeType = content.mimeType {
            contentDict[JsonKey.mimeType] = mimeType
        }
        return [partTypeKey: type, JsonKey.content: contentDict]
    }

    static func fromJson(_ json: [String: Any?]) throws -> StandardPart {
        guard let content = json[JsonKey.content] as? [String: Any?] else {
            throw PartError.invalidFormat("LinkPart requires 'content' dictionary")
        }
        guard let urlString = content[JsonKey.url] as? String,
              let url = URL(string: urlString) else {
            throw PartError.invalidFormat("LinkPart requires valid 'url'")
        }
        let mimeType = content[JsonKey.mimeType] as? String
        let name = content[JsonKey.name] as? String
        return .link(LinkPartContent(url: url, mimeType: mimeType, name: name))
    }
}

// MARK: - ToolPartKind

/// The kind of tool interaction.
public enum ToolPartKind: String, Hashable, Sendable {
    /// A request to call a tool.
    case call
    /// The result of a tool execution.
    case result
}

// MARK: - ToolPartContent

/// Content for a tool interaction part.
public struct ToolPartContent: Hashable, Sendable {
    /// The kind of tool interaction.
    public let kind: ToolPartKind

    /// The unique identifier for this tool interaction.
    public let callId: String

    /// The name of the tool.
    public let toolName: String

    /// The arguments for a tool call (nil for results).
    public let arguments: [String: JSONValue]?

    /// The result of a tool execution (nil for calls).
    public let result: JSONValue?

    /// Opaque thought signature returned by Gemini thinking models.
    ///
    /// Must be preserved and sent back in conversation history for
    /// function call parts; required by Gemini 3 models.
    public let thoughtSignature: String?

    /// The arguments as a JSON string.
    public var argumentsRaw: String {
        guard let arguments = arguments else { return "" }
        // Build JSON string manually for deterministic output
        guard let data = try? JSONSerialization.data(
            withJSONObject: jsonValueDictToAny(arguments),
            options: [.sortedKeys]
        ), let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    /// Creates a tool call content.
    public static func call(
        callId: String,
        toolName: String,
        arguments: [String: JSONValue],
        thoughtSignature: String? = nil
    ) -> ToolPartContent {
        ToolPartContent(
            kind: .call, callId: callId, toolName: toolName,
            arguments: arguments, result: nil,
            thoughtSignature: thoughtSignature
        )
    }

    /// Creates a tool result content.
    public static func result(
        callId: String,
        toolName: String,
        result: JSONValue?,
        thoughtSignature: String? = nil
    ) -> ToolPartContent {
        ToolPartContent(
            kind: .result, callId: callId, toolName: toolName,
            arguments: nil, result: result,
            thoughtSignature: thoughtSignature
        )
    }
}

/// Helper to convert `[String: JSONValue]` to `[String: Any]`
private func jsonValueDictToAny(_ dict: [String: JSONValue]) -> [String: Any] {
    var result: [String: Any] = [:]
    for (k, v) in dict {
        if let val = v.anyValue {
            result[k] = val
        }
    }
    return result
}

/// Namespace for ToolPart factory methods.
public enum ToolPart {
    public static let type = "Tool"

    /// Creates a tool call StandardPart.
    public static func call(
        callId: String,
        toolName: String,
        arguments: [String: JSONValue],
        thoughtSignature: String? = nil
    ) -> StandardPart {
        .tool(.call(
            callId: callId, toolName: toolName,
            arguments: arguments, thoughtSignature: thoughtSignature
        ))
    }

    /// Creates a tool result StandardPart.
    public static func result(
        callId: String,
        toolName: String,
        result: JSONValue?,
        thoughtSignature: String? = nil
    ) -> StandardPart {
        .tool(.result(
            callId: callId, toolName: toolName,
            result: result, thoughtSignature: thoughtSignature
        ))
    }

    static func toJson(_ content: ToolPartContent) -> [String: Any?] {
        var contentDict: [String: Any?] = [
            JsonKey.id: content.callId,
            JsonKey.name: content.toolName,
        ]
        if let arguments = content.arguments {
            contentDict[JsonKey.arguments] = jsonValueDictToAny(arguments)
        }
        if let result = content.result {
            contentDict[JsonKey.result] = result.anyValue
        }
        return [partTypeKey: type, JsonKey.content: contentDict]
    }

    static func fromJson(_ json: [String: Any?]) throws -> StandardPart {
        guard let content = json[JsonKey.content] as? [String: Any?] else {
            throw PartError.invalidFormat("ToolPart requires 'content' dictionary")
        }
        guard let callId = content[JsonKey.id] as? String else {
            throw PartError.invalidFormat("ToolPart requires 'id'")
        }
        guard let toolName = content[JsonKey.name] as? String else {
            throw PartError.invalidFormat("ToolPart requires 'name'")
        }

        if content.keys.contains(JsonKey.arguments) {
            // It's a call
            let rawArgs = content[JsonKey.arguments] as? [String: Any?] ?? [:]
            var args: [String: JSONValue] = [:]
            for (k, v) in rawArgs {
                if let jv = JSONValue(v) {
                    args[k] = jv
                }
            }
            return .tool(.call(callId: callId, toolName: toolName, arguments: args))
        } else {
            // It's a result
            let rawResult = content[JsonKey.result]
            let resultValue: JSONValue?
            if let r = rawResult {
                resultValue = JSONValue(r)
            } else {
                resultValue = nil
            }
            return .tool(.result(callId: callId, toolName: toolName, result: resultValue))
        }
    }
}

// MARK: - ThinkingPart

/// Namespace for ThinkingPart factory methods.
public enum ThinkingPart {
    public static let type = "Thinking"

    /// Creates a thinking StandardPart.
    public static func create(_ text: String) -> StandardPart {
        .thinking(text)
    }

    static func toJson(_ text: String) -> [String: Any?] {
        [partTypeKey: type, JsonKey.content: text]
    }

    static func fromJson(_ json: [String: Any?]) throws -> StandardPart {
        guard let content = json[JsonKey.content] as? String else {
            throw PartError.invalidFormat("ThinkingPart requires string 'content'")
        }
        return .thinking(content)
    }
}
