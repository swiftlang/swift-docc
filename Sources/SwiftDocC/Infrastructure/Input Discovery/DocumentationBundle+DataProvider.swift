/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that provides data for files in a documentation bundle.
package protocol DocumentationBundleDataProvider {
    /// Returns the contents of the file at the specified location.
    ///
    /// - Parameter url: The url of the file to read.
    /// - Throws: If the provider failed to read the file.
    func contents(of url: URL) throws -> Data
}

/// A type that provides in-memory data for files in a bundle.
struct InMemoryDataProvider: DocumentationBundleDataProvider {
    private let files: [URL: Data]
    private let fileManager: FileManagerProtocol?
    
    /// Creates a data provider with a collection of in-memory files.
    ///
    /// If the provider doesn't have in-memory data for a given file it will use the file manager as a fallback.
    /// This allows the in-memory provider to be used for a mix of in-memory and on-disk content.
    ///
    /// - Parameters:
    ///   - files: The in-memory data for the files that provider can provide
    ///   - fallbackFileManager: The file manager that the provider uses as a fallback for any file it doesn't have in-memory data for.
    init(files: [URL: Data], fallbackFileManager: FileManagerProtocol?) {
        self.files = files
        self.fileManager = fallbackFileManager
    }
    
    func contents(of url: URL) throws -> Data {
        if let inMemoryResult = files[url] {
            return inMemoryResult
        }
        if let onDiskResult = try fileManager?.contents(of: url) {
            return onDiskResult
        }
        
        throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: url.path])
    }
}
