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

#if (canImport(UIKit) && !os(watchOS)) || canImport(AppKit)
import CoreGraphics
import Foundation

// MARK: - SVG path → CGPath
//
// A compact parser for the common SVG path commands (M/L/H/V/C/S/Q/T/Z, absolute
// and relative). Mirrors SwiftUI's SVGPathShape; arcs (A) are approximated by a
// line, which is sufficient for the material-style icon paths A2UI emits.

func a2ui_parseSVGPath(_ d: String) -> CGPath? {
    let path = CGMutablePath()
    var scanner = SVGScanner(d)
    var current = CGPoint.zero
    var start = CGPoint.zero
    var lastControl: CGPoint?
    var command: Character = " "

    func pt(_ x: CGFloat, _ y: CGFloat, relative: Bool) -> CGPoint {
        relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
    }

    while let cmd = scanner.nextCommand(currentCommand: command) {
        command = cmd
        let rel = cmd.isLowercase
        switch Character(cmd.uppercased()) {
        case "M":
            guard let x = scanner.number(), let y = scanner.number() else { return nil }
            current = pt(x, y, relative: rel); start = current
            path.move(to: current); lastControl = nil
        case "L":
            guard let x = scanner.number(), let y = scanner.number() else { return nil }
            current = pt(x, y, relative: rel); path.addLine(to: current); lastControl = nil
        case "H":
            guard let x = scanner.number() else { return nil }
            current = CGPoint(x: rel ? current.x + x : x, y: current.y)
            path.addLine(to: current); lastControl = nil
        case "V":
            guard let y = scanner.number() else { return nil }
            current = CGPoint(x: current.x, y: rel ? current.y + y : y)
            path.addLine(to: current); lastControl = nil
        case "C":
            guard let x1 = scanner.number(), let y1 = scanner.number(),
                  let x2 = scanner.number(), let y2 = scanner.number(),
                  let x = scanner.number(), let y = scanner.number() else { return nil }
            let c1 = pt(x1, y1, relative: rel), c2 = pt(x2, y2, relative: rel)
            current = pt(x, y, relative: rel)
            path.addCurve(to: current, control1: c1, control2: c2)
            lastControl = c2
        case "S":
            guard let x2 = scanner.number(), let y2 = scanner.number(),
                  let x = scanner.number(), let y = scanner.number() else { return nil }
            let c1 = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
            let c2 = pt(x2, y2, relative: rel)
            current = pt(x, y, relative: rel)
            path.addCurve(to: current, control1: c1, control2: c2)
            lastControl = c2
        case "Q":
            guard let x1 = scanner.number(), let y1 = scanner.number(),
                  let x = scanner.number(), let y = scanner.number() else { return nil }
            let c = pt(x1, y1, relative: rel)
            current = pt(x, y, relative: rel)
            path.addQuadCurve(to: current, control: c)
            lastControl = c
        case "T":
            guard let x = scanner.number(), let y = scanner.number() else { return nil }
            let c = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
            current = pt(x, y, relative: rel)
            path.addQuadCurve(to: current, control: c)
            lastControl = c
        case "Z":
            path.closeSubpath(); current = start; lastControl = nil
        case "A":
            // Arc approximated by a line (rx ry rot large sweep x y).
            for _ in 0..<5 { _ = scanner.number() }
            if let x = scanner.number(), let y = scanner.number() {
                current = pt(x, y, relative: rel); path.addLine(to: current)
            }
            lastControl = nil
        default:
            return nil
        }
    }
    return path.isEmpty ? nil : path
}

/// Minimal tokenizer for SVG path data.
private struct SVGScanner {
    private let chars: [Character]
    private var i = 0

    init(_ s: String) { chars = Array(s) }

    private mutating func skipSeparators() {
        while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i] == "\n" || chars[i] == "\t" {
            i += 1
        }
    }

    /// Returns the next command letter, or repeats `currentCommand` for implicit
    /// repeated coordinates (e.g. "L 1 2 3 4").
    mutating func nextCommand(currentCommand: Character) -> Character? {
        skipSeparators()
        guard i < chars.count else { return nil }
        if chars[i].isLetter {
            let c = chars[i]; i += 1; return c
        }
        return currentCommand == " " ? nil : currentCommand
    }

    mutating func number() -> CGFloat? {
        skipSeparators()
        var s = ""
        if i < chars.count, chars[i] == "-" || chars[i] == "+" { s.append(chars[i]); i += 1 }
        while i < chars.count, chars[i].isNumber || chars[i] == "." || chars[i] == "e" || chars[i] == "E"
              || ((chars[i] == "-" || chars[i] == "+") && (s.last == "e" || s.last == "E")) {
            s.append(chars[i]); i += 1
        }
        return Double(s).map { CGFloat($0) }
    }
}

#endif
