/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A value that encapsulates metadata for a documentation catalog that DocC built.
public struct BuildMetadata: Codable {
    
    /// The current version of the build metadata schema.
    public var schemaVersion = SemanticVersion(
        major: 0,
        minor: 1,
        patch: 0
    )
    
    /// The display name of the documentation catalog that DocC built.
    public var catalogDisplayName: String
    
    @available(*, deprecated, renamed: "catalogDisplayName")
    public var bundleDisplayName: String {
        get {
            return catalogDisplayName
        }
        
        set {
            catalogDisplayName = newValue
        }
    }
    
    /// The catalog identifier of the documentation catalog that DocC built.
    public var catalogIdentifier: String
    
    @available(*, deprecated, renamed: "catalogIdentifier")
    public var bundleIdentifier: String {
        get {
            return catalogIdentifier
        }
        
        set {
            catalogIdentifier = newValue
        }
    }
    
    /// Creates a build metadata value for a documentation catalog built by DocC.
    ///
    /// - Parameters:
    ///   - catalogDisplayName: The display name of the documentation catalog.
    ///   - catalogIdentifier: The catalog identifier of the documentation catalog.
    public init(catalogDisplayName: String, catalogIdentifier: String) {
        self.catalogDisplayName = catalogDisplayName
        self.catalogIdentifier = catalogIdentifier
    }
    
    @available(*, deprecated, renamed: "init(catalogDisplayName:catalogIdentifier:)")
    public init(bundleDisplayName: String, bundleIdentifier: String) {
        self = .init(catalogDisplayName: bundleDisplayName, catalogIdentifier: bundleIdentifier)
    }
}
