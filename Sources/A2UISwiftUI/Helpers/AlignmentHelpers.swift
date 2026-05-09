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
import A2UISwiftCore

/// Maps spec `Align` (`start | center | end | stretch`) to a SwiftUI `HorizontalAlignment`.
///
/// `.stretch` and `.unknown(_)` fall through to the spec-default cross-axis
/// start-anchor (`.leading`), matching the pre-existing string-based behavior.
func a2uiHorizontalAlignment(_ align: Align?) -> HorizontalAlignment {
    switch align {
    case .start: return .leading
    case .center: return .center
    case .end: return .trailing
    default: return .leading
    }
}

/// Maps spec `Align` (`start | center | end | stretch`) to a SwiftUI `VerticalAlignment`.
///
/// `.stretch` and `.unknown(_)` fall through to the spec-default cross-axis
/// start-anchor (`.top`), matching the pre-existing string-based behavior.
func a2uiVerticalAlignment(_ align: Align?) -> VerticalAlignment {
    switch align {
    case .start: return .top
    case .center: return .center
    case .end: return .bottom
    default: return .top
    }
}
