// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/// Resolves the Gemini API key using a priority chain, mirroring
/// Flutter's `io_get_api_key.dart`:
///
/// 1. Environment variable `GEMINI_API_KEY`
/// 2. User-entered key stored in UserDefaults (`@AppStorage`)
enum GetApiKey {
    private static let environmentKey = "GEMINI_API_KEY"
    private static let userDefaultsKey = "geminiAPIKey"

    /// Returns the API key if available, or an empty string if not configured.
    ///
    /// Checks the process environment first (set via Xcode scheme or CLI),
    /// then the locally persisted key the user entered in Settings.
    /// No hardcoded fallback — the user must provide their own key.
    static func resolve() -> String {
        if let envKey = ProcessInfo.processInfo.environment[environmentKey],
           !envKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return envKey
        }

        let stored = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        if !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stored.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return ""
    }

    /// Whether the user has configured a key (env var or UserDefaults).
    static var hasUserProvidedKey: Bool {
        !resolve().isEmpty
    }
}
