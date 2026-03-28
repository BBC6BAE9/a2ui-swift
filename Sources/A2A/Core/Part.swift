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

// MARK: - Part

/// Represents a distinct piece of content within an ``A2AMessage`` or ``Artifact``.
///
/// A ``Part`` can be text, a file reference, or structured data. The `kind` field
/// acts as a discriminator to determine the specific type of the content part.
///
/// Mirrors Dart `Part` (freezed union) in `a2a/core/part.dart`.
public enum Part: Codable, Sendable, Equatable {

    /// A plain text content part.
    case text(text: String, metadata: JSONObject? = nil)

    /// A file content part.
    case file(file: FileContent, metadata: JSONObject? = nil)

    /// A structured JSON data content part.
    case data(data: JSONObject, metadata: JSONObject? = nil)

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case kind
        case text
        case file
        case data
        case metadata
    }

    // MARK: - Decodable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)

        switch kind {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            let metadata = try container.decodeIfPresent(JSONObject.self, forKey: .metadata)
            self = .text(text: text, metadata: metadata)

        case "file":
            let file = try container.decode(FileContent.self, forKey: .file)
            let metadata = try container.decodeIfPresent(JSONObject.self, forKey: .metadata)
            self = .file(file: file, metadata: metadata)

        case "data":
            let data = try container.decode(JSONObject.self, forKey: .data)
            let metadata = try container.decodeIfPresent(JSONObject.self, forKey: .metadata)
            self = .data(data: data, metadata: metadata)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown Part kind: \(kind)"
            )
        }
    }

    // MARK: - Encodable

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text, let metadata):
            try container.encode("text", forKey: .kind)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(metadata, forKey: .metadata)

        case .file(let file, let metadata):
            try container.encode("file", forKey: .kind)
            try container.encode(file, forKey: .file)
            try container.encodeIfPresent(metadata, forKey: .metadata)

        case .data(let data, let metadata):
            try container.encode("data", forKey: .kind)
            try container.encode(data, forKey: .data)
            try container.encodeIfPresent(metadata, forKey: .metadata)
        }
    }
}

// MARK: - FileContent

/// Represents file data, used within a ``Part/file`` part.
///
/// The file content can be provided either as a URI pointing to the file or
/// directly as base64-encoded bytes.
///
/// Named `FileContent` to avoid conflict with Dart `FileType` and Swift `FileType`.
///
/// Mirrors Dart `FileType` (freezed union) in `a2a/core/part.dart`.
public enum FileContent: Codable, Sendable, Equatable {

    /// A file located at a specific URI.
    case uri(uri: String, name: String? = nil, mimeType: String? = nil)

    /// A file with its content embedded as a base64-encoded string.
    case bytes(bytes: String, name: String? = nil, mimeType: String? = nil)

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case uri
        case bytes
        case name
        case mimeType
    }

    // MARK: - Decodable

    /// Decodes a ``FileContent`` from JSON.
    ///
    /// Follows the same fallback logic as the Dart `FileType.fromJson`:
    /// if `bytes` key is present → `.bytes`; if `uri` key is present → `.uri`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decodeIfPresent(String.self, forKey: .name)
        let mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)

        if let bytes = try container.decodeIfPresent(String.self, forKey: .bytes) {
            self = .bytes(bytes: bytes, name: name, mimeType: mimeType)
        } else if let uri = try container.decodeIfPresent(String.self, forKey: .uri) {
            self = .uri(uri: uri, name: name, mimeType: mimeType)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "FileContent must contain either 'uri' or 'bytes'"
                )
            )
        }
    }

    // MARK: - Encodable

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .uri(let uri, let name, let mimeType):
            try container.encode(uri, forKey: .uri)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(mimeType, forKey: .mimeType)

        case .bytes(let bytes, let name, let mimeType):
            try container.encode(bytes, forKey: .bytes)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(mimeType, forKey: .mimeType)
        }
    }
}
