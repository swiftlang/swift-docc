/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import CommandLine
import SwiftDocCTestUtilities

class EmitGeneratedCurationsActionTests: XCTestCase {
    
    func testWritesDocumentationExtensionFilesToOutputDir() async throws {
        // This can't be in the test file system because `LocalFileSystemDataProvider` doesn't support `FileManagerProtocol`.
        let realCatalogURL = try XCTUnwrap(Bundle.module.url(forResource: "MixedLanguageFramework", withExtension: "docc", subdirectory: "Test Bundles"))
        
        func assertOutput(
            initialContent: [any File],
            depthLimit: Int?,
            startingPointSymbolLink: String?,
            expectedFilesList: [String],
            file: StaticString = #filePath,
            line: UInt = #line
        ) async throws {
            let fs = try TestFileSystem(folders: [
                Folder(name: "input", content: [
                    CopyOfFolder(original: realCatalogURL)
                ]),
                Folder(name: "output", content: initialContent),
            ])
            
            let catalogURL = URL(fileURLWithPath: "/input/MixedLanguageFramework.docc")
            let outputDir  = URL(fileURLWithPath: "/output/Output.doccarchive")
            
            let action = try EmitGeneratedCurationAction(
                documentationCatalog: catalogURL,
                additionalSymbolGraphDirectory: nil,
                outputURL: outputDir,
                depthLimit: depthLimit,
                startingPointSymbolLink: startingPointSymbolLink,
                fileManager: fs
            )
            
            _ = try await action.perform(logHandle: .none)
            XCTAssertEqual(try fs.recursiveContentsOfDirectory(atPath: "/output").sorted(), expectedFilesList, file: file, line: line)
        }
        
        try await assertOutput(initialContent: [], depthLimit: 0, startingPointSymbolLink: nil, expectedFilesList: [
            "Output.doccarchive",
            "Output.doccarchive/MixedLanguageFramework.md",
        ])
        
        try await assertOutput(initialContent: [], depthLimit: nil, startingPointSymbolLink: nil, expectedFilesList: [
            "Output.doccarchive",
            "Output.doccarchive/MixedLanguageFramework",
            "Output.doccarchive/MixedLanguageFramework.md",
            "Output.doccarchive/MixedLanguageFramework/Bar.md",
            "Output.doccarchive/MixedLanguageFramework/Foo-swift.struct.md",
            "Output.doccarchive/MixedLanguageFramework/SwiftOnlyStruct.md",
        ])
        
        try await assertOutput(initialContent: [], depthLimit: nil, startingPointSymbolLink: "Foo-struct", expectedFilesList: [
            "Output.doccarchive",
            "Output.doccarchive/MixedLanguageFramework",
            "Output.doccarchive/MixedLanguageFramework/Foo-swift.struct.md",
        ])
    }
}
