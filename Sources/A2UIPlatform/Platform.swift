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

// MARK: - Platform aliases
//
// The Apple-substrate renderer is ONE codebase compiled for two UI frameworks.
// Everything that is API-identical across UIKit and AppKit (Auto Layout anchors,
// CALayer, AVFoundation, color/font initializers) is shared verbatim. Only the
// handful of high-level controls that genuinely diverge get a `#if` shell inside
// the individual component files.
//
// These aliases give every shared file ONE name to write against.

#if canImport(UIKit) && !os(watchOS)
import UIKit

public typealias PlatformView = UIView
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
public typealias PlatformStackView = UIStackView
public typealias PlatformLayoutGuide = UILayoutGuide

#elseif canImport(AppKit)
import AppKit

public typealias PlatformView = NSView
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
public typealias PlatformStackView = NSStackView
public typealias PlatformLayoutGuide = NSLayoutGuide

#endif
