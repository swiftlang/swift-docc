/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest

// These helpers methods exist to put temp files for different test executions in different locations when running in Swift CI.

public extension XCTestCase {
    
    @available(*, deprecated, message: "Use `createTemporaryDirectory` instead in unit tests to avoid referencing a shared location in Swift CI.")
    func NSTemporaryDirectory() -> String {
        return Foundation.NSTemporaryDirectory()
    }
    
    /// Creates a new temporary directory and returns the URL of that directory.
    ///
    /// After the current test method has returned the temporary directory is automatically removed.
    ///
    /// - Parameters:
    ///   - pathComponents: Additional path components to add to the temporary URL.
    ///   - fileManager: The file manager that will create the directory.
    /// - Returns: The URL of the newly created directory.
    func createTemporaryDirectory(pathComponents: String..., fileManager: FileManager = .default) throws -> URL {
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
        try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
        
        return tempURL
    }
}

private extension String {
    func replacingWhitespaceAndPunctuation(with separator: String) -> String {
        let charactersToStrip = CharacterSet.whitespaces.union(.punctuationCharacters)
        return components(separatedBy: charactersToStrip).filter({ !$0.isEmpty }).joined(separator: separator)
    }
}
