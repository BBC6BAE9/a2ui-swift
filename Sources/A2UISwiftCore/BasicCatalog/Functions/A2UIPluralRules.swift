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

/// CLDR cardinal plural selection; mirrors `Intl.PluralRules(locale).select(n)`.
///
/// Pure-Swift port of the CLDR plural rules (v44 `plurals.xml`, cardinal type),
/// so `A2UISwiftCore` needs no ICU dependency. Semantics match `Intl.PluralRules`
/// with default options: the number is first formatted with at most 3 fraction
/// digits (half-away-from-zero), and the CLDR operands (n, i, v, f) are derived
/// from that rendering. Trailing fraction zeros never occur (doubles carry no
/// formatting), so `w == v` and `t == f`; compact-notation exponents (`e`/`c`)
/// are always 0.
///
/// Unknown languages fall back to the root rule set (always `"other"`), matching
/// ICU / `Intl.PluralRules` behavior for unrecognized locales.
struct A2UIPluralRules {
    private var localeIdentifier: String

    init(localeIdentifier: String) {
        self.localeIdentifier = localeIdentifier
    }

    func select(_ number: Double) -> String {
        // Intl.PluralRules maps non-finite values to "other".
        guard number.isFinite else { return "other" }
        let rule = Self.ruleSet(for: localeIdentifier)
        return rule(PluralOperands(abs(number)))
    }
}

// MARK: - CLDR operands

/// The CLDR plural operands for a non-negative finite value, per
/// https://unicode.org/reports/tr35/tr35-numbers.html#Operands
private struct PluralOperands {
    /// `i` — integer part of the formatted value. Integral-valued; kept as
    /// `Double` so magnitudes beyond `Int64` still work with `%` helpers.
    let i: Double
    /// `v` — count of visible fraction digits (trailing zeros stripped; ≤ 3).
    let v: Int
    /// `f` — visible fraction digits as an integer (equals `t` here).
    let f: Int

    init(_ n: Double) {
        // Above 2^53 every double is integral; skip the fixed-point path
        // (which scales by 1000) to avoid Int64 overflow.
        if n >= 9_007_199_254_740_992 {
            i = n
            v = 0
            f = 0
            return
        }
        // Round to 3 fraction digits (Intl default maximumFractionDigits,
        // halfExpand), then strip trailing zeros.
        let scaled = Int64((n * 1000).rounded(.toNearestOrAwayFromZero))
        let fraction = Int(scaled % 1000)
        i = Double(scaled / 1000)
        if fraction == 0 {
            (v, f) = (0, 0)
        } else if fraction % 100 == 0 {
            (v, f) = (1, fraction / 100)
        } else if fraction % 10 == 0 {
            (v, f) = (2, fraction / 10)
        } else {
            (v, f) = (3, fraction)
        }
    }

    /// True when the formatted value is an integer (`n` has no visible fraction).
    var isInt: Bool { v == 0 }

    func iMod(_ m: Int) -> Int {
        Int(i.truncatingRemainder(dividingBy: Double(m)))
    }

    func iIs(_ values: Int...) -> Bool {
        values.contains { Double($0) == i }
    }

    func iIn(_ range: ClosedRange<Int>) -> Bool {
        i >= Double(range.lowerBound) && i <= Double(range.upperBound)
    }

    // `n`-based relations. CLDR range/equality relations against integer
    // constants can only match when `n` itself is an integer, and after
    // trailing-zero stripping `v == 0` implies `n == i`.
    func nIs(_ values: Int...) -> Bool {
        isInt && values.contains { Double($0) == i }
    }

    func nIn(_ range: ClosedRange<Int>) -> Bool {
        isInt && iIn(range)
    }

    func nMod(_ m: Int, is values: Int...) -> Bool {
        isInt && values.contains(iMod(m))
    }

    func nMod(_ m: Int, in range: ClosedRange<Int>) -> Bool {
        isInt && range.contains(iMod(m))
    }
}

// MARK: - Rule sets

/// One function per distinct CLDR cardinal rule set; comments quote the CLDR
/// rule source. Categories are checked in CLDR order (zero, one, two, few, many).
private typealias PluralRuleSet = (PluralOperands) -> String

extension A2UIPluralRules {

    /// Root rules: everything is "other" (ja, zh, ko, th, vi, id, …).
    private static let otherOnly: PluralRuleSet = { _ in "other" }

    /// one: `n = 1` (tr, el, bg, hu, kk, sq, ta, te, …)
    private static let oneWhenN1: PluralRuleSet = { o in
        o.nIs(1) ? "one" : "other"
    }

    /// one: `i = 1 and v = 0` (en, de, nl, sv, fi, et, ur, sw, …)
    private static let oneWhenI1V0: PluralRuleSet = { o in
        o.iIs(1) && o.v == 0 ? "one" : "other"
    }

    /// one: `i = 0,1` (ff, hy, kab)
    private static let oneWhenI0or1: PluralRuleSet = { o in
        o.iIs(0, 1) ? "one" : "other"
    }

    /// fr — one: `i = 0,1`; many: `e = 0 and i != 0 and i % 1000000 = 0 and v = 0`
    private static let french: PluralRuleSet = { o in
        if o.iIs(0, 1) { return "one" }
        if o.v == 0, !o.iIs(0), o.iMod(1_000_000) == 0 { return "many" }
        return "other"
    }

    /// it, ca, vec, pt-PT — one: `i = 1 and v = 0`; many: `e = 0 and i != 0 and i % 1000000 = 0 and v = 0`
    private static let italian: PluralRuleSet = { o in
        if o.iIs(1), o.v == 0 { return "one" }
        if o.v == 0, !o.iIs(0), o.iMod(1_000_000) == 0 { return "many" }
        return "other"
    }

    /// es — one: `n = 1`; many: `e = 0 and i != 0 and i % 1000000 = 0 and v = 0`
    private static let spanish: PluralRuleSet = { o in
        if o.nIs(1) { return "one" }
        if o.v == 0, !o.iIs(0), o.iMod(1_000_000) == 0 { return "many" }
        return "other"
    }

    /// pt — one: `i = 0..1`; many: `e = 0 and i != 0 and i % 1000000 = 0 and v = 0`
    private static let portuguese: PluralRuleSet = { o in
        if o.iIn(0...1) { return "one" }
        if o.v == 0, !o.iIs(0), o.iMod(1_000_000) == 0 { return "many" }
        return "other"
    }

    /// ru, uk — one: `v = 0 and i % 10 = 1 and i % 100 != 11`;
    /// few: `v = 0 and i % 10 = 2..4 and i % 100 != 12..14`;
    /// many: `v = 0 and (i % 10 = 0 or i % 10 = 5..9 or i % 100 = 11..14)`
    private static let russian: PluralRuleSet = { o in
        guard o.v == 0 else { return "other" }
        if o.iMod(10) == 1, o.iMod(100) != 11 { return "one" }
        if (2...4).contains(o.iMod(10)), !(12...14).contains(o.iMod(100)) { return "few" }
        return "many"
    }

    /// pl — one: `i = 1 and v = 0`;
    /// few: `v = 0 and i % 10 = 2..4 and i % 100 != 12..14`;
    /// many: `v = 0 and (i != 1 and i % 10 = 0..1 or i % 10 = 5..9 or i % 100 = 12..14)`
    private static let polish: PluralRuleSet = { o in
        guard o.v == 0 else { return "other" }
        if o.iIs(1) { return "one" }
        if (2...4).contains(o.iMod(10)), !(12...14).contains(o.iMod(100)) { return "few" }
        return "many"
    }

    /// cs, sk — one: `i = 1 and v = 0`; few: `i = 2..4 and v = 0`; many: `v != 0`
    private static let czech: PluralRuleSet = { o in
        if o.v != 0 { return "many" }
        if o.iIs(1) { return "one" }
        if o.iIn(2...4) { return "few" }
        return "other"
    }

    /// ar — zero: `n = 0`; one: `n = 1`; two: `n = 2`;
    /// few: `n % 100 = 3..10`; many: `n % 100 = 11..99`
    private static let arabic: PluralRuleSet = { o in
        if o.nIs(0) { return "zero" }
        if o.nIs(1) { return "one" }
        if o.nIs(2) { return "two" }
        if o.nMod(100, in: 3...10) { return "few" }
        if o.nMod(100, in: 11...99) { return "many" }
        return "other"
    }

    /// he — one: `i = 1 and v = 0 or i = 0 and v != 0`; two: `i = 2 and v = 0`
    private static let hebrew: PluralRuleSet = { o in
        if (o.iIs(1) && o.v == 0) || (o.iIs(0) && o.v != 0) { return "one" }
        if o.iIs(2), o.v == 0 { return "two" }
        return "other"
    }

    /// lv, prg — zero: `n % 10 = 0 or n % 100 = 11..19 or v = 2 and f % 100 = 11..19`;
    /// one: `n % 10 = 1 and n % 100 != 11 or v = 2 and f % 10 = 1 and f % 100 != 11 or v != 2 and f % 10 = 1`
    private static let latvian: PluralRuleSet = { o in
        if o.nMod(10, is: 0) || o.nMod(100, in: 11...19)
            || (o.v == 2 && (11...19).contains(o.f % 100)) {
            return "zero"
        }
        if (o.nMod(10, is: 1) && !o.nMod(100, is: 11))
            || (o.v == 2 && o.f % 10 == 1 && o.f % 100 != 11)
            || (o.v != 2 && o.f % 10 == 1) {
            return "one"
        }
        return "other"
    }

    /// lt — one: `n % 10 = 1 and n % 100 != 11..19`;
    /// few: `n % 10 = 2..9 and n % 100 != 11..19`; many: `f != 0`
    private static let lithuanian: PluralRuleSet = { o in
        if o.nMod(10, is: 1), !o.nMod(100, in: 11...19) { return "one" }
        if o.nMod(10, in: 2...9), !o.nMod(100, in: 11...19) { return "few" }
        if o.f != 0 { return "many" }
        return "other"
    }

    /// ro, mo — one: `i = 1 and v = 0`; few: `v != 0 or n = 0 or n != 1 and n % 100 = 1..19`
    private static let romanian: PluralRuleSet = { o in
        if o.iIs(1), o.v == 0 { return "one" }
        if o.v != 0 || o.nIs(0) || (!o.nIs(1) && o.nMod(100, in: 1...19)) { return "few" }
        return "other"
    }

    /// sl — one: `v = 0 and i % 100 = 1`; two: `v = 0 and i % 100 = 2`;
    /// few: `v = 0 and i % 100 = 3..4 or v != 0`
    private static let slovenian: PluralRuleSet = { o in
        if o.v != 0 { return "few" }
        switch o.iMod(100) {
        case 1: return "one"
        case 2: return "two"
        case 3, 4: return "few"
        default: return "other"
        }
    }

    /// hr, sr, bs, sh — one: `v = 0 and i % 10 = 1 and i % 100 != 11 or f % 10 = 1 and f % 100 != 11`;
    /// few: `v = 0 and i % 10 = 2..4 and i % 100 != 12..14 or f % 10 = 2..4 and f % 100 != 12..14`
    private static let serboCroatian: PluralRuleSet = { o in
        if (o.v == 0 && o.iMod(10) == 1 && o.iMod(100) != 11)
            || (o.v != 0 && o.f % 10 == 1 && o.f % 100 != 11) {
            return "one"
        }
        if (o.v == 0 && (2...4).contains(o.iMod(10)) && !(12...14).contains(o.iMod(100)))
            || (o.v != 0 && (2...4).contains(o.f % 10) && !(12...14).contains(o.f % 100)) {
            return "few"
        }
        return "other"
    }

    /// mk — one: `v = 0 and i % 10 = 1 and i % 100 != 11 or f % 10 = 1 and f % 100 != 11`
    private static let macedonian: PluralRuleSet = { o in
        if (o.v == 0 && o.iMod(10) == 1 && o.iMod(100) != 11)
            || (o.v != 0 && o.f % 10 == 1 && o.f % 100 != 11) {
            return "one"
        }
        return "other"
    }

    /// be — one: `n % 10 = 1 and n % 100 != 11`;
    /// few: `n % 10 = 2..4 and n % 100 != 12..14`;
    /// many: `n % 10 = 0 or n % 10 = 5..9 or n % 100 = 11..14`
    private static let belarusian: PluralRuleSet = { o in
        guard o.isInt else { return "other" }
        if o.iMod(10) == 1, o.iMod(100) != 11 { return "one" }
        if (2...4).contains(o.iMod(10)), !(12...14).contains(o.iMod(100)) { return "few" }
        return "many"
    }

    /// da — one: `n = 1 or t != 0 and i = 0,1`
    private static let danish: PluralRuleSet = { o in
        o.nIs(1) || (o.f != 0 && o.iIs(0, 1)) ? "one" : "other"
    }

    /// is — one: `t = 0 and i % 10 = 1 and i % 100 != 11 or t % 10 = 1 and t % 100 != 11`
    private static let icelandic: PluralRuleSet = { o in
        if (o.f == 0 && o.iMod(10) == 1 && o.iMod(100) != 11)
            || (o.f != 0 && o.f % 10 == 1 && o.f % 100 != 11) {
            return "one"
        }
        return "other"
    }

    /// fil, tl — one: `v = 0 and i = 1,2,3 or v = 0 and i % 10 != 4,6,9 or v != 0 and f % 10 != 4,6,9`
    private static let filipino: PluralRuleSet = { o in
        if o.v == 0 {
            return o.iIs(1, 2, 3) || ![4, 6, 9].contains(o.iMod(10)) ? "one" : "other"
        }
        return ![4, 6, 9].contains(o.f % 10) ? "one" : "other"
    }

    /// hi, bn, fa, am, gu, kn, zu, … — one: `i = 0 or n = 1`
    private static let oneWhenI0orN1: PluralRuleSet = { o in
        o.iIs(0) || o.nIs(1) ? "one" : "other"
    }

    /// si — one: `n = 0,1 or i = 0 and f = 1`
    private static let sinhala: PluralRuleSet = { o in
        o.nIs(0, 1) || (o.iIs(0) && o.f == 1) ? "one" : "other"
    }

    /// ak, ln, mg, pa, ti, … — one: `n = 0..1`
    private static let oneWhenN0to1: PluralRuleSet = { o in
        o.nIn(0...1) ? "one" : "other"
    }

    /// tzm — one: `n = 0..1 or n = 11..99`
    private static let tachelhitTamazight: PluralRuleSet = { o in
        o.nIn(0...1) || o.nIn(11...99) ? "one" : "other"
    }

    /// shi — one: `i = 0 or n = 1`; few: `n = 2..10`
    private static let shilha: PluralRuleSet = { o in
        if o.iIs(0) || o.nIs(1) { return "one" }
        if o.nIn(2...10) { return "few" }
        return "other"
    }

    /// ga — one: `n = 1`; two: `n = 2`; few: `n = 3..6`; many: `n = 7..10`
    private static let irish: PluralRuleSet = { o in
        if o.nIs(1) { return "one" }
        if o.nIs(2) { return "two" }
        if o.nIn(3...6) { return "few" }
        if o.nIn(7...10) { return "many" }
        return "other"
    }

    /// gd — one: `n = 1,11`; two: `n = 2,12`; few: `n = 3..10,13..19`
    private static let scottishGaelic: PluralRuleSet = { o in
        if o.nIs(1, 11) { return "one" }
        if o.nIs(2, 12) { return "two" }
        if o.nIn(3...10) || o.nIn(13...19) { return "few" }
        return "other"
    }

    /// cy — zero: `n = 0`; one: `n = 1`; two: `n = 2`; few: `n = 3`; many: `n = 6`
    private static let welsh: PluralRuleSet = { o in
        if o.nIs(0) { return "zero" }
        if o.nIs(1) { return "one" }
        if o.nIs(2) { return "two" }
        if o.nIs(3) { return "few" }
        if o.nIs(6) { return "many" }
        return "other"
    }

    /// br — one: `n % 10 = 1 and n % 100 != 11,71,91`; two: `n % 10 = 2 and n % 100 != 12,72,92`;
    /// few: `n % 10 = 3..4,9 and n % 100 != 10..19,70..79,90..99`;
    /// many: `n != 0 and n % 1000000 = 0`
    private static let breton: PluralRuleSet = { o in
        guard o.isInt else { return "other" }
        let m10 = o.iMod(10)
        let m100 = o.iMod(100)
        if m10 == 1, ![11, 71, 91].contains(m100) { return "one" }
        if m10 == 2, ![12, 72, 92].contains(m100) { return "two" }
        if [3, 4, 9].contains(m10),
           !((10...19).contains(m100) || (70...79).contains(m100) || (90...99).contains(m100)) {
            return "few"
        }
        if !o.nIs(0), o.iMod(1_000_000) == 0 { return "many" }
        return "other"
    }

    /// mt — one: `n = 1`; two: `n = 2`; few: `n = 0 or n % 100 = 3..10`; many: `n % 100 = 11..19`
    private static let maltese: PluralRuleSet = { o in
        if o.nIs(1) { return "one" }
        if o.nIs(2) { return "two" }
        if o.nIs(0) || o.nMod(100, in: 3...10) { return "few" }
        if o.nMod(100, in: 11...19) { return "many" }
        return "other"
    }

    /// ksh — zero: `n = 0`; one: `n = 1`
    private static let colognian: PluralRuleSet = { o in
        if o.nIs(0) { return "zero" }
        if o.nIs(1) { return "one" }
        return "other"
    }

    /// lag — zero: `n = 0`; one: `i = 0,1 and n != 0`
    private static let langi: PluralRuleSet = { o in
        if o.nIs(0) { return "zero" }
        if o.iIs(0, 1) { return "one" }
        return "other"
    }

    // MARK: Language → rule set

    private static func ruleSet(for identifier: String) -> PluralRuleSet {
        let (language, region) = languageAndRegion(identifier)
        switch language {
        case "af", "an", "asa", "az", "bal", "bem", "bez", "bg", "brx", "ce", "cgg", "chr",
             "ckb", "dv", "ee", "el", "eo", "eu", "fo", "fur", "gsw", "ha", "haw", "hu",
             "jgo", "jmc", "ka", "kaj", "kcg", "kk", "kkj", "kl", "ks", "ksb", "ku", "ky",
             "lb", "lg", "mas", "mgo", "ml", "mn", "mr", "nah", "nb", "nd", "ne", "nn",
             "nnh", "no", "nr", "ny", "nyn", "om", "or", "os", "pap", "ps", "rm", "rof",
             "rwk", "saq", "sd", "sdh", "seh", "sn", "so", "sq", "ss", "ssy", "st", "syr",
             "ta", "te", "teo", "tig", "tk", "tn", "tr", "ts", "ug", "uz", "ve", "vo",
             "vun", "wae", "xh", "xog":
            return oneWhenN1
        case "ast", "de", "en", "et", "fi", "fy", "gl", "ia", "io", "ji", "lij", "nl",
             "sc", "scn", "sv", "sw", "ur", "yi":
            return oneWhenI1V0
        case "ff", "hy", "kab":
            return oneWhenI0or1
        case "fr":
            return french
        case "it", "ca", "vec":
            return italian
        case "pt":
            // CLDR keys European Portuguese separately (`pt_PT`); everything
            // else (pt, pt-BR, …) uses the `i = 0..1` rule.
            return region == "PT" ? italian : portuguese
        case "es":
            return spanish
        case "ru", "uk":
            return russian
        case "pl":
            return polish
        case "cs", "sk":
            return czech
        case "ar", "ars":
            return arabic
        case "he", "iw":
            return hebrew
        case "lv", "prg":
            return latvian
        case "lt":
            return lithuanian
        case "ro", "mo":
            return romanian
        case "sl":
            return slovenian
        case "bs", "hr", "sh", "sr":
            return serboCroatian
        case "mk":
            return macedonian
        case "be":
            return belarusian
        case "da":
            return danish
        case "is":
            return icelandic
        case "fil", "tl":
            return filipino
        case "am", "as", "bn", "doi", "fa", "gu", "hi", "kn", "pcm", "zu":
            return oneWhenI0orN1
        case "si":
            return sinhala
        case "ak", "bho", "guw", "ln", "mg", "nso", "pa", "ti", "wa":
            return oneWhenN0to1
        case "tzm":
            return tachelhitTamazight
        case "shi":
            return shilha
        case "ga":
            return irish
        case "gd":
            return scottishGaelic
        case "cy":
            return welsh
        case "br":
            return breton
        case "mt":
            return maltese
        case "ksh":
            return colognian
        case "lag":
            return langi
        default:
            // Includes the explicit "other"-only languages (ja, zh, ko, th,
            // vi, id, ms, km, lo, my, …) and any unknown language.
            return otherOnly
        }
    }

    /// Extracts the base language (lowercased) and region from a BCP-47
    /// ("en-US") or POSIX/ICU ("en_US") locale identifier.
    private static func languageAndRegion(_ identifier: String) -> (language: String, region: String?) {
        let subtags = identifier.split(whereSeparator: { $0 == "-" || $0 == "_" })
        guard let first = subtags.first else { return ("", nil) }
        // Region is the first 2-letter alpha or 3-digit subtag after the
        // language (skipping a possible 4-letter script subtag).
        for subtag in subtags.dropFirst() {
            if subtag.count == 2, subtag.allSatisfy(\.isLetter) {
                return (first.lowercased(), subtag.uppercased())
            }
            if subtag.count == 3, subtag.allSatisfy(\.isNumber) {
                return (first.lowercased(), String(subtag))
            }
        }
        return (first.lowercased(), nil)
    }
}
