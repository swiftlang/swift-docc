/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A data provider that provides existing in-memory documentation bundles with files on the local filesystem.
public struct PrebuiltLocalFileSystemDataProvider: DocumentationWorkspaceDataProvider {
    public var identifier: String = UUID().uuidString
    
    private var _bundles: [DocumentationBundle]
    public func bundles(options: BundleDiscoveryOptions) throws -> [DocumentationBundle] {
        // Ignore the bundle discovery options, these bundles are already built.
        return _bundles
    }
    
    /// Creates a new provider to provide the given documentation bundles.
    /// - Parameter bundles: The existing documentation bundles for this provider to provide.
    public init(bundles: [DocumentationBundle]) {
        _bundles = bundles
    }

    public func contentsOfURL(_ url: URL) throws -> Data {
        precondition(url.isFileURL, "Unexpected non-file url '\(url)'.")
        return try Data(contentsOf: url)
    }
}

