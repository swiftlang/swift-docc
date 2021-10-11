/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that vends a tree of virtual filesystem objects.
public protocol FileSystemProvider {
    /// The organization of the files that this provider provides.
    var fileSystem: FSNode { get }
}

/// An element in a virtual filesystem.
public enum FSNode {
    /// A file in a filesystem.
    case file(File)
    /// A directory in a filesystem.
    case directory(Directory)
    
    /// A file in a virtual file system
    public struct File {
        /// The URL to this file.
        public var url: URL
        
        /// Creates a new virtual file with a given URL
        /// - Parameter url: The URL to this file.
        public init(url: URL) {
            self.url = url
        }
    }
    
    /// A directory in a virtual file system.
    public struct Directory {
        /// The URL to this directory.
        public var url: URL
        /// The contents of this directory.
        public var children: [FSNode]
        
        /// Creates a new virtual directory with a given URL and contents.
        /// - Parameters:
        ///   - url: The URL to this directory.
        ///   - children: The contents of this directory.
        public init(url: URL, children: [FSNode]) {
            self.url = url
            self.children = children
        }
    }
    
    /// The URL for the node in the filesystem.
    public var url: URL {
        switch self {
        case .file(let file):
            return file.url
        case .directory(let directory):
            return directory.url
        }
    }
}
