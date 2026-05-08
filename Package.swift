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
            name: "Primitives",
            targets: ["Primitives"]
        ),
        .library(
            name: "v_08",
            targets: ["v_08"]
        ),
        .library(
            name: "A2UISwiftCore",
            targets: ["A2UISwiftCore"]
        ),
        .library(
            name: "A2UISwiftUI",
            targets: ["A2UISwiftUI"]
        ),
        .library(
            name: "A2UIUIKit",
            targets: ["A2UIUIKit"]
        ),
        .library(
            name: "A2UIAppKit",
            targets: ["A2UIAppKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/objecthub/swift-dynamicjson.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "Primitives",
            path: "Sources/Primitives"
        ),
        .target(
            name: "v_08",
            path: "Sources/v_08"
        ),
        .target(
            name: "A2UISwiftCore",
            dependencies: [.product(name: "DynamicJSON", package: "swift-dynamicjson")],
            path: "Sources/A2UISwiftCore",
            resources: [.copy("Resources/v0_9")]
        ),
        .target(
            name: "A2UISwiftUI",
            dependencies: ["A2UISwiftCore"],
            path: "Sources/A2UISwiftUI"
        ),
        .target(
            name: "A2UIUIKit",
            dependencies: ["A2UISwiftCore"],
            path: "Sources/A2UIUIKit"
        ),
        .target(
            name: "A2UIAppKit",
            dependencies: ["A2UISwiftCore"],
            path: "Sources/A2UIAppKit"
        ),
        .testTarget(
            name: "PrimitivesTests",
            dependencies: ["Primitives"],
            path: "Tests/PrimitivesTests"
        ),
        .testTarget(
            name: "v_08Tests",
            dependencies: ["v_08"],
            path: "Tests/v_08Tests",
            resources: [.copy("TestData")]
        ),
        .testTarget(
            name: "A2UISwiftCoreTests",
            dependencies: ["A2UISwiftCore"],
            path: "Tests/A2UISwiftCoreTests"
        ),
        .testTarget(
            name: "A2UISwiftUITests",
            dependencies: ["A2UISwiftCore", "A2UISwiftUI"],
            path: "Tests/A2UISwiftUITests"
        ),
        .testTarget(
            name: "A2UIUIKitTests",
            dependencies: ["A2UISwiftCore", "A2UIUIKit"],
            path: "Tests/A2UIUIKitTests"
        ),
        .testTarget(
            name: "A2UIAppKitTests",
            dependencies: ["A2UISwiftCore", "A2UIAppKit"],
            path: "Tests/A2UIAppKitTests"
        ),
    ]
)
