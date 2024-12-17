/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension FileManagerProtocol {
    /// Returns a sequence of all the files in the directory structure from the starting point.
    /// - Parameters:
    ///   - startingPoint: The file or directory that's the top of the directory structure that the file manager traverses.
    ///   - options: Options for how the file manager enumerates the contents of directories. Defaults to `.skipsHiddenFiles`.
    /// - Returns: A sequence of the files in the directory structure.
    package func recursiveFiles(startingPoint: URL, options: FileManager.DirectoryEnumerationOptions = .skipsHiddenFiles) -> IteratorSequence<_FilesIterator> {
        IteratorSequence(_FilesIterator(fileManager: self, startingPoint: startingPoint, options: options))
    }
}

// FIXME: This should be private and `FileManagerProtocol.recursiveFiles(startingPoint:options:)` should return `some Sequence<ULR>`
// but because of https://github.com/swiftlang/swift/issues/77955 it needs to be exposed as an explicit type to avoid a SIL Validation error in the Swift compiler.

/// An iterator that traverses the directory structure and returns the files in breadth-first order.
package struct _FilesIterator: IteratorProtocol {
    /// The file manager that the iterator uses to traverse the directory structure.
    private var fileManager: any FileManagerProtocol // This can't be a generic because of https://github.com/swiftlang/swift/issues/77955
    private var options: FileManager.DirectoryEnumerationOptions
    
    private var foundFiles: [URL]
    private var foundDirectories: [URL]
    
    fileprivate init(fileManager: any FileManagerProtocol, startingPoint: URL, options: FileManager.DirectoryEnumerationOptions) {
        self.fileManager = fileManager
        self.options = options
        
        // Check if the starting point is a file or a directory.
        if fileManager.directoryExists(atPath: startingPoint.path) {
            foundFiles       = []
            foundDirectories = [startingPoint]
        } else {
            foundFiles       = [startingPoint]
            foundDirectories = []
        }
    }
    
    package mutating func next() -> URL? {
        // If the iterator has already found some files, return those first
        if !foundFiles.isEmpty {
            return foundFiles.removeFirst()
        }
        
        // Otherwise, check the next found directory and add its contents
        guard !foundDirectories.isEmpty else {
            // Traversed the entire directory structure
            return nil
        }
        
        let directory = foundDirectories.removeFirst()
        guard let (newFiles, newDirectories) = try? fileManager.contentsOfDirectory(at: directory, options: options) else {
            // The iterator protocol doesn't have a mechanism for raising errors. If an error occurs we
            return nil
        }
        
        foundFiles.append(contentsOf: newFiles)
        foundDirectories.append(contentsOf: newDirectories)
        
        // Iterate again after adding new found files and directories.
        // This enables the iterator do recurse multiple layers of directories until it finds a file.
        return next()
    }
}
