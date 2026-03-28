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

/// Parses JSONL (JSON Lines) data where each line is an A2UI v0.8 message.
public final class JSONLStreamParser {

    private let decoder = JSONDecoder()

    public init() {}

    // MARK: - Versioned Parsing

    /// Parse a single JSONL line into a versioned message.
    public func parseVersionedLine(_ line: String) -> VersionedMessage? {
        guard let msg = parseLine(line) else { return nil }
        return .v08(msg)
    }

    /// Parse a multi-line JSONL string into versioned messages.
    public func parseVersionedLines(_ text: String) -> [VersionedMessage] {
        text.components(separatedBy: .newlines).compactMap(parseVersionedLine)
    }

    /// Parse a byte stream into versioned messages.
    @available(iOS 15.0, macOS 12.0, *)
    public func versionedMessages<S: AsyncSequence>(
        from bytes: S
    ) -> AsyncThrowingStream<VersionedMessage, Error> where S.Element == UInt8 {
        AsyncThrowingStream { continuation in
            Task {
                var buffer = Data()
                do {
                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            if !buffer.isEmpty,
                               let msg = try? self.decoder.decode(
                                ServerToClientMessage_V08.self, from: buffer
                               ) {
                                continuation.yield(.v08(msg))
                            }
                            buffer.removeAll(keepingCapacity: true)
                        } else {
                            buffer.append(byte)
                        }
                    }
                    if !buffer.isEmpty,
                       let msg = try? self.decoder.decode(
                        ServerToClientMessage_V08.self, from: buffer
                       ) {
                        continuation.yield(.v08(msg))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Parse a line stream into versioned messages.
    @available(iOS 15.0, macOS 12.0, *)
    public func versionedMessages<S: AsyncSequence>(
        fromLines lines: S
    ) -> AsyncThrowingStream<VersionedMessage, Error> where S.Element == String {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in lines {
                        if let msg = self.parseVersionedLine(line) {
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

    // MARK: - Direct Parsing

    /// Parse a single JSONL line.
    public func parseLine(_ line: String) -> ServerToClientMessage_V08? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8) else { return nil }
        return try? decoder.decode(ServerToClientMessage_V08.self, from: data)
    }

    /// Parse a multi-line JSONL string.
    public func parseLines(_ text: String) -> [ServerToClientMessage_V08] {
        text.components(separatedBy: .newlines).compactMap(parseLine)
    }

    /// Parse byte stream.
    @available(iOS 15.0, macOS 12.0, *)
    public func messages<S: AsyncSequence>(
        from bytes: S
    ) -> AsyncThrowingStream<ServerToClientMessage_V08, Error> where S.Element == UInt8 {
        AsyncThrowingStream { continuation in
            Task {
                var buffer = Data()
                do {
                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            if !buffer.isEmpty,
                               let msg = try? self.decoder.decode(
                                ServerToClientMessage_V08.self, from: buffer
                               ) {
                                continuation.yield(msg)
                            }
                            buffer.removeAll(keepingCapacity: true)
                        } else {
                            buffer.append(byte)
                        }
                    }
                    if !buffer.isEmpty,
                       let msg = try? self.decoder.decode(
                        ServerToClientMessage_V08.self, from: buffer
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

    /// Parse line stream.
    @available(iOS 15.0, macOS 12.0, *)
    public func messages<S: AsyncSequence>(
        fromLines lines: S
    ) -> AsyncThrowingStream<ServerToClientMessage_V08, Error> where S.Element == String {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in lines {
                        if let msg = self.parseLine(line) {
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
