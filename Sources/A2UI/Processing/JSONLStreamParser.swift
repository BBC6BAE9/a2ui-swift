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

/// Parses JSONL (JSON Lines) data where each line is a separate
/// `ServerToClientMessage` JSON object.
///
/// Agents send A2UI messages as a JSONL stream — one JSON object per line.
/// This parser handles both synchronous (string-based) and asynchronous
/// (URL/byte stream) scenarios.
public final class JSONLStreamParser {

    private let decoder = JSONDecoder()

    public init() {}

    // MARK: - Synchronous Parsing

    /// Parse a single JSONL line into a message. Returns `nil` for blank lines
    /// or lines that fail to decode.
    public func parseLine(_ line: String) -> ServerToClientMessage? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8) else { return nil }
        return try? decoder.decode(ServerToClientMessage.self, from: data)
    }

    /// Parse a multi-line JSONL string into an array of messages.
    public func parseLines(_ text: String) -> [ServerToClientMessage] {
        text.components(separatedBy: .newlines).compactMap(parseLine)
    }

    // MARK: - Async Stream (for URLSession / file streams)

    /// Parse an `AsyncSequence` of bytes (e.g. from `URLSession.bytes(for:)`)
    /// and yield messages as they arrive.
    ///
    /// Transport errors (network failures, connection resets, etc.) are propagated
    /// to the caller via the throwing stream, matching how web renderers surface
    /// errors to the application layer for handling (snackbar, fallback, etc.).
    @available(iOS 15.0, macOS 12.0, *)
    public func messages<S: AsyncSequence>(
        from bytes: S
    ) -> AsyncThrowingStream<ServerToClientMessage, Error> where S.Element == UInt8 {
        AsyncThrowingStream { continuation in
            Task {
                var buffer = Data()
                do {
                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            if !buffer.isEmpty,
                               let msg = try? decoder.decode(
                                ServerToClientMessage.self, from: buffer
                               ) {
                                continuation.yield(msg)
                            }
                            buffer.removeAll(keepingCapacity: true)
                        } else {
                            buffer.append(byte)
                        }
                    }
                    // Handle last line without trailing newline
                    if !buffer.isEmpty,
                       let msg = try? decoder.decode(
                        ServerToClientMessage.self, from: buffer
                       ) {
                        continuation.yield(msg)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Parse an `AsyncLineSequence` (e.g. from `URL.lines` or
    /// `URLSession.bytes(for:).lines`).
    ///
    /// Transport errors are propagated to the caller, consistent with how
    /// web renderers handle stream errors at the application layer.
    @available(iOS 15.0, macOS 12.0, *)
    public func messages<S: AsyncSequence>(
        fromLines lines: S
    ) -> AsyncThrowingStream<ServerToClientMessage, Error> where S.Element == String {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in lines {
                        if let msg = parseLine(line) {
                            continuation.yield(msg)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
