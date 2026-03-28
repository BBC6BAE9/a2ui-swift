// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import v_09

/// Builds A2UI protocol messages (`A2uiMessage`) from mock travel data.
/// Uses v0.9 message format: `createSurface` + `updateComponents`.
enum MockServerToClientMessages {

    // MARK: - JSON Decoding Helper

    /// Decode a JSON dictionary into an `A2uiMessage`.
    /// Public so CatalogView can use the same decoding logic.
    static func decodeMessage(_ json: [String: Any]) -> A2uiMessage? {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        return try? JSONDecoder().decode(A2uiMessage.self, from: data)
    }

}
