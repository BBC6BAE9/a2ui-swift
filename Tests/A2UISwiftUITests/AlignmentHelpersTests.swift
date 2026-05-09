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

import A2UISwiftCore
import SwiftUI
import Testing

@testable import A2UISwiftUI

// Spec coverage: common_types.json `Align` enum (start | center | end | stretch).
//
// These tests pin the typed `Align` → SwiftUI alignment mapping, replacing
// the prior stringly-typed helper. `.stretch` and `.unknown(_)` fall through
// to the cross-axis start anchor (.leading / .top), matching pre-existing
// behavior of the string-based default branch.

@Suite("a2uiHorizontalAlignment")
struct HorizontalAlignmentMappingTests {

    @Test(".start → .leading")
    func startMapsToLeading() {
        #expect(a2uiHorizontalAlignment(.start) == .leading)
    }

    @Test(".center → .center")
    func centerMapsToCenter() {
        #expect(a2uiHorizontalAlignment(.center) == .center)
    }

    @Test(".end → .trailing")
    func endMapsToTrailing() {
        #expect(a2uiHorizontalAlignment(.end) == .trailing)
    }

    @Test(".stretch → .leading (default)")
    func stretchFallsThrough() {
        #expect(a2uiHorizontalAlignment(.stretch) == .leading)
    }

    @Test(".unknown(_) → .leading (forward-compat)")
    func unknownFallsThrough() {
        #expect(a2uiHorizontalAlignment(.unknown("future")) == .leading)
    }

    @Test("nil → .leading (default)")
    func nilFallsThrough() {
        #expect(a2uiHorizontalAlignment(nil) == .leading)
    }
}

@Suite("a2uiVerticalAlignment")
struct VerticalAlignmentMappingTests {

    @Test(".start → .top")
    func startMapsToTop() {
        #expect(a2uiVerticalAlignment(.start) == .top)
    }

    @Test(".center → .center")
    func centerMapsToCenter() {
        #expect(a2uiVerticalAlignment(.center) == .center)
    }

    @Test(".end → .bottom")
    func endMapsToBottom() {
        #expect(a2uiVerticalAlignment(.end) == .bottom)
    }

    @Test(".stretch → .top (default)")
    func stretchFallsThrough() {
        #expect(a2uiVerticalAlignment(.stretch) == .top)
    }

    @Test(".unknown(_) → .top (forward-compat)")
    func unknownFallsThrough() {
        #expect(a2uiVerticalAlignment(.unknown("future")) == .top)
    }

    @Test("nil → .top (default)")
    func nilFallsThrough() {
        #expect(a2uiVerticalAlignment(nil) == .top)
    }
}
