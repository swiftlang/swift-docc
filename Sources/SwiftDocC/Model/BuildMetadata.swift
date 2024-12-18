/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
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
    
    @available(*, deprecated, renamed: "bundleID", message: "Use 'bundleID' instead. This deprecated API will be removed after 6.2 is released")
    public var bundleIdentifier: String {
        bundleID.rawValue
    }
    
    /// The bundle identifier of the documentation bundle that DocC built.
    public let bundleID: DocumentationBundle.Identifier
    
    /// Creates a build metadata value for a documentation bundle built by DocC.
    ///
    /// - Parameters:
    ///   - bundleDisplayName: The display name of the documentation bundle.
    ///   - bundleID: The bundle identifier of the documentation bundle.
    public init(bundleDisplayName: String, bundleID: DocumentationBundle.Identifier) {
        self.bundleDisplayName = bundleDisplayName
        self.bundleID = bundleID
    }
    
    @available(*, deprecated, renamed: "init(bundleDisplayName:bundleID:)", message: "Use 'init(bundleDisplayName:bundleID:)' instead. This deprecated API will be removed after 6.2 is released")
    public init(bundleDisplayName: String, bundleIdentifier: String) {
        self.init(
            bundleDisplayName: bundleDisplayName,
            bundleID: .init(rawValue: bundleIdentifier)
        )
    }
}
