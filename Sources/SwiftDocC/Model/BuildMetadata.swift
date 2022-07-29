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
    
    /// The complete list of versions that are available for this documentation archive.
    public var versions: [ArchiveVersion]?
    
    /// Creates a build metadata value for a documentation bundle built by DocC.
    ///
    /// - Parameters:
    ///   - bundleDisplayName: The display name of the documentation bundle.
    ///   - bundleIdentifier: The bundle identifier of the documentation bundle.
    ///   - currentVersion: The current version for the archive the documentation bundle will be converted into
    ///   - previousBuildMetadata: The URL to a previous DocC archive's buildMetadata file.
    public init(bundleDisplayName: String, bundleIdentifier: String, currentVersion: ArchiveVersion? = nil, previousBuildMetadata: URL? = nil) {
        self.bundleDisplayName = bundleDisplayName
        self.bundleIdentifier = bundleIdentifier
        
        // Try to get the previous archive's BuildMetadata and grab its versions property.
        
        if let previousBuildMetadataURL = previousBuildMetadata, let previousMetadataData = try? Data(contentsOf: previousBuildMetadataURL) {
            let previousMetadata = try? JSONDecoder().decode(BuildMetadata.self, from: previousMetadataData)
            self.versions = previousMetadata?.versions
        }
        
        if let currentVersion = currentVersion {
            if self.versions == nil { self.versions = [] }
            self.versions?.append(currentVersion)
        }
    }
}
