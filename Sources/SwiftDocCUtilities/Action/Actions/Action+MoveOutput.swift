/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@_spi(FileManagerProtocol) import SwiftDocC

extension Action {
    
    /// Creates a new unique directory, with an optional template, inside of specified container.
    /// - Parameters:
    ///   - container: The container directory to create a new directory within.
    ///   - template: An optional template for the new directory.
    ///   - fileManager: The file manager to create the new directory.
    /// - Returns: The URL of the new unique directory.
    static func createUniqueDirectory(inside container: URL, template: URL?, fileManager: FileManagerProtocol) throws -> URL {
        let targetURL = container.appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        
        if let template = template {
            // If a template directory has been provided, create the temporary build folder with its contents
            // Ensure that the container exists
            try? fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: false, attributes: nil)
            try fileManager.copyItem(at: template, to: targetURL)
        } else {
            // Otherwise, create an empty directory
            try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
        }
        return targetURL
    }
    
    /// Moves a file or directory from the specified location to a new location.
    /// - Parameters:
    ///   - source: The file or directory to move.
    ///   - destination: The new location for the file or directory.
    ///   - fileManager: The file manager to move the file or directory.
    static func moveOutput(from source: URL, to destination: URL, fileManager: FileManagerProtocol) throws {
        // We only need to move output if it exists
        guard fileManager.fileExists(atPath: source.path) else { return }
        
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        
        try ensureThatParentFolderExist(for: destination, fileManager: fileManager)
        try fileManager.moveItem(at: source, to: destination)
    }
    
    private static func ensureThatParentFolderExist(for location: URL, fileManager: FileManagerProtocol) throws {
        let parentFolder = location.deletingLastPathComponent()
        if !fileManager.directoryExists(atPath: parentFolder.path) {
            try fileManager.createDirectory(at: parentFolder, withIntermediateDirectories: false, attributes: nil)
        }
    }
}
