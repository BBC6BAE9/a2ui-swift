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

/// All standard A2UI v0.8 component types, plus `.custom` for extensions.
public enum ComponentType_V08: Hashable {
    case Text, Image, Icon, Video, AudioPlayer
    case Row, Column, List, Card, Tabs, Divider, Modal
    case Button, CheckBox, TextField, DateTimeInput, MultipleChoice, Slider
    case custom(String)

    /// Map from raw type name string to `ComponentType_V08`.
    public static func from(_ typeName: String) -> ComponentType_V08 {
        switch typeName {
        case "Text": return .Text
        case "Image": return .Image
        case "Icon": return .Icon
        case "Video": return .Video
        case "AudioPlayer": return .AudioPlayer
        case "Row": return .Row
        case "Column": return .Column
        case "List": return .List
        case "Card": return .Card
        case "Tabs": return .Tabs
        case "Divider": return .Divider
        case "Modal": return .Modal
        case "Button": return .Button
        case "CheckBox": return .CheckBox
        case "TextField": return .TextField
        case "DateTimeInput": return .DateTimeInput
        case "MultipleChoice": return .MultipleChoice
        case "Slider": return .Slider
        default: return .custom(typeName)
        }
    }
}

// MARK: - Basic Content

public struct TextProperties_V08: Codable {
    public var text: StringValue_V08
    public var usageHint: String?
}

public struct ImageProperties_V08: Codable {
    public var url: StringValue_V08
    public var usageHint: String?
    public var fit: String?
}

public struct IconProperties_V08: Codable {
    /// Either a standard icon name string or a custom icon with SVG path.
    public var name: IconNameValue_V08
}

/// Represents the `Icon.name` property which can be either a standard
/// icon name string or a custom icon with an SVG path.
public enum IconNameValue_V08: Codable {
    case standard(StringValue_V08)
    case customPath(String)

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        switch raw {
        case .string(let s):
            self = .standard(StringValue_V08(literalString: s))
        case .dictionary(let dict):
            // Custom SVG path: {"path": "M10 20 L30 40..."} — the value
            // starts with an SVG command letter, not "/" (data binding).
            if dict.count == 1,
               let pathStr = dict["path"]?.stringValue,
               Self.looksLikeSVGPath(pathStr) {
                self = .customPath(pathStr)
            } else {
                // Data binding, literalString, or function call — decode as StringValue_V08.
                let sv = try StringValue_V08(from: decoder)
                self = .standard(sv)
            }
        default:
            self = .standard(StringValue_V08())
        }
    }

    /// Heuristic: an SVG path starts with a move command (M/m) and contains
    /// drawing commands, while a data-model path starts with "/" or is a
    /// relative key like "iconName".
    private static func looksLikeSVGPath(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return false }
        // SVG paths start with M (absolute) or m (relative) move-to command
        return (first == "M" || first == "m") && trimmed.count > 2
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .standard(let sv):
            try sv.encode(to: encoder)
        case .customPath(let path):
            var container = encoder.singleValueContainer()
            try container.encode(["path": path])
        }
    }
}

// MARK: - Media

public struct VideoProperties_V08: Codable {
    public var url: StringValue_V08
}

public struct AudioPlayerProperties_V08: Codable {
    public var url: StringValue_V08
    public var description: StringValue_V08?
}

// MARK: - Layout & Containers

public struct RowProperties_V08: Codable {
    public var children: ChildrenReference_V08
    public var distribution: String?
    public var alignment: String?
}

public struct ColumnProperties_V08: Codable {
    public var children: ChildrenReference_V08
    public var distribution: String?
    public var alignment: String?
}

public struct ListProperties_V08: Codable {
    public var children: ChildrenReference_V08
    public var direction: String?
    public var alignment: String?
}

public struct CardProperties_V08: Codable {
    public var child: String
}

public struct TabItemEntry_V08: Codable {
    public var title: StringValue_V08
    public var child: String
}

public struct TabsProperties_V08: Codable {
    public var tabItems: [TabItemEntry_V08]
}

public struct ModalProperties_V08: Codable {
    public var entryPointChild: String
    public var contentChild: String
}

public struct DividerProperties_V08: Codable {
    public var axis: String?
}

// MARK: - Interactive & Input

public struct ButtonProperties_V08: Codable {
    public var child: String
    public var action: Action_V08
    public var primary: Bool?
}

public struct TextFieldProperties_V08: Codable {
    public var label: StringValue_V08
    public var text: StringValue_V08?
    public var textFieldType: String?
    public var validationRegexp: String?
}

public struct CheckBoxProperties_V08: Codable {
    public var label: StringValue_V08
    public var value: BooleanValue_V08
}

public struct SliderProperties_V08: Codable {
    public var label: StringValue_V08?
    public var value: NumberValue_V08
    public var minValue: Double?
    public var maxValue: Double?
}

public struct DateTimeInputProperties_V08: Codable {
    public var value: StringValue_V08
    public var enableDate: Bool?
    public var enableTime: Bool?
    public var label: StringValue_V08?
}

public struct MultipleChoiceOption_V08: Codable {
    public var label: StringValue_V08
    public var value: String
}

/// v0.8 `selections` value: `{"path":"..."}` or `{"literalArray":[...]}`.
public struct StringListValue_V08 {
    public var path: String?
    public var literalArray: [String]?
}

extension StringListValue_V08: Codable {
    private enum CodingKeys: String, CodingKey {
        case path, literalArray
    }

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        switch raw {
        case .dictionary(let dict):
            self.path = dict["path"]?.stringValue
            self.literalArray = dict["literalArray"]?.arrayValue?.compactMap(\.stringValue)
        case .string(let s):
            self.path = s
            self.literalArray = nil
        default:
            self.path = nil
            self.literalArray = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(path, forKey: .path)
        try container.encodeIfPresent(literalArray, forKey: .literalArray)
    }
}

public struct MultipleChoiceProperties_V08: Codable {
    public var description: StringValue_V08?
    public var variant: String?
    public var options: [MultipleChoiceOption_V08]?
    public var selections: StringListValue_V08?
    public var filterable: Bool?
    public var maxAllowedSelections: Int?
}

// MARK: - Typed Property Extraction

extension RawComponentPayload_V08 {

    /// The component type parsed from the dynamic key name.
    /// Returns `.custom(typeName)` for unknown types instead of nil.
    public var componentType: ComponentType_V08 {
        ComponentType_V08.from(typeName)
    }

    /// Decode the raw properties dictionary into a strongly-typed struct.
    /// Re-encodes `[String: AnyCodable]` to JSON, then decodes into `T`.
    public func typedProperties<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(properties)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
