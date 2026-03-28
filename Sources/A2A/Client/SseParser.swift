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
#if canImport(os)
import os
#endif

// MARK: - SseParser

/// Parses a stream of Server-Sent Events (SSE) lines into JSON objects.
///
/// This class handles multi-line `data:` fields, SSE comment lines (`:` prefix),
/// and JSON-RPC result/error extraction.
///
/// Mirrors Flutter `SseParser` in `genui_a2a/client/sse_parser.dart`.
///
/// ## SSE Format
///
/// ```
/// data: {"jsonrpc":"2.0","result":{...}}
///
/// data: {"jsonrpc":"2.0","result":{...}}
///
/// ```
///
/// - `data:` lines accumulate until an empty line signals an event boundary.
/// - `:` lines are comments (used for keepalives) and are ignored.
/// - The `result` field from the JSON-RPC envelope is extracted and yielded.
/// - If an `error` field is found, an ``A2ATransportError/jsonRpc(code:message:)`` is thrown.
public struct SseParser: Sendable {

    #if canImport(os)
    private let logger = Logger(subsystem: "A2UIV09_A2A", category: "SseParser")
    #endif

    public init() {}

    /// Parses a sequence of SSE lines into an `AsyncThrowingStream` of JSON objects.
    ///
    /// - Parameter lines: An `AsyncSequence` of individual SSE lines (already split by newline).
    /// - Returns: An `AsyncThrowingStream` emitting one `[String: Any]` per SSE event.
    public func parse<S: AsyncSequence & Sendable>(
        _ lines: S
    ) -> AsyncThrowingStream<[String: Any], Error> where S.Element == String {
        AsyncThrowingStream { continuation in
            let task = Task {
                var dataBuffer: [String] = []

                do {
                    for try await line in lines {
                        if line.hasPrefix("data:") {
                            let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            dataBuffer.append(payload)
                        } else if line.hasPrefix(":") {
                            // SSE comment — used for keepalive, ignore.
                            #if canImport(os)
                            logger.trace("Ignoring SSE comment: \(line)")
                            #endif
                        } else if line.isEmpty {
                            // Event boundary.
                            if !dataBuffer.isEmpty {
                                if let result = try parseDataBuffer(dataBuffer) {
                                    continuation.yield(result)
                                }
                                dataBuffer = []
                            }
                        } else {
                            #if canImport(os)
                            logger.warning("Ignoring unexpected SSE line: \(line)")
                            #endif
                        }
                    }

                    // Flush remaining buffer at end of stream.
                    if !dataBuffer.isEmpty {
                        if let result = try parseDataBuffer(dataBuffer) {
                            continuation.yield(result)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private

    /// Joins accumulated `data:` lines and parses the JSON content.
    ///
    /// If the JSON-RPC envelope has a `result` key, its value is returned.
    /// If it has an `error` key, an ``A2ATransportError`` is thrown.
    ///
    /// - Parameter dataBuffer: Accumulated data strings from `data:` lines.
    /// - Returns: The extracted result dictionary, or `nil` if the result is null.
    private func parseDataBuffer(_ dataBuffer: [String]) throws -> [String: Any]? {
        let dataString = dataBuffer.joined(separator: "\n")
        guard !dataString.isEmpty,
              let jsonData = dataString.data(using: .utf8) else {
            return nil
        }

        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: jsonData)
        } catch {
            throw A2ATransportError.parsing(message: error.localizedDescription)
        }

        guard let jsonDict = parsed as? [String: Any] else {
            throw A2ATransportError.parsing(message: "SSE data is not a JSON object.")
        }

        // Extract JSON-RPC result/error envelope.
        if let result = jsonDict["result"] {
            if let resultDict = result as? [String: Any] {
                return resultDict
            } else {
                // null result
                #if canImport(os)
                logger.warning("Received a null result in the SSE stream.")
                #endif
                return nil
            }
        } else if let error = jsonDict["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let message = error["message"] as? String ?? "Unknown JSON-RPC error"
            throw A2ATransportError.jsonRpc(code: code, message: message)
        }

        return nil
    }
}
