/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A value that encapsulates metadata for a documentation bundle that DocC built.
public struct BuildMetadata: Codable {
    
    /// The current version of the build metadata schema.
    public var schemaVersion = SemanticVersion(
        major: 0,
        minor: 1,
        patch: 0
    )
    
    /// The display name of the documentation bundle that DocC built.
    public var bundleDisplayName: String
    
    /// The bundle identifier of the documentation bundle that DocC built.
    public var bundleIdentifier: String
    
    /// Creates a build metadata value for a documentation bundle built by DocC.
    ///
    /// - Parameters:
    ///   - bundleDisplayName: The display name of the documentation bundle.
    ///   - bundleIdentifier: The bundle identifier of the documentation bundle.
    public init(bundleDisplayName: String, bundleIdentifier: String) {
        self.bundleDisplayName = bundleDisplayName
        self.bundleIdentifier = bundleIdentifier
    }
}
