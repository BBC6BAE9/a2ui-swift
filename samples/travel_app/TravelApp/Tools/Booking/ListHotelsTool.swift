// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/// An `AiTool` for listing hotels.
/// Mirrors Flutter's `ListHotelsTool` in `tools/booking/list_hotels_tool.dart`.
struct ListHotelsTool: AiTool {
    let name = "listHotels"
    let description = "Lists hotels based on the provided criteria."

    let parameters: [String: Any]? = [
        "type": "object",
        "properties": [
            "query": [
                "type": "string",
                "description": "The search query, e.g., \"hotels in Paris\".",
            ] as [String: Any],
            "checkIn": [
                "type": "string",
                "description":
                    "The check-in date in ISO 8601 format (YYYY-MM-DD).",
                "format": "date",
            ] as [String: Any],
            "checkOut": [
                "type": "string",
                "description":
                    "The check-out date in ISO 8601 format (YYYY-MM-DD).",
                "format": "date",
            ] as [String: Any],
            "guests": [
                "type": "integer",
                "description": "The number of guests.",
            ] as [String: Any],
        ] as [String: Any],
        "required": ["query", "checkIn", "checkOut", "guests"],
    ]

    let onListHotels: (HotelSearch) async -> HotelSearchResult

    func invoke(_ args: [String: Any]) async throws -> [String: Any] {
        let search = HotelSearch.fromJson(args)
        return await onListHotels(search).toAiInput()
    }
}
