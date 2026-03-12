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

// MARK: - RawComponentInstance

/// A raw component instance from a surfaceUpdate message.
/// v0.8 nested format: `{"component":{"TextField":{...}}}`.
public struct RawComponentInstance {
    public var id: String
    public var weight: Double?
    public var component: RawComponentPayload?
}

extension RawComponentInstance: Codable {
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
                self.component = RawComponentPayload(typeName: typeName, properties: props)
            } else {
                self.component = RawComponentPayload(typeName: typeName, properties: [:])
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

// MARK: - RawComponentPayload

/// Wraps the dynamic component type and its properties.
/// v0.8 JSON: `{"Text": {"text": {...}, "usageHint": "h1"}}`.
public struct RawComponentPayload: Codable {
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

// MARK: - ChildrenReference

/// The set of children for a container component (Row, Column, List).
/// v0.8 format: `{"explicitList":["a","b"]}` or `{"template":{...}}`.
public struct ChildrenReference {
    public var explicitList: [String]?
    public var template: TemplateReference?
}

extension ChildrenReference: Codable {
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
                self.template = TemplateReference(componentId: cid, dataBinding: db)
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

// MARK: - TemplateReference

/// A template for generating dynamic lists from data model arrays/maps.
public struct TemplateReference: Codable {
    public var componentId: String
    public var dataBinding: String
}

// MARK: - Action

/// An action triggered by user interaction (e.g., button click).
/// v0.8 format: `{"name":"tap","context":[{"key":"k","value":{...}}]}`.
public struct Action {
    public var name: String
    public var context: [ActionContextEntry]?
}

extension Action: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, context
    }

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        guard case .dictionary(let dict) = raw else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Action must be an object")
            )
        }

        guard let name = dict["name"]?.stringValue else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Action: expected 'name'")
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

    private static func decodeV08ContextEntry(_ item: AnyCodable) -> ActionContextEntry? {
        guard case .dictionary(let d) = item,
              let key = d["key"]?.stringValue,
              let valRaw = d["value"] else { return nil }
        return ActionContextEntry(key: key, value: boundValueFromAnyCodable(valRaw))
    }

    private static func boundValueFromAnyCodable(_ value: AnyCodable) -> BoundValue {
        switch value {
        case .string(let s):
            return BoundValue(literalString: s)
        case .number(let n):
            return BoundValue(literalNumber: n)
        case .bool(let b):
            return BoundValue(literalBoolean: b)
        case .dictionary(let dict):
            if let path = dict["path"]?.stringValue {
                return BoundValue(path: path)
            }
            if let s = dict["literalString"]?.stringValue {
                return BoundValue(literalString: s)
            }
            if let n = dict["literalNumber"]?.numberValue {
                return BoundValue(literalNumber: n)
            }
            if let b = dict["literalBoolean"]?.boolValue {
                return BoundValue(literalBoolean: b)
            }
            return BoundValue()
        default:
            return BoundValue()
        }
    }
}

// MARK: - ActionContextEntry

/// A key-value pair in an action's context payload.
public struct ActionContextEntry: Codable {
    public var key: String
    public var value: BoundValue
}

// MARK: - ResolvedAction

/// An action whose context paths have been resolved to actual values.
public struct ResolvedAction: Sendable {
    public let name: String
    public let sourceComponentId: String
    public let context: [String: AnyCodable]

    public init(name: String, sourceComponentId: String, context: [String: AnyCodable]) {
        self.name = name
        self.sourceComponentId = sourceComponentId
        self.context = context
    }
}
