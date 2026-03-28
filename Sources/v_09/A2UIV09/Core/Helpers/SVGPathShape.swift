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

/// A SwiftUI `Shape` that renders a basic subset of SVG path commands.
///
/// Supports: M/m (moveTo), L/l (lineTo), H/h (horizontal), V/v (vertical),
/// C/c (cubic bezier), S/s (smooth cubic), Q/q (quadratic), T/t (smooth quadratic),
/// A/a (arc - simplified), Z/z (close).
struct SVGPathShape: Shape {
    let svgPath: String

    func path(in rect: CGRect) -> Path {

        let parsed = parseSVGPath(svgPath)
        guard !parsed.isEmpty else { return Path() }

        // Inset slightly so anti-aliased edges aren't clipped at the boundary.
        let insetRect = rect.insetBy(dx: rect.width * 0.05, dy: rect.height * 0.05)

        // Compute bounding box to scale into rect
        var tempPath = Path()
        buildPath(&tempPath, from: parsed, in: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        let bounds = tempPath.boundingRect
        guard bounds.width > 0, bounds.height > 0 else { return tempPath }

        let scale = min(insetRect.width / bounds.width, insetRect.height / bounds.height)
        let offsetX = insetRect.midX - bounds.midX * scale
        let offsetY = insetRect.midY - bounds.midY * scale

        var finalPath = Path()
        buildPath(&finalPath, from: parsed, in: rect)

        return finalPath.applying(
            CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY)
                .scaledBy(x: scale, y: scale)
                .translatedBy(x: offsetX / scale, y: offsetY / scale)
        )
    }



    private enum Command {
        case moveTo(CGPoint, Bool)
        case lineTo(CGPoint, Bool)
        case horizontalTo(CGFloat, Bool)
        case verticalTo(CGFloat, Bool)
        case cubicTo(CGPoint, CGPoint, CGPoint, Bool)
        case quadTo(CGPoint, CGPoint, Bool)
        case closePath
    }

    private func buildPath(_ path: inout Path, from commands: [Command], in rect: CGRect) {
        var current = CGPoint.zero
        for cmd in commands {
            switch cmd {
            case .moveTo(let pt, let abs):
                let target = abs ? pt : CGPoint(x: current.x + pt.x, y: current.y + pt.y)
                path.move(to: target)
                current = target
            case .lineTo(let pt, let abs):
                let target = abs ? pt : CGPoint(x: current.x + pt.x, y: current.y + pt.y)
                path.addLine(to: target)
                current = target
            case .horizontalTo(let x, let abs):
                let target = CGPoint(x: abs ? x : current.x + x, y: current.y)
                path.addLine(to: target)
                current = target
            case .verticalTo(let y, let abs):
                let target = CGPoint(x: current.x, y: abs ? y : current.y + y)
                path.addLine(to: target)
                current = target
            case .cubicTo(let c1, let c2, let end, let abs):
                let e = abs ? end : CGPoint(x: current.x + end.x, y: current.y + end.y)
                let p1 = abs ? c1 : CGPoint(x: current.x + c1.x, y: current.y + c1.y)
                let p2 = abs ? c2 : CGPoint(x: current.x + c2.x, y: current.y + c2.y)
                path.addCurve(to: e, control1: p1, control2: p2)
                current = e
            case .quadTo(let ctrl, let end, let abs):
                let e = abs ? end : CGPoint(x: current.x + end.x, y: current.y + end.y)
                let c = abs ? ctrl : CGPoint(x: current.x + ctrl.x, y: current.y + ctrl.y)
                path.addQuadCurve(to: e, control: c)
                current = e
            case .closePath:
                path.closeSubpath()
            }
        }
    }

    private func parseSVGPath(_ d: String) -> [Command] {
        var commands: [Command] = []
        var scanner = SVGScanner(d)

        while let char = scanner.nextCommand() {
            let isAbsolute = char.isUppercase
            switch char.uppercased() {
            case "M":
                if let pt = scanner.nextPoint() {
                    commands.append(.moveTo(pt, isAbsolute))
                }
            case "L":
                if let pt = scanner.nextPoint() {
                    commands.append(.lineTo(pt, isAbsolute))
                }
            case "H":
                if let x = scanner.nextNumber() {
                    commands.append(.horizontalTo(x, isAbsolute))
                }
            case "V":
                if let y = scanner.nextNumber() {
                    commands.append(.verticalTo(y, isAbsolute))
                }
            case "C":
                if let c1 = scanner.nextPoint(),
                   let c2 = scanner.nextPoint(),
                   let end = scanner.nextPoint() {
                    commands.append(.cubicTo(c1, c2, end, isAbsolute))
                }
            case "Q":
                if let ctrl = scanner.nextPoint(),
                   let end = scanner.nextPoint() {
                    commands.append(.quadTo(ctrl, end, isAbsolute))
                }
            case "Z":
                commands.append(.closePath)
            default:
                break
            }
        }
        return commands
    }
}

/// Simple scanner for SVG path data strings.
struct SVGScanner {
    private let chars: [Character]
    private var index: Int = 0

    init(_ string: String) {
        self.chars = Array(string)
    }

    mutating func nextCommand() -> Character? {
        skipWhitespaceAndCommas()
        while index < chars.count {
            let c = chars[index]
            if c.isLetter {
                index += 1
                return c
            }
            // Skip numbers that might be implicit lineTo args
            if c == "-" || c == "." || c.isNumber {
                return nil
            }
            index += 1
        }
        return nil
    }

    mutating func nextNumber() -> CGFloat? {
        skipWhitespaceAndCommas()
        guard index < chars.count else { return nil }

        var numStr = ""
        if index < chars.count && (chars[index] == "-" || chars[index] == "+") {
            numStr.append(chars[index])
            index += 1
        }
        var hasDot = false
        while index < chars.count {
            let c = chars[index]
            if c.isNumber {
                numStr.append(c)
                index += 1
            } else if c == "." && !hasDot {
                hasDot = true
                numStr.append(c)
                index += 1
            } else {
                break
            }
        }
        guard let val = Double(numStr) else { return nil }
        return CGFloat(val)
    }

    mutating func nextPoint() -> CGPoint? {
        guard let x = nextNumber(), let y = nextNumber() else { return nil }
        return CGPoint(x: x, y: y)
    }

    private mutating func skipWhitespaceAndCommas() {
        while index < chars.count && (chars[index].isWhitespace || chars[index] == ",") {
            index += 1
        }
    }
}
