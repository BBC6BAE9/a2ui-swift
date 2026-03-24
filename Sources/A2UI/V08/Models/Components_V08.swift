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

// MARK: - RawComponentInstance_V08

/// A raw component instance from a surfaceUpdate message.
/// v0.8 nested format: `{"component":{"TextField":{...}}}`.
public struct RawComponentInstance_V08 {
    public var id: String
    public var weight: Double?
    public var component: RawComponentPayload_V08?
}

extension RawComponentInstance_V08: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, weight, component
    }

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        guard case .dictionary(let dict) = raw else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Component instance must be an object")
            )
        }

        guard let id = dict["id"]?.stringValue else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Component instance missing 'id'")
            )
        }
        self.id = id
        self.weight = dict["weight"]?.numberValue

        guard let componentVal = dict["component"] else {
            self.component = nil
            return
        }

        if case .dictionary(let compDict) = componentVal {
            // v0.8 nested format: {"TypeName": {prop1:..., prop2:...}}
            guard let (typeName, propsVal) = compDict.first else {
                self.component = nil
                return
            }
            if case .dictionary(let props) = propsVal {
                self.component = RawComponentPayload_V08(typeName: typeName, properties: props)
            } else {
                self.component = RawComponentPayload_V08(typeName: typeName, properties: [:])
            }
        } else {
            self.component = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(component, forKey: .component)
    }
}

// MARK: - RawComponentPayload_V08

/// Wraps the dynamic component type and its properties.
/// v0.8 JSON: `{"Text": {"text": {...}, "usageHint": "h1"}}`.
public struct RawComponentPayload_V08: Codable {
    public var typeName: String
    public var properties: [String: AnyCodable]

    public init(typeName: String, properties: [String: AnyCodable]) {
        self.typeName = typeName
        self.properties = properties
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        guard let firstKey = container.allKeys.first else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Empty component object")
            )
        }
        self.typeName = firstKey.stringValue
        self.properties = try container.decode([String: AnyCodable].self, forKey: firstKey)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        guard let key = DynamicKey(stringValue: typeName) else { return }
        try container.encode(properties, forKey: key)
    }
}

// MARK: - ChildrenReference_V08

/// The set of children for a container component (Row, Column, List).
/// v0.8 format: `{"explicitList":["a","b"]}` or `{"template":{...}}`.
public struct ChildrenReference_V08 {
    public var explicitList: [String]?
    public var template: TemplateReference_V08?
}

extension ChildrenReference_V08: Codable {
    private enum CodingKeys: String, CodingKey {
        case explicitList, template
    }

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        switch raw {
        case .dictionary(let dict):
            // v0.8: {"explicitList":[...]} or {"template":{...}}
            if case .array(let items) = dict["explicitList"] {
                self.explicitList = items.compactMap(\.stringValue)
            } else {
                self.explicitList = nil
            }
            if let tDict = dict["template"]?.dictionaryValue,
               let cid = tDict["componentId"]?.stringValue,
               let db = tDict["dataBinding"]?.stringValue {
                self.template = TemplateReference_V08(componentId: cid, dataBinding: db)
            } else {
                self.template = nil
            }
        default:
            self.explicitList = nil
            self.template = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(explicitList, forKey: .explicitList)
        try container.encodeIfPresent(template, forKey: .template)
    }
}

// MARK: - TemplateReference_V08

/// A template for generating dynamic lists from data model arrays/maps.
public struct TemplateReference_V08: Codable {
    public var componentId: String
    public var dataBinding: String
}

// MARK: - Action_V08

/// An action triggered by user interaction (e.g., button click).
/// v0.8 format: `{"name":"tap","context":[{"key":"k","value":{...}}]}`.
public struct Action_V08 {
    public var name: String
    public var context: [ActionContextEntry_V08]?
}

extension Action_V08: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, context
    }

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        guard case .dictionary(let dict) = raw else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Action_V08 must be an object")
            )
        }

        guard let name = dict["name"]?.stringValue else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Action_V08: expected 'name'")
            )
        }
        // v0.8: {"name":"tap","context":[{"key":"k","value":{...}}]}
        self.name = name
        if case .array(let items) = dict["context"] {
            self.context = items.compactMap(Self.decodeV08ContextEntry)
        } else {
            self.context = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(context, forKey: .context)
    }

    // MARK: - Helpers

    private static func decodeV08ContextEntry(_ item: AnyCodable) -> ActionContextEntry_V08? {
        guard case .dictionary(let d) = item,
              let key = d["key"]?.stringValue,
              let valRaw = d["value"] else { return nil }
        return ActionContextEntry_V08(key: key, value: boundValueFromAnyCodable(valRaw))
    }

    private static func boundValueFromAnyCodable(_ value: AnyCodable) -> BoundValue_V08 {
        switch value {
        case .string(let s):
            return BoundValue_V08(literalString: s)
        case .number(let n):
            return BoundValue_V08(literalNumber: n)
        case .bool(let b):
            return BoundValue_V08(literalBoolean: b)
        case .dictionary(let dict):
            if let path = dict["path"]?.stringValue {
                return BoundValue_V08(path: path)
            }
            if let s = dict["literalString"]?.stringValue {
                return BoundValue_V08(literalString: s)
            }
            if let n = dict["literalNumber"]?.numberValue {
                return BoundValue_V08(literalNumber: n)
            }
            if let b = dict["literalBoolean"]?.boolValue {
                return BoundValue_V08(literalBoolean: b)
            }
            return BoundValue_V08()
        default:
            return BoundValue_V08()
        }
    }
}

// MARK: - ActionContextEntry_V08

/// A key-value pair in an action's context payload.
public struct ActionContextEntry_V08: Codable {
    public var key: String
    public var value: BoundValue_V08
}

