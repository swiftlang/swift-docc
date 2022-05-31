/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A read-write file manager.
///
/// A file-system manager is a type that's central to *managing* files on
/// a file-system, it performs actions like creating new files, copying, renaming
/// and deleting files, and organizing them in directories.
///
/// The Cocoa `FileManager` type is the default implementation of that protocol
/// that manages files stored on disk.
///
/// Should you need a file system with a different storage, create your own
/// protocol implementations to manage files in memory,
/// on a network, in a database, or elsewhere.
protocol FileManagerProtocol {
    
    /// Returns the data content of a file at the given path, if it exists.
    func contents(atPath: String) -> Data?
    /// Compares the contents of two files at the given paths.
    func contentsEqual(atPath: String, andPath: String) -> Bool

    /// The *current* directory path.
    var currentDirectoryPath: String { get }
    
    /// Returns `true` if a file or a directory exists at the given path.
    func fileExists(atPath: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool
    /// Returns `true` if a directory exists at the given path.
    func directoryExists(atPath: String) -> Bool
    /// Returns `true` if a file exists at the given path.
    func fileExists(atPath: String) -> Bool
    /// Copies a file from one location on the file-system to another.
    func copyItem(at: URL, to: URL) throws
    /// Moves a file from one location on the file-system to another.
    func moveItem(at: URL, to: URL) throws
    /// Creates a new file folder at the given location.
    func createDirectory(at: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey : Any]?) throws
    /// Removes a file from the given location.
    func removeItem(at: URL) throws
    /// Returns a list of items in a directory
    func contentsOfDirectory(atPath path: String) throws -> [String]
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL]

    /// Creates a file with the specified `contents` at the specified location.
    ///
    /// - Parameters:
    ///   - at: The location to create the file
    ///   - contents: The data to write to the file.
    ///
    /// - Note: This method doesn't exist on ``FileManager``.
    ///         There is a similar looking method but it doesn't provide information about potential errors.
    ///
    /// - Throws: If the file couldn't be created with the specified contents.
    func createFile(at: URL, contents: Data) throws
    
    /// Creates a file with the given contents at the given url with the specified
    /// writing options.
    ///
    /// - Parameters:
    ///   - at: The location to create the file
    ///   - contents: The data to write to the file.
    ///   - options: Options for writing the data. Provide `nil` to use the default
    ///              writing options of the file manager.
    func createFile(at location: URL, contents: Data, options writingOptions: NSData.WritingOptions?) throws
}

extension FileManagerProtocol {
    /// Returns a Boolean value that indicates whether a directory exists at a specified path.
    func directoryExists(atPath path: String) -> Bool {
        var isDirectory = ObjCBool(booleanLiteral: false)
        let fileExistsAtPath = fileExists(atPath: path, isDirectory: &isDirectory)
        return fileExistsAtPath && isDirectory.boolValue
    }
}

/// Add compliance to `FileManagerProtocol` to `FileManager`,
/// most of the methods are already implemented in Foundation.
extension FileManager: FileManagerProtocol {
    
    // This method doesn't exist on `FileManager`. There is a similar looking method but it doesn't provide information about potential errors.
    func createFile(at location: URL, contents: Data) throws {
        try contents.write(to: location, options: .atomic)
    }
    
    func createFile(at location: URL, contents: Data, options writingOptions: NSData.WritingOptions?) throws {
        if let writingOptions = writingOptions {
            try contents.write(to: location, options: writingOptions)
        } else {
            try contents.write(to: location)
        }
    }
}
