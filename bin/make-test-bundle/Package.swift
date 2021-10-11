// swift-tools-version:5.3
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackageDescription

let package = Package(
    name: "make-test-bundle",
    platforms: [.macOS(.v10_15)],
    dependencies: [],
    targets: [
        .target(
            name: "make-test-bundle",
            path: "Sources/make-test-bundle",
            resources: [
                .copy("File/image@2x.png")
            ]
        )
    ]
)
