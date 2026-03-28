// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import XCTest
@testable import TravelApp

/// Tests for `GetApiKey`.
///
/// Mirrors Flutter's `io_get_api_key.dart` logic:
/// env var → UserDefaults → hardcoded fallback.
final class GetApiKeyTests: XCTestCase {

    private let userDefaultsKey = "geminiAPIKey"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        super.tearDown()
    }

    func testResolveReturnsNonEmptyKey() {
        let key = GetApiKey.resolve()
        XCTAssertFalse(key.isEmpty, "resolve() should always return a non-empty key")
    }

    func testResolveFallsBackToHardcodedKey() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        let key = GetApiKey.resolve()
        XCTAssertTrue(
            key.hasPrefix("AIza"),
            "Without env var or stored key, should fall back to hardcoded key"
        )
    }

    func testResolveUsesUserDefaultsWhenSet() {
        let customKey = "test-custom-api-key-12345"
        UserDefaults.standard.set(customKey, forKey: userDefaultsKey)

        let key = GetApiKey.resolve()
        XCTAssertEqual(key, customKey)
    }

    func testResolveIgnoresEmptyUserDefaults() {
        UserDefaults.standard.set("   ", forKey: userDefaultsKey)
        let key = GetApiKey.resolve()
        XCTAssertNotEqual(key.trimmingCharacters(in: .whitespacesAndNewlines), "")
    }

    func testHasUserProvidedKeyFalseByDefault() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        // Without env var set, this should reflect only UserDefaults state.
        // In test environments, GEMINI_API_KEY env var is typically not set.
        if ProcessInfo.processInfo.environment["GEMINI_API_KEY"] == nil {
            XCTAssertFalse(GetApiKey.hasUserProvidedKey)
        }
    }

    func testHasUserProvidedKeyTrueWhenStored() {
        UserDefaults.standard.set("my-key", forKey: userDefaultsKey)
        XCTAssertTrue(GetApiKey.hasUserProvidedKey)
    }
}
