// swift-tools-version:5.5
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackageDescription
import class Foundation.ProcessInfo

let swiftSettings: [SwiftSetting] = [
    .unsafeFlags(["-Xfrontend", "-warn-long-expression-type-checking=1000"], .when(configuration: .debug)),
]

let package = Package(
    name: "SwiftDocC",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "SwiftDocC",
            targets: ["SwiftDocC"]
        ),
        .library(
            name: "SwiftDocCUtilities",
            targets: ["SwiftDocCUtilities"]
        ),
        .executable(
            name: "docc",
            targets: ["docc"]
        )
    ],
    targets: [
        // SwiftDocC library
        .target(
            name: "SwiftDocC",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                "SymbolKit",
                "CLMDB",
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SwiftDocCTests",
            dependencies: [
                "SwiftDocC",
                "SwiftDocCTestUtilities",
            ],
            resources: [
                .copy("Test Resources"),
                .copy("Test Bundles"),
                .copy("Converter/Converter Fixtures"),
                .copy("Rendering/Rendering Fixtures"),
            ],
            swiftSettings: swiftSettings
        ),
        
        // Command-line tool library
        .target(
            name: "SwiftDocCUtilities",
            dependencies: [
                "SwiftDocC",
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SwiftDocCUtilitiesTests",
            dependencies: [
                "SwiftDocCUtilities",
                "SwiftDocC",
                "SwiftDocCTestUtilities",
            ],
            resources: [
                .copy("Test Resources"),
                .copy("Test Bundles"),
            ],
            swiftSettings: swiftSettings
        ),
        // Test utility library
        .target(
            name: "SwiftDocCTestUtilities",
            dependencies: [
                "SymbolKit"
            ],
            swiftSettings: swiftSettings
        ),

        // Command-line tool
        .executableTarget(
            name: "docc",
            dependencies: [
                "SwiftDocCUtilities",
            ],
            swiftSettings: swiftSettings
        ),

        // Test app for SwiftDocCUtilities
        .executableTarget(
            name: "signal-test-app",
            dependencies: [
                "SwiftDocCUtilities",
            ],
            path: "Tests/signal-test-app",
            swiftSettings: swiftSettings
        ),

        .executableTarget(
            name: "generate-symbol-graph",
            dependencies: [
                "SwiftDocC",
                "SymbolKit",
            ],
            swiftSettings: swiftSettings
        ),
        
    ]
)

// If the `SWIFTCI_USE_LOCAL_DEPS` environment variable is set,
// we're building in the Swift.org CI system alongside other projects in the Swift toolchain and
// we can depend on local versions of our dependencies instead of fetching them remotely.
if ProcessInfo.processInfo.environment["SWIFTCI_USE_LOCAL_DEPS"] == nil {
    // Building standalone, so fetch all dependencies remotely.
    package.dependencies += [
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMinor(from: "2.31.2")),
        .package(name: "swift-markdown", url: "https://github.com/apple/swift-markdown.git", .branch("release/5.9")),
        .package(name: "CLMDB", url: "https://github.com/apple/swift-lmdb.git", .branch("release/5.9")),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.0.1")),
        .package(name: "SymbolKit", url: "https://github.com/apple/swift-docc-symbolkit", .branch("release/5.9")),
        .package(url: "https://github.com/apple/swift-crypto.git", .upToNextMinor(from: "1.1.2")),
    ]
    
    // SwiftPM command plugins are only supported by Swift version 5.6 and later.
    #if swift(>=5.6)
    package.dependencies += [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ]
    #endif
} else {
    // Building in the Swift.org CI system, so rely on local versions of dependencies.
    package.dependencies += [
        .package(path: "../swift-nio"),
        .package(path: "../swift-markdown"),
        .package(name: "CLMDB", path: "../swift-lmdb"),
        .package(path: "../swift-argument-parser"),
        .package(name: "SymbolKit", path: "../swift-docc-symbolkit"),
        .package(path: "../swift-crypto"),
    ]
}
