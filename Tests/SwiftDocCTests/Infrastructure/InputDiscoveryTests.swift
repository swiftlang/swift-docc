/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import DocCTestUtilities

class InputDiscoveryTests: XCTestCase {
    
    private let testBundleLocation = Bundle.module.url(forResource: "LegacyBundle_DoNotUseInNewTests", withExtension: "docc", subdirectory: "Test Bundles")!
    private func flatListOfFiles() throws -> [URL] {
        let testBundleLocation = try testCatalogURL(named: "LegacyBundle_DoNotUseInNewTests")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: testBundleLocation, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles))
        
        var files: [URL] = []
        for case let fileURL as URL in enumerator where try fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == false {
            files.append(fileURL)
        }
        return files
    }
    
    func testBundleFormat() throws {
        let allFiles = try flatListOfFiles()
        
        func parsedBundle(from folder: any File) throws -> DocumentationContext.Inputs {
            let fileSystem = try TestFileSystem(folders: [
                Folder(name: "path", content: [
                    Folder(name: "to", content: [
                        folder
                    ])
                ])
            ])
            
            let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)
            let (inputs, _) = try inputProvider.inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/"), options: .init())
            return inputs
        }
        
        let expectedBundle = try parsedBundle(from: CopyOfFolder(original: testBundleLocation))
        
        func checkExpectedFilesFoundIn(_ folder: any File, file: StaticString = #filePath, line: UInt = #line) throws {
            let catalog = try parsedBundle(from: folder)
            
            XCTAssertEqual(catalog.id, expectedBundle.id)
            XCTAssertEqual(catalog.displayName, expectedBundle.displayName)
            
            func assertEqualFiles(_ got: [URL], _ expected: [URL], file: StaticString = #filePath, line: UInt = #line) {
                let gotFileNames = Set(got.map { $0.lastPathComponent })
                let expectedFileNames = Set(expected.map { $0.lastPathComponent })
                
                XCTAssertEqual(gotFileNames, expectedFileNames, file: (file), line: line)
                XCTAssertEqual(gotFileNames.count, expectedFileNames.count, file: (file), line: line)
                
                let extraFiles = gotFileNames.subtracting(expectedFileNames)
                XCTAssert(extraFiles.isEmpty, "Got these extra files: \(extraFiles.sorted().map({ $0.singleQuoted }).joined(separator: ", "))", file: (file), line: line)
                
                let missingFiles = expectedFileNames.subtracting(gotFileNames)
                XCTAssert(missingFiles.isEmpty, "Missing these files: \(extraFiles.sorted().map({ $0.singleQuoted }).joined(separator: ", "))", file: (file), line: line)
            }
            
            assertEqualFiles(catalog.symbolGraphURLs, expectedBundle.symbolGraphURLs, file: (file), line: line)
            assertEqualFiles(catalog.markupURLs, expectedBundle.markupURLs, file: (file), line: line)
            assertEqualFiles(catalog.miscResourceURLs, expectedBundle.miscResourceURLs, file: (file), line: line)
        }
        
        // The TestBundle as-is.
        try checkExpectedFilesFoundIn(
            CopyOfFolder(original: testBundleLocation, newName: "TestBundle.docc")
        )
        
        // Compatibility with previous format
        try checkExpectedFilesFoundIn( // All in one folder
            Folder(name: "TestBundle.docc", content:
                allFiles.map { CopyOfFile(original: $0) }
            )
        )
        
        try checkExpectedFilesFoundIn( // Separate subfolders for symbols and resources
            Folder(name: "TestBundle.docc", content: [
                // Symbol graphs in the Symbols folder
                Folder(name: "Symbols", content:
                    allFiles.filter { $0.lastPathComponent.lowercased().hasSuffix(".symbols.json") }.map { CopyOfFile(original: $0) }
                ),
                // Other files in the Resources folder
                Folder(name: "Resources", content:
                    allFiles.filter { !$0.lastPathComponent.lowercased().hasSuffix(".symbols.json") }.map { CopyOfFile(original: $0) }
                ),
                // The original Info.plist
                CopyOfFile(original: allFiles.first(where: { $0.lastPathComponent.lowercased() == "info.plist" })!),
            ])
        )
        
        // Deeply nested subfolders inside the catalog
        try checkExpectedFilesFoundIn(
            Folder(name: "TestBundle.docc", content: [
                // The original Info.plist
                CopyOfFile(original: allFiles.first(where: { $0.lastPathComponent.lowercased() == "info.plist" })!),
                // Put all the other files in deeper and deeper folders
                Folder(name: "One", content: allFiles[..<10].map { CopyOfFile(original: $0) }).appendingFile(
                    Folder(name: "Two", content: allFiles[10..<20].map { CopyOfFile(original: $0) }).appendingFile(
                        Folder(name: "Three", content: allFiles[20..<30].map { CopyOfFile(original: $0) }).appendingFile(
                            Folder(name: "Four", content: allFiles[30...].map { CopyOfFile(original: $0) })
                        )
                    )
                ),
            ])
        )
    }
    
    func testBundleDiscoveryOptions() throws {
        let fileSystem = try TestFileSystem(folders: [
            Folder(name: "path", content: [
                Folder(name: "to", content: [
                    // The test catalog without all the symbol graph files
                    CopyOfFolder(original: testBundleLocation, filter: { !DocumentationCatalogFileTypes.isSymbolGraphFile($0) }),
                    
                    // Just the symbol graph files in a non-bundle folder
                    CopyOfFolder(original: testBundleLocation, newName: "Not a catalog", filter: { DocumentationCatalogFileTypes.isSymbolGraphFile($0) }),
                ])
            ])
        ])
        
        let catalogDiscoveryOptions = CatalogDiscoveryOptions(
            infoPlistFallbacks: [
                "CFBundleDisplayName": "Fallback Display Name",
            ],
            additionalSymbolGraphFiles: [
                URL(fileURLWithPath: "path/to/Not a catalog/mykit-iOS.symbols.json"),
                URL(fileURLWithPath: "path/to/Not a catalog/sidekit.symbols.json"),
                URL(fileURLWithPath: "path/to/Not a catalog/MyKit@SideKit.symbols.json"),
            ]
        )
        
        let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)
        let (inputs, _) = try inputProvider.inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/"), options: catalogDiscoveryOptions)
        
        // The input information was overridden from the options
        XCTAssertEqual(inputs.id, "org.swift.docc.example")
        XCTAssertEqual(inputs.displayName, "Test Bundle") // The fallback should not override this value
        
        // The additional symbol graph files are part of the inputs
        XCTAssertEqual(inputs.symbolGraphURLs.count, 3)
        XCTAssertTrue(inputs.symbolGraphURLs.map { $0.lastPathComponent }.contains("mykit-iOS.symbols.json"))
        XCTAssertTrue(inputs.symbolGraphURLs.map { $0.lastPathComponent }.contains("MyKit@SideKit.symbols.json"))
        XCTAssertTrue(inputs.symbolGraphURLs.map { $0.lastPathComponent }.contains("sidekit.symbols.json"))
        
        // The symbol graph files are not located inside the documentation catalog
        for symbolGraphFile in inputs.symbolGraphURLs {
            XCTAssertFalse(symbolGraphFile.pathComponents.contains(where: { $0.hasSuffix(".docc") }))
        }
    }
    
    func testNoInfoPlist() throws {
        let catalog = Folder(name: "Something.docc", content: [])

        let bundleDiscoveryOptions = CatalogDiscoveryOptions(
            infoPlistFallbacks: [
                "CFBundleDisplayName": "Fallback Display Name",
                "CFBundleIdentifier": "com.fallback.bundle.identifier"
            ],
            additionalSymbolGraphFiles: []
        )
        
        let fileSystem = try TestFileSystem(folders: [catalog])
        
        let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)
        let (inputs, _) = try inputProvider.inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/\(catalog.name)"), options: bundleDiscoveryOptions)
        
        // The inputs information was specified via the options
        XCTAssertEqual(inputs.id, "com.fallback.bundle.identifier")
        XCTAssertEqual(inputs.displayName, "Fallback Display Name")
    }

    func testNoCustomTemplates() throws {
        let catalog = Folder(name: "Something.docc", content: [])

        let fileSystem = try TestFileSystem(folders: [catalog])
        
        let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)
        let (inputs, _) = try inputProvider.inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/\(catalog.name)"), options: .init())

        // Ensure that `customHeader` is `nil` if no top level `header.html` file was found in the inputs
        XCTAssertNil(inputs.customHeader)
        // Ensure that `customFooter` is `nil` if no top level `footer.html` file was found in the inputs
        XCTAssertNil(inputs.customFooter)
        // Ensure that `themeSettings` is `nil` if no `theme-settings.json` file was found in the inputs
        XCTAssertNil(inputs.themeSettings)
    }

    func testCustomTemplatesFound() throws {
        let catalog = Folder(name: "Something.docc", content: [
            TextFile(name: "header.html", utf8Content: """
            <header><marquee>hello world</marquee></header>
            """),
            TextFile(name: "footer.html", utf8Content: """
            <footer><marquee>goodbye world</marquee></footer>
            """),
        ])

        let fileSystem = try TestFileSystem(folders: [catalog])
        
        let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)
        let (inputs, _) = try inputProvider.inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/\(catalog.name)"), options: .init())

        // Ensure that `customHeader` points to the location of a top level
        // `header.html` file if one is found in the inputs
        XCTAssertEqual(inputs.customHeader?.lastPathComponent, "header.html")
        // Ensure that `customFooter` points to the location of a top level
        // `footer.html` file if one is found in the inputs
        XCTAssertEqual(inputs.customFooter?.lastPathComponent, "footer.html")
    }

    func testThemeSettingsFound() throws {
        let catalog = Folder(name: "Something.docc", content: [
            TextFile(name: "theme-settings.json", utf8Content: """
            {
              "meta": {},
              "theme": {
                "colors": {
                  "text": "#ff0000"
                }
              },
              "features": {}
            }
            """),
        ])

        let fileSystem = try TestFileSystem(folders: [catalog])
        
        let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)
        let (inputs, _) = try inputProvider.inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/\(catalog.name)"), options: .init())

        // Ensure that `themeSettings` points to the location of a
        // `theme-settings.json` file if one is found in the inputs
        XCTAssertEqual(inputs.themeSettings?.lastPathComponent, "theme-settings.json")
    }
}
