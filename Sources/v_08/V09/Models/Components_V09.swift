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

// MARK: - RawComponentInstance_V09

/// A raw component instance from a v0.9 updateComponents message.
/// v0.9 flat format: `{"component":"Text","id":"t1","text":"hello","weight":1}`.
public struct RawComponentInstance_V09 {
    public var id: String
    public var component: String
    public var weight: Double?
    public var properties: [String: AnyCodable]
}

extension RawComponentInstance_V09: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        guard case .dictionary(var dict) = raw else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "v0.9 component must be an object")
            )
        }

        guard let id = dict.removeValue(forKey: "id")?.stringValue else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "v0.9 component missing 'id'")
            )
        }
        self.id = id

        guard let component = dict.removeValue(forKey: "component")?.stringValue else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "v0.9 component missing 'component' type discriminator")
            )
        }
        self.component = component
        self.weight = dict.removeValue(forKey: "weight")?.numberValue

        // Accessibility is parsed separately from the raw JSON, not from properties
        dict.removeValue(forKey: "accessibility")
        self.properties = dict
    }

    public func encode(to encoder: Encoder) throws {
        var dict = properties
        dict["id"] = .string(id)
        dict["component"] = .string(component)
        if let w = weight {
            dict["weight"] = .number(w)
        }
        var container = encoder.singleValueContainer()
        try container.encode(dict)
    }
}

// MARK: - Typed Property Extraction

extension RawComponentInstance_V09 {

    /// The component type parsed from the `component` discriminator field.
    public var componentType: ComponentType_V09 {
        ComponentType_V09.from(component)
    }

    /// Decode the properties dictionary into a strongly-typed struct.
    public func typedProperties<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(properties)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Parse accessibility attributes from the raw JSON.
    public func parseAccessibility(from rawJSON: AnyCodable?) -> A2UIAccessibility_V09? {
        guard case .dictionary(let dict) = rawJSON,
              let accDict = dict["accessibility"]?.dictionaryValue else {
            return nil
        }
        var acc = A2UIAccessibility_V09()
        if let labelRaw = accDict["label"] {
            let data = try? JSONEncoder().encode(labelRaw)
            acc.label = data.flatMap { try? JSONDecoder().decode(DynamicString_V09.self, from: $0) }
        }
        if let descRaw = accDict["description"] {
            let data = try? JSONEncoder().encode(descRaw)
            acc.description = data.flatMap { try? JSONDecoder().decode(DynamicString_V09.self, from: $0) }
        }
        return acc
    }
}

// MARK: - A2UIAccessibility_V09

/// Accessibility attributes for v0.9 components.
public struct A2UIAccessibility_V09 {
    public var label: DynamicString_V09?
    public var description: DynamicString_V09?
}
