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

/// All standard A2UI v0.9 component types, plus `.custom` for extensions.
public enum ComponentType: Hashable {
    case Text, Image, Icon, Video, AudioPlayer
    case Row, Column, List, Card, Tabs, Divider, Modal
    case Button, CheckBox, TextField, DateTimeInput, ChoicePicker, Slider
    case custom(String)

    /// Map from raw type name string to `ComponentType`.
    public static func from(_ typeName: String) -> ComponentType {
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
        case "ChoicePicker": return .ChoicePicker
        case "Slider": return .Slider
        default: return .custom(typeName)
        }
    }
}

// MARK: - Property Enums

/// Text variant: h1–h5, caption, body.
public enum TextVariant: Codable, Hashable {
    case h1, h2, h3, h4, h5, caption, body
    case unknown(String)

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "h1": self = .h1
        case "h2": self = .h2
        case "h3": self = .h3
        case "h4": self = .h4
        case "h5": self = .h5
        case "caption": self = .caption
        case "body": self = .body
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var rawValue: String {
        switch self {
        case .h1: return "h1"
        case .h2: return "h2"
        case .h3: return "h3"
        case .h4: return "h4"
        case .h5: return "h5"
        case .caption: return "caption"
        case .body: return "body"
        case .unknown(let s): return s
        }
    }
}

/// Image fit mode.
public enum ImageFit: Codable, Hashable {
    case contain, cover, fill, none, scaleDown
    case unknown(String)

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "contain": self = .contain
        case "cover": self = .cover
        case "fill": self = .fill
        case "none": self = .none
        case "scaleDown", "scale-down": self = .scaleDown
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var rawValue: String {
        switch self {
        case .contain: return "contain"
        case .cover: return "cover"
        case .fill: return "fill"
        case .none: return "none"
        case .scaleDown: return "scaleDown"
        case .unknown(let s): return s
        }
    }
}

/// Image variant.
public enum ImageVariant: Codable, Hashable {
    case icon, avatar, smallFeature, mediumFeature, largeFeature, header
    case unknown(String)

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "icon": self = .icon
        case "avatar": self = .avatar
        case "smallFeature": self = .smallFeature
        case "mediumFeature": self = .mediumFeature
        case "largeFeature": self = .largeFeature
        case "header": self = .header
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var rawValue: String {
        switch self {
        case .icon: return "icon"
        case .avatar: return "avatar"
        case .smallFeature: return "smallFeature"
        case .mediumFeature: return "mediumFeature"
        case .largeFeature: return "largeFeature"
        case .header: return "header"
        case .unknown(let s): return s
        }
    }
}

/// Justify mode for Row/Column (maps to CSS justify-content).
public enum Justify: Codable, Hashable {
    case start, center, end, spaceBetween, spaceAround, spaceEvenly, stretch
    case unknown(String)

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "start": self = .start
        case "center": self = .center
        case "end": self = .end
        case "spaceBetween": self = .spaceBetween
        case "spaceAround": self = .spaceAround
        case "spaceEvenly": self = .spaceEvenly
        case "stretch": self = .stretch
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var rawValue: String {
        switch self {
        case .start: return "start"
        case .center: return "center"
        case .end: return "end"
        case .spaceBetween: return "spaceBetween"
        case .spaceAround: return "spaceAround"
        case .spaceEvenly: return "spaceEvenly"
        case .stretch: return "stretch"
        case .unknown(let s): return s
        }
    }
}

/// Align mode for Row/Column/List (maps to CSS align-items).
public enum Align: Codable, Hashable {
    case start, center, end, stretch
    case unknown(String)

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "start": self = .start
        case "center": self = .center
        case "end": self = .end
        case "stretch": self = .stretch
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var rawValue: String {
        switch self {
        case .start: return "start"
        case .center: return "center"
        case .end: return "end"
        case .stretch: return "stretch"
        case .unknown(let s): return s
        }
    }
}

/// List direction.
public enum ListDirection: Codable, Hashable {
    case vertical, horizontal
    case unknown(String)

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "vertical": self = .vertical
        case "horizontal": self = .horizontal
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var rawValue: String {
        switch self {
        case .vertical: return "vertical"
        case .horizontal: return "horizontal"
        case .unknown(let s): return s
        }
    }
}

/// Divider axis.
public enum DividerAxis: Codable, Hashable {
    case horizontal, vertical
    case unknown(String)

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "horizontal": self = .horizontal
        case "vertical": self = .vertical
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var rawValue: String {
        switch self {
        case .horizontal: return "horizontal"
        case .vertical: return "vertical"
        case .unknown(let s): return s
        }
    }
}

/// Button variant.
public enum ButtonVariant_Enum: Codable, Hashable {
    case `default`, primary, borderless
    case unknown(String)

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "default": self = .default
        case "primary": self = .primary
        case "borderless": self = .borderless
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var rawValue: String {
        switch self {
        case .default: return "default"
        case .primary: return "primary"
        case .borderless: return "borderless"
        case .unknown(let s): return s
        }
    }
}

/// TextField variant.
public enum TextFieldVariant: Codable, Hashable {
    case shortText, longText, number, obscured
    case unknown(String)

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "shortText": self = .shortText
        case "longText": self = .longText
        case "number": self = .number
        case "obscured": self = .obscured
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var rawValue: String {
        switch self {
        case .shortText: return "shortText"
        case .longText: return "longText"
        case .number: return "number"
        case .obscured: return "obscured"
        case .unknown(let s): return s
        }
    }
}

/// ChoicePicker display style.
public enum ChoicePickerDisplayStyle: Codable, Hashable {
    case checkbox, chips
    case unknown(String)

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "checkbox": self = .checkbox
        case "chips": self = .chips
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var rawValue: String {
        switch self {
        case .checkbox: return "checkbox"
        case .chips: return "chips"
        case .unknown(let s): return s
        }
    }
}

/// ChoicePicker selection variant.
///
/// Spec (basic_catalog.json:619-624):
///   `variant: "multipleSelection" | "mutuallyExclusive"` (default `mutuallyExclusive`).
/// Reference renderers (Lit/React/Angular/Flutter) all apply the spec default
/// when the field is absent — Swift renderer must do the same explicitly because
/// it does not run schema-level default coercion.
public enum ChoicePickerVariant: Codable, Hashable {
    case mutuallyExclusive, multipleSelection
    case unknown(String)

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "mutuallyExclusive": self = .mutuallyExclusive
        case "multipleSelection": self = .multipleSelection
        default: self = .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var rawValue: String {
        switch self {
        case .mutuallyExclusive: return "mutuallyExclusive"
        case .multipleSelection: return "multipleSelection"
        case .unknown(let s): return s
        }
    }
}

// MARK: - Basic Content

public struct TextProperties: Codable {
    public var text: DynamicString
    public var variant: TextVariant?
}

public struct ImageProperties: Codable {
    public var url: DynamicString
    public var fit: ImageFit?
    public var variant: ImageVariant?
}

public struct IconProperties: Codable {
    public var name: IconNameValue
}

/// v0.9 Icon.name: either an enum string or `{"path":"M10 20..."}` for custom SVG.
public enum IconNameValue: Codable {
    case standard(DynamicString)
    case customPath(String)

    public init(from decoder: Decoder) throws {
        let raw = try AnyCodable(from: decoder)
        switch raw {
        case .string(let s):
            self = .standard(.literal(s))
        case .dictionary(let dict):
            if dict.count == 1,
               let pathStr = dict["path"]?.stringValue,
               Self.looksLikeSVGPath(pathStr) {
                self = .customPath(pathStr)
            } else {
                let data = try JSONEncoder().encode(raw)
                let ds = try JSONDecoder().decode(DynamicString.self, from: data)
                self = .standard(ds)
            }
        default:
            self = .standard(.literal(""))
        }
    }

    private static func looksLikeSVGPath(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return false }
        return (first == "M" || first == "m") && trimmed.count > 2
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .standard(let ds):
            try ds.encode(to: encoder)
        case .customPath(let path):
            var container = encoder.singleValueContainer()
            try container.encode(["path": path])
        }
    }
}

// MARK: - Media

public struct VideoProperties: Codable {
    public var url: DynamicString
}

public struct AudioPlayerProperties: Codable {
    public var url: DynamicString
    public var description: DynamicString?
}

// MARK: - Layout & Containers

public struct RowProperties: Codable {
    public var children: ChildList
    public var justify: Justify?
    public var align: Align?
}

public struct ColumnProperties: Codable {
    public var children: ChildList
    public var justify: Justify?
    public var align: Align?
}

public struct ListProperties: Codable {
    public var children: ChildList
    public var direction: ListDirection?
    public var align: Align?
}

public struct CardProperties: Codable {
    public var child: String
}

public struct TabItemEntry: Codable {
    public var title: DynamicString
    public var child: String
}

public struct TabsProperties: Codable {
    public var tabs: [TabItemEntry]
}

public struct ModalProperties: Codable {
    public var trigger: String
    public var content: String
}

public struct DividerProperties: Codable {
    public var axis: DividerAxis?
}

// MARK: - Interactive & Input

public struct ButtonProperties: Codable {
    public var child: String
    public var action: Action
    public var variant: ButtonVariant_Enum?
    /// Spec §617 (a2ui_protocol.md): "If any check fails, the button is automatically disabled."
    public var checks: [CheckRule]?
}

public struct TextFieldProperties: Codable {
    public var label: DynamicString?
    public var value: DynamicString
    public var variant: TextFieldVariant?
    public var validationRegexp: String?
    public var checks: [CheckRule]?
}

public struct CheckBoxProperties: Codable {
    public var label: DynamicString
    public var value: DynamicBoolean
    public var checks: [CheckRule]?
}

public struct SliderProperties: Codable {
    public var label: DynamicString?
    public var value: DynamicNumber
    public var min: Double?
    public var max: Double
    public var checks: [CheckRule]?
}

public struct DateTimeInputProperties: Codable {
    public var value: DynamicString
    public var enableDate: Bool?
    public var enableTime: Bool?
    public var min: DynamicString?
    public var max: DynamicString?
    public var label: DynamicString?
    public var checks: [CheckRule]?
}

public struct ChoicePickerOption: Codable {
    public var label: DynamicString
    public var value: String
}

public struct ChoicePickerProperties: Codable {
    public var label: DynamicString?
    public var options: [ChoicePickerOption]
    public var value: DynamicStringList?
    public var displayStyle: ChoicePickerDisplayStyle?
    /// Spec (basic_catalog.json:619-624): default `mutuallyExclusive` when absent.
    public var variant: ChoicePickerVariant?
    public var filterable: Bool?
    public var checks: [CheckRule]?
}
