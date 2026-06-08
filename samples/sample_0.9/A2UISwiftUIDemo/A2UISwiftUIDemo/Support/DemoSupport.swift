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

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

// MARK: - Catalog

/// The catalog used by every surface in this demo.
///
/// It reuses the v0.9 basic catalog (all standard components + functions such as
/// `formatDate`) and adds the demo's custom Rizzcharts component type names so
/// they pass catalog validation. The id matches the v0.9 spec basic catalog so
/// JSON copied verbatim from `specification/v0_9/catalogs/basic/examples` works.
let demoCatalogId = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"

let demoCatalog = Catalog(
    id: demoCatalogId,
    componentNames: basicCatalog.componentNames.union(["Canvas", "Chart", "GoogleMap"]),
    functions: basicCatalog.functions
)

// MARK: - Custom component catalog (Rizzcharts)

/// Renders the demo's custom component types. Returning `EmptyView()` tells the
/// framework to fall back to rendering the node's children (used for `Canvas`,
/// which is a plain container).
struct RizzCustomCatalog: CustomComponentCatalog {
    @ViewBuilder
    func build(typeName: String, node: ComponentNode, surface: SurfaceModel) -> some View {
        switch typeName {
        case "Chart":
            RizzchartChartView(node: node, surface: surface)
        case "GoogleMap":
            RizzchartMapView(node: node, surface: surface)
        default:
            // "Canvas" and any unknown type: framework renders children in a VStack.
            EmptyView()
        }
    }
}

// MARK: - SurfaceStore

/// Holds one `SurfaceViewModel` per surface id, in arrival order.
///
/// This is the v0.9 replacement for the v0.8 `SurfaceManager`. Each surface gets
/// its own `SurfaceModel` (created with `demoCatalog`) and `SurfaceViewModel`, so
/// `createSurface` / `updateComponents` / `updateDataModel` / `deleteSurface`
/// messages are routed to the right surface by id.
@Observable
final class SurfaceStore {
    let catalog: Catalog
    private(set) var orderedSurfaceIds: [String] = []
    private(set) var viewModels: [String: SurfaceViewModel] = [:]

    init(catalog: Catalog = demoCatalog) {
        self.catalog = catalog
    }

    func viewModel(for surfaceId: String) -> SurfaceViewModel? {
        viewModels[surfaceId]
    }

    @discardableResult
    func process(_ messages: [A2uiMessage]) -> [Error] {
        var errors: [Error] = []
        for message in messages {
            do { try process(message) } catch { errors.append(error) }
        }
        return errors
    }

    func process(_ message: A2uiMessage) throws {
        switch message {
        case .createSurface(let payload):
            let surface = SurfaceModel(
                id: payload.surfaceId,
                catalog: catalog,
                theme: payload.theme,
                sendDataModel: payload.sendDataModel
            )
            let vm = SurfaceViewModel(surface: surface)
            viewModels[payload.surfaceId] = vm
            if !orderedSurfaceIds.contains(payload.surfaceId) {
                orderedSurfaceIds.append(payload.surfaceId)
            }
            try vm.processMessage(message)

        case .updateComponents(let payload):
            try viewModels[payload.surfaceId]?.processMessage(message)

        case .updateDataModel(let payload):
            try viewModels[payload.surfaceId]?.processMessage(message)

        case .deleteSurface(let payload):
            try viewModels[payload.surfaceId]?.processMessage(message)
            viewModels[payload.surfaceId] = nil
            orderedSurfaceIds.removeAll { $0 == payload.surfaceId }
        }
    }

    func clearAll() {
        viewModels.removeAll()
        orderedSurfaceIds.removeAll()
    }
}

// MARK: - Message loading helpers

enum DemoMessages {
    /// Decodes an array of v0.9 messages from raw JSON data.
    /// Accepts either a top-level JSON array or newline-delimited JSON (JSONL).
    static func decode(_ data: Data) throws -> [A2uiMessage] {
        let decoder = JSONDecoder()
        // Fast path: a single JSON array of messages.
        if let messages = try? decoder.decode([A2uiMessage].self, from: data) {
            return messages
        }
        // Fallback: JSONL — one message per non-empty line.
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var messages: [A2uiMessage] = []
        for line in text.components(separatedBy: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            if let lineData = line.data(using: .utf8) {
                messages.append(try decoder.decode(A2uiMessage.self, from: lineData))
            }
        }
        return messages
    }

    /// Loads and decodes v0.9 messages from a bundled `.json` resource.
    static func load(_ filename: String) throws -> [A2uiMessage] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            throw DemoError.missingResource(filename)
        }
        return try decode(Data(contentsOf: url))
    }

    /// First surface id referenced by a message batch (used for single-surface pages).
    static func firstSurfaceId(_ messages: [A2uiMessage]) -> String? {
        for message in messages {
            switch message {
            case .createSurface(let p): return p.surfaceId
            case .updateComponents(let p): return p.surfaceId
            case .updateDataModel(let p): return p.surfaceId
            case .deleteSurface(let p): return p.surfaceId
            }
        }
        return nil
    }
}

enum DemoError: LocalizedError {
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name): return "\(name).json not found in bundle"
        }
    }
}

/// Builds a single `SurfaceViewModel` from a message batch, creating its backing
/// `SurfaceModel` with `demoCatalog` (so functions like `formatDate` resolve).
func makeSurfaceViewModel(
    from messages: [A2uiMessage],
    catalog: Catalog = demoCatalog
) -> SurfaceViewModel {
    let create: CreateSurfacePayload? = messages.compactMap {
        if case .createSurface(let p) = $0 { return p }
        return nil
    }.first
    let surface = SurfaceModel(
        id: create?.surfaceId ?? DemoMessages.firstSurfaceId(messages) ?? "main",
        catalog: catalog,
        theme: create?.theme,
        sendDataModel: create?.sendDataModel ?? false
    )
    let vm = SurfaceViewModel(surface: surface)
    vm.processMessages(messages)
    return vm
}

// MARK: - Pretty JSON

/// Re-serializes raw A2UI JSON (a JSON array or JSONL) into a pretty-printed
/// string for the "JSON" inspector tabs.
func prettyPrintedA2UIJSON(_ raw: String) -> String {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

    if let data = raw.data(using: .utf8),
       let value = try? decoder.decode(AnyCodable.self, from: data),
       let pretty = try? encoder.encode(value),
       let string = String(data: pretty, encoding: .utf8) {
        return string
    }
    // JSONL fallback: pretty-print each line.
    return raw
        .components(separatedBy: "\n")
        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        .map { line -> String in
            guard let data = line.data(using: .utf8),
                  let value = try? decoder.decode(AnyCodable.self, from: data),
                  let pretty = try? encoder.encode(value),
                  let string = String(data: pretty, encoding: .utf8)
            else { return line }
            return string
        }
        .joined(separator: "\n\n")
}
