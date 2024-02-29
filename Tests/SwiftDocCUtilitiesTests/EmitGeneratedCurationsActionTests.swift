/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import SwiftDocCUtilities
@_spi(FileManagerProtocol) import SwiftDocCTestUtilities

class EmitGeneratedCurationsActionTests: XCTestCase {
    
    func testWritesDocumentationExtensionFilesToOutputDir() throws {
        // This can't be in the test file system because `LocalFileSystemDataProvider` doesn't support `FileManagerProtocol`.
        let bundleURL = try XCTUnwrap(Bundle.module.url(forResource: "MixedLanguageFramework", withExtension: "docc", subdirectory: "Test Bundles"))
        
        func assertOutput(
            initialContent: [File],
            depthLimit: Int?,
            startingPointSymbolLink: String?,
            expectedFilesList: [String],
            file: StaticString = #file,
            line: UInt = #line
        ) throws {
            let fs = try TestFileSystem(folders: [
                Folder(name: "output", content: initialContent)
            ])
            
            let outputDir = URL(fileURLWithPath: "/output/Output.doccarchive")
            var action = try EmitGeneratedCurationAction(
                documentationCatalog: bundleURL,
                additionalSymbolGraphDirectory: nil,
                outputURL: outputDir,
                depthLimit: depthLimit,
                startingPointSymbolLink: startingPointSymbolLink,
                fileManager: fs
            )
            _ = try action.perform(logHandle: .none)
            
            XCTAssertEqual(try fs.recursiveContentsOfDirectory(atPath: "/output").sorted(), expectedFilesList, file: file, line: line)
        }
        
        try assertOutput(initialContent: [], depthLimit: 0, startingPointSymbolLink: nil, expectedFilesList: [
            "Output.doccarchive",
            "Output.doccarchive/MixedLanguageFramework.md",
        ])
        
        try assertOutput(initialContent: [], depthLimit: nil, startingPointSymbolLink: nil, expectedFilesList: [
            "Output.doccarchive",
            "Output.doccarchive/MixedLanguageFramework",
            "Output.doccarchive/MixedLanguageFramework.md",
            "Output.doccarchive/MixedLanguageFramework/Bar.md",
            "Output.doccarchive/MixedLanguageFramework/Foo-swift.struct.md",
            "Output.doccarchive/MixedLanguageFramework/SwiftOnlyStruct.md",
        ])
        
        try assertOutput(initialContent: [], depthLimit: nil, startingPointSymbolLink: "Foo-struct", expectedFilesList: [
            "Output.doccarchive",
            "Output.doccarchive/MixedLanguageFramework",
            "Output.doccarchive/MixedLanguageFramework/Foo-swift.struct.md",
        ])
    }
}
