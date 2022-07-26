// swift-tools-version: 5.5
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackageDescription

let package = Package(
    name: "benchmark",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "benchmark",
            targets: ["benchmark"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.0.3")),
        .package(name: "swift-docc", path: "../../"),
    ],
    targets: [
        .executableTarget(
            name: "benchmark",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftDocC", package: "swift-docc"),
            ]),
        .testTarget(
            name: "benchmarkTests",
            dependencies: ["benchmark"]),
    ]
)
