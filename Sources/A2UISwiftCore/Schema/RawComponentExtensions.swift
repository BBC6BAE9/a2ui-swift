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

// MARK: - Typed Property Extraction

extension RawComponent {

    /// Flat JSON object matching the wire format, suitable for Draft 2020-12 catalog validation.
    public func asJSONObjectForValidation() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw A2uiValidationError("Cannot encode RawComponent for JSON Schema validation.")
        }
        return obj
    }

    /// The component type parsed from the `component` discriminator field.
    public var componentType: ComponentType {
        ComponentType.from(component)
    }

    /// Decode the properties dictionary into a strongly-typed struct.
    public func typedProperties<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(properties)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Parse accessibility attributes from the raw JSON.
    public func parseAccessibility(from rawJSON: AnyCodable?) -> A2UIAccessibility? {
        guard case .dictionary(let dict) = rawJSON,
              let accDict = dict["accessibility"]?.dictionaryValue else { return nil }
        return A2UIAccessibility.decode(from: accDict)
    }
}

// MARK: - A2UIAccessibility

/// Accessibility attributes for v0.9 components.
public struct A2UIAccessibility: Sendable {
    public var label: DynamicString?
    public var description: DynamicString?

    public init(label: DynamicString? = nil, description: DynamicString? = nil) {
        self.label = label
        self.description = description
    }
}

extension A2UIAccessibility {

    /// Decodes an `A2UIAccessibility` from an `"accessibility"` sub-dictionary of `AnyCodable`.
    /// Returns `nil` when the key is absent or not a dictionary.
    static func decode(from accDict: [String: AnyCodable]) -> A2UIAccessibility? {
        var acc = A2UIAccessibility()
        acc.label        = decodeDynamic(accDict["label"])
        acc.description  = decodeDynamic(accDict["description"])
        guard acc.label != nil || acc.description != nil else { return nil }
        return acc
    }

    /// Re-encodes the receiver as `[String: AnyCodable]` for inclusion in a JSON payload.
    /// Returns `nil` when both fields are absent.
    func toDict() -> [String: AnyCodable]? {
        var d: [String: AnyCodable] = [:]
        if let label       { d["label"]       = encodeDynamic(label) }
        if let description { d["description"] = encodeDynamic(description) }
        return d.isEmpty ? nil : d
    }

    // MARK: Private codec helpers

    private static func decodeDynamic(_ raw: AnyCodable?) -> DynamicString? {
        guard let raw,
              let data = try? JSONEncoder().encode(raw) else { return nil }
        return try? JSONDecoder().decode(DynamicString.self, from: data)
    }

    private func encodeDynamic(_ value: DynamicString) -> AnyCodable? {
        guard let data    = try? JSONEncoder().encode(value),
              let decoded = try? JSONDecoder().decode(AnyCodable.self, from: data)
        else { return nil }
        return decoded
    }
}
