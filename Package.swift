// swift-tools-version:6.0
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackageDescription
import class Foundation.ProcessInfo

let swiftSettings: [SwiftSetting] = [
    .unsafeFlags(["-Xfrontend", "-warn-long-expression-type-checking=1000"], .when(configuration: .debug)),
    
    .swiftLanguageMode(.v5),
    
    .enableUpcomingFeature("ConciseMagicFile"), // SE-0274: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0274-magic-file.md
    .enableUpcomingFeature("ExistentialAny"), // SE-0335: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0335-existential-any.md
    .enableUpcomingFeature("InternalImportsByDefault"), // SE-0409: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md
]

let package = Package(
    name: "SwiftDocC",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SwiftDocC",
            targets: ["SwiftDocC"]
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
                .target(name: "Common"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "SymbolKit", package: "swift-docc-symbolkit"),
                .product(name: "CLMDB", package: "swift-lmdb"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            exclude: ["CMakeLists.txt"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SwiftDocCTests",
            dependencies: [
                .target(name: "SwiftDocC"),
                .target(name: "Common"),
                .target(name: "TestUtilities"),
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
            name: "CommandLine",
            dependencies: [
                .target(name: "SwiftDocC"),
                .target(name: "Common"),
                .product(name: "NIOHTTP1", package: "swift-nio", condition: .when(platforms: [.macOS, .iOS, .linux, .android])),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            exclude: ["CMakeLists.txt"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CommandLineTests",
            dependencies: [
                .target(name: "CommandLine"),
                .target(name: "SwiftDocC"),
                .target(name: "Common"),
                .target(name: "TestUtilities"),
            ],
            resources: [
                .copy("Test Resources"),
                .copy("Test Bundles"),
            ],
            swiftSettings: swiftSettings
        ),
        
        // Test utility library
        .target(
            name: "TestUtilities",
            dependencies: [
                .target(name: "SwiftDocC"),
                .target(name: "Common"),
                .product(name: "SymbolKit", package: "swift-docc-symbolkit"),
            ],
            swiftSettings: swiftSettings
        ),

        // Command-line tool
        .executableTarget(
            name: "docc",
            dependencies: [
                .target(name: "CommandLine"),
            ],
            exclude: ["CMakeLists.txt"],
            swiftSettings: swiftSettings
        ),
        
        // A few common types and core functionality that's useable by all other targets.
        .target(
            name: "Common",
            dependencies: [
                // This target shouldn't have any local dependencies so that all other targets can depend on it.
                // We can add dependencies on SymbolKit and Markdown here but they're not needed yet.
            ],
            swiftSettings: swiftSettings // FIXME: Use `[.swiftLanguageMode(.v6)]` here
        ),
        
        .testTarget(
            name: "CommonTests",
            dependencies: [
                .target(name: "Common"),
                .target(name: "TestUtilities"),
            ],
            swiftSettings: swiftSettings // FIXME: Use `[.swiftLanguageMode(.v6)]` here
        ),

        // Test app for CommandLine
        .executableTarget(
            name: "signal-test-app",
            dependencies: [
                .target(name: "CommandLine"),
            ],
            path: "Tests/signal-test-app",
            swiftSettings: swiftSettings
        ),

        .executableTarget(
            name: "generate-symbol-graph",
            dependencies: [
                .target(name: "SwiftDocC"),
                .product(name: "SymbolKit", package: "swift-docc-symbolkit"),
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
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.53.0"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main"),
        .package(url: "https://github.com/swiftlang/swift-lmdb.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.2"),
        .package(url: "https://github.com/swiftlang/swift-docc-symbolkit.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.2.0"),
    ]
} else {
    // Building in the Swift.org CI system, so rely on local versions of dependencies.
    package.dependencies += [
        .package(path: "../swift-nio"),
        .package(path: "../swift-markdown"),
        .package(path: "../swift-lmdb"),
        .package(path: "../swift-argument-parser"),
        .package(path: "../swift-docc-symbolkit"),
        .package(path: "../swift-crypto"),
    ]
}
