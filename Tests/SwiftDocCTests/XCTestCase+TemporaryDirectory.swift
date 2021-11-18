/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

// These helpers methods exist to put temp files for different test executions in different locations when running in Swift CI.

extension XCTestCase {
    
    @available(*, deprecated, message: "Use `createTemporaryDirectory` instead in unit tests to avoid referencing a shared location in Swift CI.")
    func NSTemporaryDirectory() -> String {
        return Foundation.NSTemporaryDirectory()
    }
    
    /// Creates a new temporary directory and returns the URL of that directory.
    ///
    /// At the end of the test the temporary directory is automatically removed.
    ///
    /// - Parameters:
    ///   - pathComponents: Additional path components to add to the temporary URL.
    ///   - createDirectoryForLastPathComponent: If the file manager should create a directory for the last path component or not. Defaults to `true`.
    ///   - fileManager: The file manager that will create the directory.
    /// - Returns: The URL of the newly created directory.
    func createTemporaryDirectory(
        pathComponents: String...,
        createDirectoryForLastPathComponent: Bool = true,
        fileManager: FileManager = .default
    ) throws -> URL {
        let bundleParentDir = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
        let baseURL = bundleParentDir.appendingPathComponent(name.replacingWhitespaceAndPunctuation(with: "-"))
        
        var tempURL = baseURL.appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        for component in pathComponents {
            tempURL.appendPathComponent(component)
        }
        tempURL.standardize()
        
        addTeardownBlock {
            try? fileManager.removeItem(at: baseURL)
        }
        
        let urlToCreate = createDirectoryForLastPathComponent ? tempURL : tempURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: urlToCreate, withIntermediateDirectories: true, attributes: nil)
        
        return tempURL
    }
}
