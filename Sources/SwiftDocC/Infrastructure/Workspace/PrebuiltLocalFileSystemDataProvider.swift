/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A data provider that provides existing in-memory documentation catalogs with files on the local filesystem.
public struct PrebuiltLocalFileSystemDataProvider: DocumentationWorkspaceDataProvider {
    public var identifier: String = UUID().uuidString
    
    private var _catalogs: [DocumentationCatalog]
    public func catalogs(options: CatalogDiscoveryOptions) throws -> [DocumentationCatalog] {
        // Ignore the catalog discovery options, these catalogs are already built.
        return _catalogs
    }
    
    @available(*, deprecated, renamed: "bundles(options:)")
    public func bundles(options: CatalogDiscoveryOptions) throws -> [DocumentationCatalog] {
        return try catalogs(options: options)
    }
    
    /// Creates a new provider to provide the given documentation catalogs.
    /// - Parameter catalogs: The existing documentation catalogs for this provider to provide.
    public init(catalogs: [DocumentationCatalog]) {
        _catalogs = catalogs
    }
    
    @available(*, deprecated, renamed: "init(catalogs:)")
    public init(bundles: [DocumentationCatalog]) {
        self = .init(catalogs: bundles)
    }

    public func contentsOfURL(_ url: URL) throws -> Data {
        precondition(url.isFileURL, "Unexpected non-file url '\(url)'.")
        return try Data(contentsOf: url)
    }
}

