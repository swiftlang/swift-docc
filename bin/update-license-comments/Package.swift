// swift-tools-version: 6.1
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackageDescription

let package = Package(
    name: "update-license-for-modified-files",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "update-license-for-modified-files"
        ),
    ]
)
