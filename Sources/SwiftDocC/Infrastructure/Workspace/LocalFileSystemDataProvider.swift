/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that provides documentation bundles that it discovers by traversing the local file system.
public struct LocalFileSystemDataProvider: DocumentationWorkspaceDataProvider, FileSystemProvider {
    public var identifier: String = UUID().uuidString
    
    /// The location that this provider searches for documentation bundles in.
    public var rootURL: URL
    
    public var fileSystem: FSNode
    
    /// Creates a new provider that recursively traverses the content of the given root URL to discover documentation bundles.
    /// - Parameter rootURL: The location that this provider searches for documentation bundles in.
    public init(rootURL: URL) throws {
        self.rootURL = rootURL
        fileSystem = try LocalFileSystemDataProvider.buildTree(root: rootURL)
    }
    
    /// Builds a virtual file system hierarchy from the contents of a root URL in the local file system.
    /// - Parameter root: The location from which to descend to build the virtual file system.
    /// - Returns: A virtual file system that describe the file and directory structure within the given URL.
    private static func buildTree(root: URL) throws -> FSNode {
        var children: [FSNode] = []
        let childURLs = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [URLResourceKey.isDirectoryKey], options: .skipsHiddenFiles)
        
        for url in childURLs {
            if FileManager.default.directoryExists(atPath: url.path) {
                children.append(try buildTree(root: url))
            } else {
                children.append(FSNode.file(FSNode.File(url: url)))
            }
        }
        return FSNode.directory(FSNode.Directory(url: root, children: children))
    }

    public func contentsOfURL(_ url: URL) throws -> Data {
        precondition(url.isFileURL, "Unexpected non-file url '\(url)'.")
        return try Data(contentsOf: url)
    }
}
