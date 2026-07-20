/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation

/// A read-only file manager.
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
public protocol ReadOnlyFileManagerProtocol: DataProvider, Sendable {

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
    func copyItem(at: URL, to: URL, on: any FileManagerProtocol) throws
    /// Returns a list of items in a directory
    func contentsOfDirectory(atPath path: String) throws -> [String]
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL]

    /// Returns the data content of a file at the given URL.
    ///
    /// - Parameters:
    ///   - url: The location to create the file
    ///
    /// - Note: This method doesn't exist on ``FileManager``.
    ///         There is a similar looking method but it doesn't provide information about potential errors.
    ///
    /// - Throws: If the file couldn't be read.
    func contents(of url: URL) throws -> Data

    /// Performs a shallow search of the specified directory and returns the file and directory URLs for the contained items.
    ///
    /// - Parameters:
    ///   - url: The URL for the directory whose contents to enumerate.
    ///   - mark: Options for the enumeration. Because this method performs only shallow enumerations, the only supported option is `skipsHiddenFiles`.
    /// - Returns: The URLs of each file and directory that's contained in `url`.
    func contentsOfDirectory(at url: URL, options mask: FileManager.DirectoryEnumerationOptions) throws -> (files: [URL], directories: [URL])

    /// Calculates the total size of the files in the specified directory.
    ///
    /// - Parameters:
    ///   - url: The URL for the directory to compute the size of.
    /// - Returns: The total size, in bytes, of the specified directory and its contents.
    func sizeOfDirectory(at url: URL, options mask: FileManager.DirectoryEnumerationOptions) throws -> Int64

}

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
public protocol FileManagerProtocol: ReadOnlyFileManagerProtocol {

    /// Removes an item from the filesystem.
    func removeItem(at: URL) throws
    /// Copies a file from one location on the file-system to another.
    func _copyItem(at: URL, to: URL) throws // Use a different name than FileManager to work around https://github.com/swiftlang/swift-foundation/issues/1125
    /// Moves a file from one location on the file-system to another.
    func moveItem(at: URL, to: URL, on: any FileManagerProtocol) throws
    /// Moves a file from one location on the file-system to another.
    func moveItem(at: URL, to: URL) throws
    /// Returns a list of items in a directory
    func contentsOfDirectory(atPath path: String) throws -> [String]
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL]
    
    /// Returns a unique temporary directory.
    ///
    /// Each call to this function will return a new temporary directory.
    func uniqueTemporaryDirectory() -> URL // Because we shadow 'FileManager.temporaryDirectory' in our tests, we can't also use 'temporaryDirectory' in FileManagerProtocol
    
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

    /// Creates a directory at the given url with the specified attributes.
    ///
    /// - Parameters:
    ///   - at: The location to create the directory
    ///   - withIntermediateDirectories: If `true`, create any parent directories
    ///         that do not currently exist
    ///   - attributes: Attributes to set on the newly created directory
    ///
    /// - Throws: If the directory couldn't be created.
    func createDirectory(at: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey: Any]?) throws
}

extension ReadOnlyFileManagerProtocol {

    public func contentsEqual(atPath path1: String, andPath path2: String) -> Bool {
        guard let content1 = contents(atPath: path1),
              let content2 = contents(atPath: path2) else {
            return false
        }

        return content1 == content2
    }

    /// Returns a Boolean value that indicates whether a directory exists at a specified path.
    public func directoryExists(atPath path: String) -> Bool {
        var isDirectory = ObjCBool(booleanLiteral: false)
        let fileExistsAtPath = fileExists(atPath: path, isDirectory: &isDirectory)
        return fileExistsAtPath && isDirectory.boolValue
    }

    public func copyItem(at source: URL, to destination: URL, on otherFileManager: any FileManagerProtocol) throws {
        if directoryExists(atPath: source.path) {
            if destination.path != "/" {
                if otherFileManager.directoryExists(atPath: destination.path) {
                    try otherFileManager.removeItem(at: destination)
                }
                try otherFileManager.createDirectory(at: destination, withIntermediateDirectories: false, attributes: [:])
            }
            for item in try contentsOfDirectory(at: source, includingPropertiesForKeys: [], options: []) {
                if let relativeItem = item.relative(to: source) {
                    let destinationItem = destination.appendingPathComponent(relativeItem.path)
                    try copyItem(at: item, to: destinationItem, on: otherFileManager)
                }
            }
        } else {
            let data = try contents(of: source)
            try otherFileManager.createFile(at: destination, contents: data)
        }

    }

    public func contentsOfDirectory(at url: URL, options mask: FileManager.DirectoryEnumerationOptions) throws -> (files: [URL], directories: [URL]) {
        var allContents = try contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)

        let partitionIndex = try allContents.partition {
            try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        }
        return (
            files:       Array( allContents[..<partitionIndex] ),
            directories: Array( allContents[partitionIndex...] )
        )
    }

}

extension FileManagerProtocol {

    public func moveItem(at source: URL, to destination: URL, on otherFileManager: any FileManagerProtocol) throws {
        try self.copyItem(at: source, to: destination, on: otherFileManager)
        try self.removeItem(at: source)
    }

}

/// Add compliance to `FileManagerProtocol` to `FileManager`,
/// most of the methods are already implemented in Foundation.
extension FileManager: FileManagerProtocol {
    // This method doesn't exist on `FileManager`. There is a similar looking method but it doesn't provide information about potential errors.
    public func contents(of url: URL) throws -> Data {
        return try Data(contentsOf: url)
    }
    
    // This method doesn't exist on `FileManager`. There is a similar looking method but it doesn't provide information about potential errors.
    public func createFile(at location: URL, contents: Data) throws {
        try contents.write(to: location, options: .atomic)
    }
    
    public func createFile(at location: URL, contents: Data, options writingOptions: NSData.WritingOptions?) throws {
        if let writingOptions {
            try contents.write(to: location, options: writingOptions)
        } else {
            try contents.write(to: location)
        }
    }
    
    // Because we shadow 'FileManager.temporaryDirectory' in our tests, we can't also use 'temporaryDirectory' in FileManagerProtocol/
    public func uniqueTemporaryDirectory() -> URL {
        temporaryDirectory.appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
    }

    public func _copyItem(at source: URL, to destination: URL) throws {
        // Call `NSFileManager/copyItem(at:to:)` and catch the error to workaround https://github.com/swiftlang/swift-foundation/issues/1125
        do {
            try copyItem(at: source, to: destination)
        } catch let error as CocoaError {
            // In Swift 6 on Linux, `FileManager/copyItem(at:to:)` raises an error _after_ successfully copying the files when it's moving over file attributes from the source to the destination.
            // To workaround this issue, we check if the destination exists and the error wasn't that the destination _already_ existed.
            if error.code != CocoaError.Code.fileWriteFileExists,
               fileExists(atPath: destination.path)
            {
                // The destination exists, but the copy may be incomplete if the error occurred mid-copy
                // (e.g., when copying a directory and fchown fails on the first child item).
                // For directory copies, verify completeness and copy any missing items individually.
                if directoryExists(atPath: source.path) {
                    try _copyMissingChildren(from: source, to: destination)
                }
                // Ignore this error.
                // The consequence is that the copied item may have some different attributes (creation date, owner, etc.) compared to the source.
                // These attributes aren't critical for copying input files over to the output documentation archive.
                return
            }

            // Otherwise, if this was any other error or if the destination file doesn't exist after calling `FileManager/copyItem(at:to:)`, re-throw the error to the caller.
            throw error
        }
    }

    /// Copies any children of `source` that are missing from `destination`, recursively.
    ///
    /// This handles the case where `copyItem(at:to:)` fails mid-copy when copying a directory,
    /// leaving some children uncopied. Each missing child is copied individually so that a
    /// per-file `fchown` failure doesn't prevent copying the remaining items.
    private func _copyMissingChildren(from source: URL, to destination: URL) throws {
        let sourceChildren = try contentsOfDirectory(atPath: source.path)

        for childName in sourceChildren {
            let sourceChild = source.appendingPathComponent(childName)
            let destinationChild = destination.appendingPathComponent(childName)

            if fileExists(atPath: destinationChild.path) {
                // Child exists — if it's a directory, recurse to check its children too
                if directoryExists(atPath: sourceChild.path) {
                    try _copyMissingChildren(from: sourceChild, to: destinationChild)
                }
            } else {
                // Child is missing — copy it individually
                try _copyItem(at: sourceChild, to: destinationChild)
            }
        }
    }

    private enum FileManagerError: Error {
        case unableToEnumerate
    }

    public func sizeOfDirectory(at url: URL, options mask: FileManager.DirectoryEnumerationOptions) throws -> Int64 {
        guard let enumerator = enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: .skipsHiddenFiles,
            errorHandler: nil
        ) else {
            throw FileManagerError.unableToEnumerate
        }

        var bytes: Int64 = 0
        for case let url as URL in enumerator {
            bytes += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }

        return bytes
    }
}

extension FileManager: ReadOnlyFileManagerProtocol {}
