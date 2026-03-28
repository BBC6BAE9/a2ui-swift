// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

// MARK: - Request / Response types

/// A request to the Gemini `generateContent` endpoint.
///
/// Mirrors Flutter's `google_ai.GenerateContentRequest` from the
/// `google_cloud_ai_generativelanguage_v1beta` package. Since there is no
/// standalone Google Generative AI Swift SDK (the official one was deprecated
/// in May 2025; Google recommends Firebase AI Logic for Swift), we define a
/// lightweight equivalent here.
struct GenerateContentRequest {
    /// The model resource name (e.g., `"models/gemini-3-flash-preview"`).
    let model: String

    /// Conversation contents (user / model turns).
    let contents: [[String: Any]]

    /// System instruction (prompt fragments).
    let systemInstruction: [String: Any]?

    /// Generation configuration (e.g., `maxOutputTokens`).
    let generationConfig: [String: Any]?

    /// Tool declarations (function calling).
    let tools: [[String: Any]]?

    /// Tool configuration (e.g., function calling mode).
    let toolConfig: [String: Any]?
}

/// A response from the Gemini `generateContent` endpoint.
///
/// Mirrors Flutter's `google_ai.GenerateContentResponse`.
struct GenerateContentResponse {
    /// The raw JSON dictionary returned by the API.
    let json: [String: Any]

    /// Convenience: the first candidate's content parts.
    var candidates: [[String: Any]]? {
        json["candidates"] as? [[String: Any]]
    }

    /// Convenience: usage metadata (token counts).
    var usageMetadata: [String: Any]? {
        json["usageMetadata"] as? [String: Any]
    }
}

// MARK: - Interface

/// An interface for a generative service, allowing for mock implementations.
///
/// This protocol abstracts the underlying generative service, allowing for
/// different implementations to be used, for example, in testing.
///
/// Mirrors Flutter's `GoogleGenerativeServiceInterface` from
/// `ai_client/google_generative_service_interface.dart`.
protocol GoogleGenerativeServiceInterface {
    /// Generates content from the given request.
    func generateContent(_ request: GenerateContentRequest) async throws -> GenerateContentResponse

    /// Closes the service and releases any resources.
    func close()
}

// MARK: - URLSession wrapper

/// A wrapper that implements ``GoogleGenerativeServiceInterface`` using
/// `URLSession` to call the Gemini REST API directly.
///
/// Mirrors Flutter's `GoogleGenerativeServiceWrapper` which wraps
/// `google_ai.GenerativeService`.
///
/// Since there is no standalone Google Generative AI Swift SDK, we use
/// `URLSession` to call the REST API.
class GoogleGenerativeServiceWrapper: GoogleGenerativeServiceInterface {
    private let session: URLSession
    private let apiKey: String

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func generateContent(_ request: GenerateContentRequest) async throws -> GenerateContentResponse {
        let url = URL(string:
            "https://generativelanguage.googleapis.com/v1beta/"
            + "\(request.model):generateContent?key=\(apiKey)"
        )!

        var body: [String: Any] = [
            "contents": request.contents,
        ]
        if let systemInstruction = request.systemInstruction {
            body["system_instruction"] = systemInstruction
        }
        if let generationConfig = request.generationConfig {
            body["generationConfig"] = generationConfig
        }
        if let tools = request.tools, !tools.isEmpty {
            body["tools"] = tools
        }
        if let toolConfig = request.toolConfig {
            body["toolConfig"] = toolConfig
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 300
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "unknown error"
            throw GeminiError.apiError(
                statusCode: httpResponse.statusCode,
                message: responseBody
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GeminiError.invalidResponse
        }

        return GenerateContentResponse(json: json)
    }

    func close() {
        // URLSession doesn't strictly require disposal, but the hook is here
        // for implementations that need it (e.g., custom session configurations).
    }
}
