// swift-tools-version:5.6
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
                .product(name: "SymbolKit", package: "swift-docc-symbolkit"),
                .product(name: "CLMDB", package: "swift-lmdb"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SwiftDocCTests",
            dependencies: [
                .target(name: "SwiftDocC"),
                .target(name: "SwiftDocCTestUtilities"),
            ],
            resources: [
                .copy("Test Resources"),
                .copy("Test Bundles"),
                .copy("Converter/Converter Fixtures"),
                .copy("Rendering/Rendering Fixtures"),
            ],
            swiftSettings: swiftSettings
        ),
        
        // Test utility library
        .target(
            name: "SwiftDocCTestUtilities",
            dependencies: [
                .product(name: "SymbolKit", package: "swift-docc-symbolkit"),
            ],
            swiftSettings: swiftSettings
        ),

        // Command-line tool
        .executableTarget(
            name: "docc",
            dependencies: [
                .target(name: "SwiftDocCUtilities"),
            ],
            swiftSettings: swiftSettings
        ),

        // Test app for SwiftDocCUtilities
        .executableTarget(
            name: "signal-test-app",
            dependencies: [
                .target(name: "SwiftDocCUtilities"),
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

// Command-line tool library
#if os(Windows)
package.targets.append(contentsOf: [
    .target(
        name: "SwiftDocCUtilities",
        dependencies: [
            .target(name: "SwiftDocC"),
            .product(name: "ArgumentParser", package: "swift-argument-parser")
        ],
        exclude: [
            // PreviewServer requires NIO which cannot support non-POSIX platforms.
            "PreviewServer",
            "Action/Actions/PreviewAction.swift",
            "ArgumentParsing/ActionExtensions/PreviewAction+CommandInitialization.swift",
            "ArgumentParsing/Subcommands/Preview.swift",
        ],
        swiftSettings: swiftSettings
    ),
    .testTarget(
        name: "SwiftDocCUtilitiesTests",
        dependencies: [
            .target(name: "SwiftDocCUtilities"),
            .target(name: "SwiftDocC"),
            .target(name: "SwiftDocCTestUtilities"),
        ],
        exclude: [
            // PreviewServer requires NIO which cannot support non-POSIX platforms.
            "ArgumentParsing/PreviewSubcommandTests.swift",
            "PreviewActionIntegrationTests.swift",
            "PreviewServer",
        ],
        resources: [
            .copy("Test Resources"),
            .copy("Test Bundles"),
        ],
        swiftSettings: swiftSettings
    ),
])
#else
package.targets.append(contentsOf: [
    .target(
        name: "SwiftDocCUtilities",
        dependencies: [
            .target(name: "SwiftDocC"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            .product(name: "ArgumentParser", package: "swift-argument-parser")
        ],
        swiftSettings: swiftSettings
    ),
    .testTarget(
        name: "SwiftDocCUtilitiesTests",
        dependencies: [
            .target(name: "SwiftDocCUtilities"),
            .target(name: "SwiftDocC"),
            .target(name: "SwiftDocCTestUtilities"),
        ],
        resources: [
            .copy("Test Resources"),
            .copy("Test Bundles"),
        ],
        swiftSettings: swiftSettings
    ),
])
#endif

// If the `SWIFTCI_USE_LOCAL_DEPS` environment variable is set,
// we're building in the Swift.org CI system alongside other projects in the Swift toolchain and
// we can depend on local versions of our dependencies instead of fetching them remotely.
if ProcessInfo.processInfo.environment["SWIFTCI_USE_LOCAL_DEPS"] == nil {
    // Building standalone, so fetch all dependencies remotely.
    package.dependencies += [
        .package(url: "https://github.com/apple/swift-markdown.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-lmdb.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.2"),
        .package(url: "https://github.com/apple/swift-docc-symbolkit", branch: "main"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.5.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.2.0"),
    ]

#if !os(Windows)
    package.dependencies += [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.53.0"),
    ]
#endif
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
