// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI
import A2UISwiftCore
import A2UISwiftUI

/// Helper functions for reading properties from A2UI `ComponentNode`.
enum A2UIHelpers {

    /// Resolve a string from a component property (literal or data path).
    static func resolveString(_ value: AnyCodable?, surface: SurfaceModel, dataContextPath: String = "/") -> String? {
        guard let value else { return nil }
        switch value {
        case .string(let s):
            return s.isEmpty ? nil : s
        case .dictionary(let dict):
            if let path = dict["path"]?.stringValue {
                let resolved = DataContext(surface: surface, path: dataContextPath)
                    .resolveDynamicValue(.dataBinding(path: path))?.stringValue
                return resolved?.isEmpty == false ? resolved : nil
            }
            let s = dict["literalString"]?.stringValue ?? dict["literal"]?.stringValue
            return s?.isEmpty == false ? s : nil
        default:
            return nil
        }
    }

    /// Resolve a list of strings from a component property.
    static func resolveStringList(_ value: AnyCodable?, surface: SurfaceModel, dataContextPath: String = "/") -> [String] {
        guard case .array(let arr) = value else { return [] }
        return arr.compactMap { resolveString($0, surface: surface, dataContextPath: dataContextPath) }
    }

    /// Resolve a boolean from a component property.
    static func resolveBool(_ value: AnyCodable?, surface: SurfaceModel, dataContextPath: String = "/") -> Bool? {
        guard let value else { return nil }
        switch value {
        case .bool(let b):
            return b
        case .dictionary(let dict):
            if let path = dict["path"]?.stringValue {
                return DataContext(surface: surface, path: dataContextPath)
                    .resolveDynamicValue(.dataBinding(path: path))?.boolValue
            }
            return dict["literalBoolean"]?.boolValue ?? dict["literal"]?.boolValue
        default:
            return nil
        }
    }

    /// Resolve an Action from a component property and return a ResolvedAction.
    static func resolveAction(
        _ value: AnyCodable?,
        node: ComponentNode,
        surface: SurfaceModel
    ) -> ResolvedAction? {
        guard let value,
              case .dictionary(let dict) = value,
              let eventDict = dict["event"]?.dictionaryValue,
              let name = eventDict["name"]?.stringValue else { return nil }
        var context: [String: AnyCodable] = [:]
        if let ctx = eventDict["context"]?.dictionaryValue {
            context = ctx
        }
        return ResolvedAction(name: name, sourceComponentId: node.id, context: context)
    }
}
