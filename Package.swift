// swift-tools-version: 5.9

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

import PackageDescription

let package = Package(
    name: "A2UI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "A2UI",
            targets: ["A2UI"]
        ),
    ],
    targets: [
        .target(
            name: "A2UI",
            path: "Sources/A2UI"
        ),
        .testTarget(
            name: "A2UITests",
            dependencies: ["A2UI"],
            path: "Tests/A2UITests",
            resources: [.copy("TestData")]
        ),
    ]
)
