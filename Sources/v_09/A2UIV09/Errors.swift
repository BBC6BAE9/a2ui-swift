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

// MARK: - A2uiError (protocol — mirrors WebCore base class)

/// Base protocol for all A2UI-specific errors.
///
/// Provides unified access to `code` (machine-readable error category) and `message`.
/// Mirrors WebCore's `A2uiError` base class.
///
/// # Swift vs WebCore
/// WebCore uses a class hierarchy (`A2uiError` → subclasses). Swift error handling idioms
/// favour value types (struct) for concrete errors, so we mirror the intent with a protocol:
/// - `code` and `message` are accessible on any A2UI error via `any A2uiError`
/// - Callers can `catch let e as any A2uiError` for unified handling
/// - Callers can `catch let e as A2uiExpressionError` for precise handling
/// - `errorDescription` (for `LocalizedError`) is provided once in the protocol extension
public protocol A2uiError: Error, LocalizedError {
    /// A machine-readable string identifying the error category (e.g. "EXPRESSION_ERROR").
    var code: String { get }
    /// A human-readable description of the error.
    var message: String { get }
}

// Default `LocalizedError` implementation shared by all conforming types.
extension A2uiError {
    public var errorDescription: String? { message }
}

// MARK: - A2uiValidationError

/// Thrown when JSON validation fails or schemas are mismatched.
/// Mirrors WebCore `A2uiValidationError` (code: "VALIDATION_ERROR").
public struct A2uiValidationError: A2uiError {
    public var code: String { "VALIDATION_ERROR" }
    public let message: String
    /// Optional structured details about what failed (e.g. schema violations).
    public let details: [String: AnyCodable]?

    public init(_ message: String, details: [String: AnyCodable]? = nil) {
        self.message = message
        self.details = details
    }
}

// MARK: - A2uiDataError

/// Thrown during DataModel mutations (invalid paths, type mismatches).
/// Mirrors WebCore `A2uiDataError` (code: "DATA_ERROR").
public struct A2uiDataError: A2uiError {
    public var code: String { "DATA_ERROR" }
    public let message: String
    /// The JSON Pointer path at which the error occurred, if known.
    public let path: String?

    public init(_ message: String, path: String? = nil) {
        self.message = message
        self.path = path
    }
}

// MARK: - A2uiExpressionError

/// Thrown during string interpolation and function evaluation.
/// Mirrors WebCore `A2uiExpressionError` (code: "EXPRESSION_ERROR").
public struct A2uiExpressionError: A2uiError {
    public var code: String { "EXPRESSION_ERROR" }
    public let message: String
    /// The name of the function or expression that failed, if known.
    public let expression: String?
    /// Optional structured details (e.g. argument validation failures).
    public let details: [String: AnyCodable]?

    public init(_ message: String, expression: String? = nil, details: [String: AnyCodable]? = nil) {
        self.message = message
        self.expression = expression
        self.details = details
    }
}

// MARK: - A2uiStateError

/// Thrown for structural issues in the UI tree (missing surfaces, duplicate components).
/// Mirrors WebCore `A2uiStateError` (code: "STATE_ERROR").
public struct A2uiStateError: A2uiError {
    public var code: String { "STATE_ERROR" }
    public let message: String

    public init(_ message: String) {
        self.message = message
    }
}
