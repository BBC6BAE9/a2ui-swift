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

// MARK: - Icon name → SF Symbol
//
// Mirrors SwiftUI A2UIStyle.IconName.defaultSystemName. Maps the spec's material
// icon names to SF Symbols; unknown names pass through (they may already be an
// SF Symbol), falling back to a placeholder glyph at the call site.

private let a2ui_iconMap: [String: String] = [
    "accountCircle": "person.circle", "add": "plus", "arrowBack": "chevron.left",
    "arrowForward": "chevron.right", "attachFile": "paperclip", "calendarToday": "calendar",
    "call": "phone", "camera": "camera", "check": "checkmark", "close": "xmark",
    "delete": "trash", "download": "arrow.down.circle", "edit": "pencil",
    "event": "calendar.badge.clock", "error": "exclamationmark.circle", "fastForward": "forward",
    "favorite": "heart.fill", "favoriteOff": "heart", "folder": "folder",
    "help": "questionmark.circle", "home": "house", "info": "info.circle",
    "locationOn": "mappin.and.ellipse", "lock": "lock", "lockOpen": "lock.open",
    "mail": "envelope", "menu": "line.3.horizontal", "moreVert": "ellipsis",
    "moreHoriz": "ellipsis", "notificationsOff": "bell.slash", "notifications": "bell",
    "pause": "pause", "payment": "creditcard", "person": "person", "phone": "phone",
    "photo": "photo", "play": "play", "print": "printer", "refresh": "arrow.clockwise",
    "rewind": "backward", "search": "magnifyingglass", "send": "paperplane",
    "settings": "gearshape", "share": "square.and.arrow.up", "shoppingCart": "cart",
    "skipNext": "forward.end", "skipPrevious": "backward.end", "star": "star.fill",
    "starHalf": "star.leadinghalf.filled", "starOff": "star", "stop": "stop",
    "upload": "arrow.up.circle", "visibility": "eye", "visibilityOff": "eye.slash",
    "volumeDown": "speaker.wave.1", "volumeMute": "speaker", "volumeOff": "speaker.slash",
    "volumeUp": "speaker.wave.3", "warning": "exclamationmark.triangle",
]

/// Resolves a spec icon name to an SF Symbol name. Known material names map;
/// unknown names pass through (caller falls back to a placeholder if invalid).
func a2ui_sfSymbolName(for name: String) -> String {
    a2ui_iconMap[name] ?? name
}

#endif
