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
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Type coercion helpers (non-throwing)

/// Encodes an AnyCodable value to a compact JSON string (no spaces).
/// Used by formatString interpolation to serialize objects/arrays per the A2UI spec:
///   "Objects/Arrays: Stringified as JSON to ensure consistency across different
///    client implementations."  (a2ui_protocol.md §Type conversion)
private func toJSONString(_ val: AnyCodable) -> String {
    let encoder = JSONEncoder()
    // .sortedKeys ensures deterministic output across platforms, matching the
    // JS JSON.stringify() key ordering that other A2UI renderers produce.
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(val),
          let str = String(data: data, encoding: .utf8)
    else { return "" }
    return str
}

private func toDouble(_ val: AnyCodable?) -> Double? {
    guard let val = val else { return nil }
    switch val {
    case .number(let n): return n
    case .string(let s): return Double(s)
    case .bool(let b):   return b ? 1.0 : 0.0
    default:             return nil
    }
}

private func toString(_ val: AnyCodable?) -> String? {
    guard let val = val else { return nil }
    switch val {
    case .string(let s): return s
    case .number(let n): return n == n.rounded() && !n.isInfinite ? String(Int(n)) : String(n)
    case .bool(let b):   return b ? "true" : "false"
    default:             return nil
    }
}

private func isTruthy(_ val: AnyCodable?) -> Bool {
    guard let val = val else { return false }
    switch val {
    case .null:               return false
    case .bool(let b):        return b
    case .number(let n):      return n != 0.0
    case .string(let s):      return !s.isEmpty
    case .array(let a):       return !a.isEmpty
    case .dictionary(let d):  return !d.isEmpty
    }
}

// MARK: - Argument validation helpers (throwing)
//
// These mirror the Zod schema validation that WebCore's Catalog.invoker performs
// before calling each function's execute(). When a required argument is missing
// or has an invalid type, an A2uiExpressionError is thrown, which flows through
// DataContext.resolveDynamicValue → surface.dispatchError → onError, allowing
// the host app to report the error back to the server.

/// Mirrors `z.preprocess(null → undefined, z.coerce.number())`:
/// both nil (missing key) AND .null throw; non-numeric strings also throw.
private func coerceRequiredDouble(
    _ val: AnyCodable?, argName: String, funcName: String
) throws -> Double {
    switch val {
    case nil, .some(.null):
        throw A2uiExpressionError(
            "Missing required argument '\(argName)' for '\(funcName)'",
            expression: funcName)
    default: break
    }
    guard let n = toDouble(val) else {
        throw A2uiExpressionError(
            "Invalid numeric argument '\(argName)' for '\(funcName)'",
            expression: funcName)
    }
    return n
}

/// Mirrors `z.coerce.number()` (no null preprocess):
/// nil (missing key) throws; .null coerces to 0 (Number(null) = 0 in JS).
private func coerceDouble(
    _ val: AnyCodable?, argName: String, funcName: String
) throws -> Double {
    guard let val else {
        throw A2uiExpressionError(
            "Missing required argument '\(argName)' for '\(funcName)'",
            expression: funcName)
    }
    if case .null = val { return 0.0 }
    guard let n = toDouble(val) else {
        throw A2uiExpressionError(
            "Invalid numeric argument '\(argName)' for '\(funcName)'",
            expression: funcName)
    }
    return n
}

/// Mirrors `z.any().refine(v => v !== undefined, "Required")`:
/// nil (missing key) throws; .null and any other value are returned as-is.
private func requirePresent(
    _ val: AnyCodable?, argName: String, funcName: String
) throws -> AnyCodable {
    guard let val else {
        throw A2uiExpressionError(
            "Missing required argument '\(argName)' for '\(funcName)'",
            expression: funcName)
    }
    return val
}

/// Mirrors `z.preprocess(v => v === undefined ? undefined : String(v), z.string())`:
/// nil (missing key) throws; .null coerces to "null" (String(null) in JS).
private func coerceRequiredString(
    _ val: AnyCodable?, argName: String, funcName: String
) throws -> String {
    guard let val else {
        throw A2uiExpressionError(
            "Missing required argument '\(argName)' for '\(funcName)'",
            expression: funcName)
    }
    if case .null = val { return "null" }
    guard let s = toString(val) else {
        throw A2uiExpressionError(
            "Invalid string argument '\(argName)' for '\(funcName)'",
            expression: funcName)
    }
    return s
}

// MARK: - Arithmetic

private func basicAdd(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let a = try coerceRequiredDouble(args["a"], argName: "a", funcName: name)
    let b = try coerceRequiredDouble(args["b"], argName: "b", funcName: name)
    return .number(a + b)
}

private func basicSubtract(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let a = try coerceRequiredDouble(args["a"], argName: "a", funcName: name)
    let b = try coerceRequiredDouble(args["b"], argName: "b", funcName: name)
    return .number(a - b)
}

private func basicMultiply(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let a = try coerceRequiredDouble(args["a"], argName: "a", funcName: name)
    let b = try coerceRequiredDouble(args["b"], argName: "b", funcName: name)
    return .number(a * b)
}

private func basicDivide(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let a = try coerceRequiredDouble(args["a"], argName: "a", funcName: name)
    let b = try coerceRequiredDouble(args["b"], argName: "b", funcName: name)
    if a.isNaN || b.isNaN { return .number(Double.nan) }
    if b == 0 { return .number(Double.infinity) }
    return .number(a / b)
}

// MARK: - Comparison

private func basicEquals(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let a = try requirePresent(args["a"], argName: "a", funcName: name)
    let b = try requirePresent(args["b"], argName: "b", funcName: name)
    return .bool(a == b)
}

private func basicNotEquals(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let a = try requirePresent(args["a"], argName: "a", funcName: name)
    let b = try requirePresent(args["b"], argName: "b", funcName: name)
    return .bool(a != b)
}

private func basicGreaterThan(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let a = try coerceRequiredDouble(args["a"], argName: "a", funcName: name)
    let b = try coerceRequiredDouble(args["b"], argName: "b", funcName: name)
    return .bool(a > b)
}

private func basicLessThan(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let a = try coerceRequiredDouble(args["a"], argName: "a", funcName: name)
    let b = try coerceRequiredDouble(args["b"], argName: "b", funcName: name)
    return .bool(a < b)
}

// MARK: - Logical

private func basicAnd(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    guard let rawVal = args["values"] else {
        throw A2uiExpressionError(
            "Missing required argument 'values' for '\(name)'", expression: name)
    }
    guard let arr = rawVal.arrayValue else {
        throw A2uiExpressionError(
            "Argument 'values' must be an array for '\(name)'", expression: name)
    }
    guard arr.count >= 2 else {
        throw A2uiExpressionError(
            "Argument 'values' must have at least 2 items for '\(name)'", expression: name)
    }
    return .bool(arr.allSatisfy { isTruthy($0) })
}

private func basicOr(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    guard let rawVal = args["values"] else {
        throw A2uiExpressionError(
            "Missing required argument 'values' for '\(name)'", expression: name)
    }
    guard let arr = rawVal.arrayValue else {
        throw A2uiExpressionError(
            "Argument 'values' must be an array for '\(name)'", expression: name)
    }
    guard arr.count >= 2 else {
        throw A2uiExpressionError(
            "Argument 'values' must have at least 2 items for '\(name)'", expression: name)
    }
    return .bool(arr.contains { isTruthy($0) })
}

private func basicNot(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let val = try requirePresent(args["value"], argName: "value", funcName: name)
    return .bool(!isTruthy(val))
}

// MARK: - String

private func basicContains(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let str = try coerceRequiredString(args["string"], argName: "string", funcName: name)
    let sub = try coerceRequiredString(args["substring"], argName: "substring", funcName: name)
    return .bool(str.contains(sub))
}

private func basicStartsWith(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let str = try coerceRequiredString(args["string"], argName: "string", funcName: name)
    let prefix = try coerceRequiredString(args["prefix"], argName: "prefix", funcName: name)
    return .bool(str.hasPrefix(prefix))
}

private func basicEndsWith(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let str = try coerceRequiredString(args["string"], argName: "string", funcName: name)
    let suffix = try coerceRequiredString(args["suffix"], argName: "suffix", funcName: name)
    return .bool(str.hasSuffix(suffix))
}

// MARK: - String transformation

private func basicCapitalize(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    guard let raw = args["value"] else {
        throw A2uiExpressionError(
            "Missing required argument 'value' for '\(name)'", expression: name)
    }
    guard let s = toString(raw), !s.isEmpty else { return .string("") }
    return .string(s.prefix(1).uppercased() + s.dropFirst())
}

// MARK: - Validation

private func basicRequired(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let val = try requirePresent(args["value"], argName: "value", funcName: name)
    switch val {
    case .null:               return .bool(false)
    case .string(let s):      return .bool(!s.isEmpty)
    case .array(let a):       return .bool(!a.isEmpty)
    default:                  return .bool(true)
    }
}

private func basicRegex(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let value   = try coerceRequiredString(args["value"],   argName: "value",   funcName: name)
    let pattern = try coerceRequiredString(args["pattern"], argName: "pattern", funcName: name)
    do {
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(value.startIndex..., in: value)
        return .bool(regex.firstMatch(in: value, range: range) != nil)
    } catch {
        throw A2uiExpressionError("Invalid regex pattern: \(pattern)", expression: name)
    }
}

private func basicLength(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let val = try requirePresent(args["value"], argName: "value", funcName: name)
    // Mirrors LengthApi refine: must provide at least one of min or max.
    guard args["min"] != nil || args["max"] != nil else {
        throw A2uiExpressionError(
            "Must provide either 'min' or 'max' for '\(name)'", expression: name)
    }
    var len = 0
    switch val {
    case .string(let s): len = s.count
    case .array(let a):  len = a.count
    default: break
    }
    if let minVal = toDouble(args["min"]), !minVal.isNaN, Double(len) < minVal { return .bool(false) }
    if let maxVal = toDouble(args["max"]), !maxVal.isNaN, Double(len) > maxVal { return .bool(false) }
    return .bool(true)
}

private func basicNumeric(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    // z.coerce.number(): null → 0, missing → throw
    let value = try coerceDouble(args["value"], argName: "value", funcName: name)
    // Mirrors NumericApi refine: must provide at least one of min or max.
    guard args["min"] != nil || args["max"] != nil else {
        throw A2uiExpressionError(
            "Must provide either 'min' or 'max' for '\(name)'", expression: name)
    }
    if value.isNaN { return .bool(false) }
    if let minVal = toDouble(args["min"]), !minVal.isNaN, value < minVal { return .bool(false) }
    if let maxVal = toDouble(args["max"]), !maxVal.isNaN, value > maxVal { return .bool(false) }
    return .bool(true)
}

private func basicEmail(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let value = try coerceRequiredString(args["value"], argName: "value", funcName: name)
    let pattern = "^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return .bool(false) }
    let range = NSRange(value.startIndex..., in: value)
    return .bool(regex.firstMatch(in: value, range: range) != nil)
}

// MARK: - Formatting

private func basicFormatString(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    // z.coerce.string(): missing → throw (String(undefined) = "undefined" in JS,
    // but we treat missing as a server error and throw for early failure).
    guard let rawVal = args["value"] else {
        throw A2uiExpressionError(
            "Missing required argument 'value' for '\(name)'", expression: name)
    }
    guard let template = toString(rawVal) else { return .string("") }
    let parser = ExpressionParser()
    let parts = try parser.parse(template)
    if parts.isEmpty { return .string("") }
    let resolved = parts.map { part -> String in
        let value = context.resolveDynamicValue(part)
        switch value {
        case .some(.string(let s)): return s
        case .some(.number(let n)):
            return n == n.rounded() && !n.isInfinite ? String(Int(n)) : String(n)
        case .some(.bool(let b)):   return b ? "true" : "false"
        case .some(.null), nil:     return ""
        // Spec §"formatString type conversion":
        //   Objects/Arrays → stringified as JSON for cross-client consistency.
        case .some(let compound):   return toJSONString(compound)
        }
    }
    return .string(resolved.joined())
}

private func basicFormatNumber(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let value = try coerceDouble(args["value"], argName: "value", funcName: name)
    if value.isNaN { return .string("") }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale.current
    if let decimals = toDouble(args["decimals"]) {
        let d = Int(decimals)
        formatter.minimumFractionDigits = d
        formatter.maximumFractionDigits = d
    }
    if let groupingVal = args["grouping"]?.boolValue {
        formatter.usesGroupingSeparator = groupingVal
    }
    return .string(formatter.string(from: NSNumber(value: value)) ?? "")
}

private func basicFormatCurrency(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let value = try coerceDouble(args["value"], argName: "value", funcName: name)
    if value.isNaN { return .string("") }
    let currency = (try? coerceRequiredString(args["currency"], argName: "currency", funcName: name)) ?? "USD"
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale.current
    formatter.currencyCode = currency
    if let decimals = toDouble(args["decimals"]) {
        let d = Int(decimals)
        formatter.minimumFractionDigits = d
        formatter.maximumFractionDigits = d
    }
    if let groupingVal = args["grouping"]?.boolValue {
        formatter.usesGroupingSeparator = groupingVal
    }
    if let result = formatter.string(from: NSNumber(value: value)) {
        return .string(result)
    }
    let decimals = toDouble(args["decimals"]).map { Int($0) } ?? 2
    return .string(String(format: "%.\(decimals)f", value))
}

private func basicFormatDate(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    // z.any().refine(v !== undefined): missing → throw; null → "" (falsy, return early)
    let rawValue = try requirePresent(args["value"], argName: "value", funcName: name)
    guard let value = toString(rawValue), !value.isEmpty else { return .string("") }
    guard let formatStr = toString(args["format"]) else { return .string("") }

    let parsers: [DateFormatter] = {
        let iso = DateFormatter(); iso.locale = Locale(identifier: "en_US_POSIX")
        iso.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        let iso2 = DateFormatter(); iso2.locale = Locale(identifier: "en_US_POSIX")
        iso2.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        let iso3 = DateFormatter(); iso3.locale = Locale(identifier: "en_US_POSIX")
        iso3.dateFormat = "yyyy-MM-dd"
        return [iso, iso2, iso3]
    }()

    var date: Date? = nil
    if #available(iOS 10.0, macOS 10.12, *) {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFmt.date(from: value) { date = d }
        if date == nil {
            isoFmt.formatOptions = [.withInternetDateTime]
            date = isoFmt.date(from: value)
        }
    }
    if date == nil {
        for parser in parsers { if let d = parser.date(from: value) { date = d; break } }
    }
    guard let parsedDate = date else { return .string("") }

    if formatStr == "ISO" {
        if #available(iOS 10.0, macOS 10.12, *) {
            let out = ISO8601DateFormatter()
            out.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return .string(out.string(from: parsedDate))
        }
    }
    let outputFormatter = DateFormatter()
    outputFormatter.locale = Locale.current
    outputFormatter.dateFormat = formatStr
    return .string(outputFormatter.string(from: parsedDate))
}

// WebCore `PluralizeImplementation`:
//   const rule = new Intl.PluralRules('en-US').select(args.value);
//   return String((args as Record<string, unknown>)[rule] ?? args.other ?? '');
private func basicPluralize(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let value = try coerceDouble(args["value"], argName: "value", funcName: name)
    _ = try coerceRequiredString(args["other"], argName: "other", funcName: name)
    let rule = A2UIPluralRules(localeIdentifier: "en-US").select(value)
    return .string(toString(args[rule]) ?? toString(args["other"]) ?? "")
}

private func basicOpenUrl(_ name: String, _ args: [String: AnyCodable], _ context: DataContext) throws -> AnyCodable? {
    let urlString = try coerceRequiredString(args["url"], argName: "url", funcName: name)
    guard let url = URL(string: urlString) else {
        throw A2uiExpressionError("Invalid URL '\(urlString)' for '\(name)'", expression: name)
    }
#if canImport(UIKit)
    DispatchQueue.main.async { UIApplication.shared.open(url) }
#elseif canImport(AppKit)
    NSWorkspace.shared.open(url)
#endif
    return nil
}

// MARK: - BASIC_FUNCTIONS dictionary

/// All 26 Basic Catalog function implementations, keyed by name.
/// Mirrors WebCore `BASIC_FUNCTIONS` in basic_catalog/functions/basic_functions.ts.
public nonisolated(unsafe) let BASIC_FUNCTIONS: [String: FunctionInvoker] = [
    "add":              basicAdd,
    "subtract":         basicSubtract,
    "multiply":         basicMultiply,
    "divide":           basicDivide,
    "equals":           basicEquals,
    "not_equals":       basicNotEquals,
    "greater_than":     basicGreaterThan,
    "less_than":        basicLessThan,
    "and":              basicAnd,
    "or":               basicOr,
    "not":              basicNot,
    "capitalize":       basicCapitalize,
    "contains":         basicContains,
    "starts_with":      basicStartsWith,
    "ends_with":        basicEndsWith,
    "required":         basicRequired,
    "regex":            basicRegex,
    "length":           basicLength,
    "numeric":          basicNumeric,
    "email":            basicEmail,
    "formatString":     basicFormatString,
    "formatNumber":     basicFormatNumber,
    "formatCurrency":   basicFormatCurrency,
    "formatDate":       basicFormatDate,
    "pluralize":        basicPluralize,
    "openUrl":          basicOpenUrl,
    "now": { _, _, _ in
        .string(ISO8601DateFormatter().string(from: Date()))
    },
]
