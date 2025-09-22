/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import SwiftDocC
import SwiftDocCTestUtilities

extension XCTestCase {
    /// Loads a documentation catalog from an in-memory test file system.
    ///
    /// - Parameters:
    ///   - catalog: The directory structure of the documentation catalog
    ///   - otherFileSystemDirectories: Any other directories in the test file system.
    ///   - configuration: Configuration for the created context.
    /// - Returns: The documentation inputs and the loaded documentation context for that input.
    func loadBundle(
        catalog: Folder,
        otherFileSystemDirectories: [Folder] = [],
        configuration: DocumentationContext.Configuration = .init()
    ) async throws -> (DocumentationContext.Inputs, DocumentationContext) {
        let fileSystem = try TestFileSystem(folders: [catalog] + otherFileSystemDirectories)
        
        let (inputs, dataProvider) = try DocumentationContext.InputsProvider(fileManager: fileSystem)
            .inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/\(catalog.name)"), options: .init())

        let context = try await DocumentationContext(inputs: inputs, dataProvider: dataProvider, configuration: configuration)
        return (inputs, context)
    }
    
    func testCatalogURL(named name: String, file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "docc", subdirectory: "Test Bundles"),
            file: file, line: line
        )
    }
}
