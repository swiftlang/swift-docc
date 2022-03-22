/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import SwiftDocCTestUtilities

class CatalogDiscoveryTests: XCTestCase {
    
    private let testCatalogLocation = Bundle.module.url(
        forResource: "TestCatalog", withExtension: "docc", subdirectory: "Test Catalogs")!
    private lazy var allFiles: [URL] = ((try? FileManager.default.subpathsOfDirectory(atPath: testCatalogLocation.path)) ?? [])
        .map { testCatalogLocation.appendingPathComponent($0) }
        .filter { !$0.pathComponents.dropFirst(testCatalogLocation.pathComponents.count).contains(where: { $0.hasPrefix(".") }) }
    
    func testFirstCatalog() throws {
        let url = try createTemporaryDirectory()
        // Create 3 minimal doc catalogs
        for i in 1 ... 3 {
            let nestedCatalog = Folder(name: "TestCatalog\(i).docc", content: [
                InfoPlist(displayName: "Test Catalog \(i)", identifier: "com.example.catalog\(i)"),
                TextFile(name: "Root.md", utf8Content: """
                # Test Catalog \(i)
                @Metadata {
                   @TechnologyRoot
                }
                Abstract.
                
                Content.
                """),
            ])
            _ = try nestedCatalog.write(inside: url)
        }
        
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: url)
        try workspace.registerProvider(dataProvider)
        
        // Verify all catalogs are loaded
        XCTAssertEqual(context.registeredCatalogs.map { $0.identifier }.sorted(),
            ["com.example.catalog1", "com.example.catalog2", "com.example.catalog3"]
        )
        
        // Verify the first one is catalog1
        let converter = DocumentationConverter(documentationCatalogURL: url, emitDigest: false, documentationCoverageOptions: .noCoverage, currentPlatforms: nil, workspace: workspace, context: context, dataProvider: dataProvider, catalogDiscoveryOptions: .init())
        XCTAssertEqual(converter.firstAvailableCatalog()?.identifier, "com.example.catalog1")
    }
    
    func testLoadComplexWorkspace() throws {
        
        let workspace = Folder(name: "TestWorkspace", content: [
            CopyOfFile(original: testCatalogLocation),
            Folder(name: "nested", content: [
                Folder(name: "irrelevant", content: [
                    TextFile(name: "irrelevant.txt", utf8Content: "distraction"),
                ]),
                TextFile(name: "irrelevant.txt", utf8Content: "distraction"),
                Folder(name: "TestCatalog2.docc", content: [
                    InfoPlist(displayName: "Test Catalog", identifier: "com.example.catalog2"),
                    Folder(name: "Subfolder", content: // All files flattened into one folder
                        allFiles.map { CopyOfFile(original: $0) }
                    ),
                ]),
            ]),
        ])
        
        let tempURL = try createTemporaryDirectory()
        
        let workspaceURL = try workspace.write(inside: tempURL)

        let dataProvider = try LocalFileSystemDataProvider(rootURL: workspaceURL)

        let catalogs = (try dataProvider.catalogs()).sorted { (catalog1, catalog2) -> Bool in
            return catalog1.identifier < catalog2.identifier
        }

        XCTAssertEqual(catalogs.count, 2)
        
        guard catalogs.count == 2 else { return }
        
        XCTAssertEqual(catalogs[0].identifier, "com.example.catalog2")
        XCTAssertEqual(catalogs[1].identifier, "org.swift.docc.example")
        
        func checkCatalog(_ catalog: DocumentationCatalog) {
            XCTAssertEqual(catalog.displayName, "Test Catalog")
            XCTAssertEqual(catalog.symbolGraphURLs.count, 5)
            XCTAssertTrue(catalog.symbolGraphURLs.map { $0.lastPathComponent }.contains("mykit-iOS.symbols.json"))
            XCTAssertTrue(catalog.symbolGraphURLs.map { $0.lastPathComponent }.contains("MyKit@SideKit.symbols.json"))
            XCTAssertTrue(catalog.symbolGraphURLs.map { $0.lastPathComponent }.contains("sidekit.symbols.json"))
            XCTAssertTrue(catalog.symbolGraphURLs.map { $0.lastPathComponent }.contains("FillIntroduced.symbols.json"))
            XCTAssertTrue(catalog.symbolGraphURLs.map { $0.lastPathComponent }.contains("Test-snippets.symbols.json"))
            XCTAssertFalse(catalog.markupURLs.isEmpty)
            XCTAssertTrue(catalog.miscResourceURLs.map { $0.lastPathComponent }.sorted().contains("intro.png"))
        }
        
        for catalog in catalogs {
            checkCatalog(catalog)
        }
    }
    
    func testCatalogFormat() throws {
        func parsedCatalog(from folder: File) throws -> DocumentationCatalog? {
            let tempURL = try createTemporaryDirectory()
            
            let workspaceURL = try folder.write(inside: tempURL)
            let dataProvider = try LocalFileSystemDataProvider(rootURL: workspaceURL)
            let catalogs = try dataProvider.catalogs()
            
            XCTAssertEqual(catalogs.count, 1)
            return catalogs.first
        }
        
        guard let expectedCatalog = try parsedCatalog(from: CopyOfFolder(original: testCatalogLocation)) else {
            XCTFail("Failed to parse the Test Catalog")
            return
        }
        
        func checkExpectedFilesFoundIn(_ folder: File, file: StaticString = #file, line: UInt = #line) throws {
            guard let catalog = try parsedCatalog(from: folder) else {
                 XCTFail("Failed to parse catalog for folder structure")
                return
            }
            
            XCTAssertEqual(catalog.identifier, expectedCatalog.identifier)
            XCTAssertEqual(catalog.displayName, expectedCatalog.displayName)
            
            func assertEqualFiles(_ got: [URL], _ expected: [URL], file: StaticString = #file, line: UInt = #line) {
                let gotFileNames = Set(got.map { $0.lastPathComponent })
                let expectedFileNames = Set(expected.map { $0.lastPathComponent })
                
                XCTAssertEqual(gotFileNames, expectedFileNames, file: (file), line: line)
                XCTAssertEqual(gotFileNames.count, expectedFileNames.count, file: (file), line: line)
                
                let extraFiles = gotFileNames.subtracting(expectedFileNames)
                XCTAssert(extraFiles.isEmpty, "Got these extra files: \(extraFiles.sorted().map({ $0.singleQuoted }).joined(separator: ", "))", file: (file), line: line)
                
                let missingFiles = expectedFileNames.subtracting(gotFileNames)
                XCTAssert(missingFiles.isEmpty, "Missing these files: \(extraFiles.sorted().map({ $0.singleQuoted }).joined(separator: ", "))", file: (file), line: line)
            }
            
            assertEqualFiles(catalog.symbolGraphURLs, expectedCatalog.symbolGraphURLs, file: (file), line: line)
            assertEqualFiles(catalog.markupURLs, expectedCatalog.markupURLs, file: (file), line: line)
            assertEqualFiles(catalog.miscResourceURLs, expectedCatalog.miscResourceURLs, file: (file), line: line)
        }
        
        // The TestCatalog as-is.
        try checkExpectedFilesFoundIn(
            CopyOfFolder(original: testCatalogLocation, newName: "TestCatalog.docc")
        )
        
        // Compatibility with previous format
        try checkExpectedFilesFoundIn( // All in one folder
            Folder(name: "TestCatalog.docc", content:
                allFiles.map { CopyOfFile(original: $0) }
            )
        )
        
        try checkExpectedFilesFoundIn( // Separate subfolders for symbols and resources
            Folder(name: "TestCatalog.docc", content: [
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
            Folder(name: "TestCatalog.docc", content: [
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
    
    func testCatalogDiscoveryOptions() throws {
        let workspace = Folder(name: "TestWorkspace", content: [
            // The test catalog without all the symbol graph files
            CopyOfFolder(original: testCatalogLocation, filter: { !DocumentationCatalogFileTypes.isSymbolGraphFile($0) }),
            
            // Just the symbol graph files in a non-catalog folder
            CopyOfFolder(original: testCatalogLocation, newName: "Not a doc catalog", filter: { DocumentationCatalogFileTypes.isSymbolGraphFile($0) }),
        ])
        
        let tempURL = try createTemporaryDirectory()
        
        let workspaceURL = try workspace.write(inside: tempURL)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: workspaceURL)

        let catalogDiscoveryOptions = CatalogDiscoveryOptions(
            infoPlistFallbacks: [
                "CFBundleDisplayName": "Fallback Display Name",
            ],
            additionalSymbolGraphFiles: [
                tempURL.appendingPathComponent("TestWorkspace/Not a doc catalog/mykit-iOS.symbols.json"),
                tempURL.appendingPathComponent("TestWorkspace/Not a doc catalog/sidekit.symbols.json"),
                tempURL.appendingPathComponent("TestWorkspace/Not a doc catalog/MyKit@SideKit.symbols.json"),
            ]
        )
        let catalogs = try dataProvider.catalogs(options: catalogDiscoveryOptions)

        XCTAssertEqual(catalogs.count, 1)
        guard let catalog = catalogs.first else { return }
        
        // The catalog information was overridden from the options
        XCTAssertEqual(catalog.identifier, "org.swift.docc.example")
        XCTAssertEqual(catalog.displayName, "Test Catalog") // The fallback should not override this value
        
        // The additional symbol graph files are part of the catalog
        XCTAssertEqual(catalog.symbolGraphURLs.count, 3)
        XCTAssertTrue(catalog.symbolGraphURLs.map { $0.lastPathComponent }.contains("mykit-iOS.symbols.json"))
        XCTAssertTrue(catalog.symbolGraphURLs.map { $0.lastPathComponent }.contains("MyKit@SideKit.symbols.json"))
        XCTAssertTrue(catalog.symbolGraphURLs.map { $0.lastPathComponent }.contains("sidekit.symbols.json"))
        
        // The symbol graph files are not located inside the doc catalog
        for symbolGraphFile in catalog.symbolGraphURLs {
            XCTAssertFalse(symbolGraphFile.pathComponents.contains(where: { $0.hasSuffix(".docc") }))
        }
    }
    
    func testNoInfoPlist() throws {
        let workspace = Folder(name: "TestWorkspace", content: [
            // The test catalog without the Info.plist file
            CopyOfFolder(original: testCatalogLocation, filter: { !DocumentationCatalogFileTypes.isInfoPlistFile($0) }),
        ])
        
        XCTAssertFalse(workspace.recursiveContent.contains(where: { $0.name == "Info.plist" }), "This catalog shouldn't contain an Info.plist file")
        
        let tempURL = try createTemporaryDirectory()
        
        let workspaceURL = try workspace.write(inside: tempURL)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: workspaceURL)

        // All the required information is passed via overrides
        let catalogDiscoveryOptions = CatalogDiscoveryOptions(
            infoPlistFallbacks: [
                "CFBundleDisplayName": "Fallback Display Name",
                "CFBundleIdentifier": "com.fallback.catalog.identifier",
                "CFBundleVersion": "1.2.3",
            ],
            additionalSymbolGraphFiles: []
        )
        let catalogs = try dataProvider.catalogs(options: catalogDiscoveryOptions)
        
        XCTAssertEqual(catalogs.count, 1)
        guard let catalog = catalogs.first else { return }
        
        // The catalog information was specified via the options
        XCTAssertEqual(catalog.identifier, "com.fallback.catalog.identifier")
        XCTAssertEqual(catalog.displayName, "Fallback Display Name")
        XCTAssertEqual(catalog.version, "1.2.3")
    }

    func testNoCustomTemplates() throws {
        let workspace = Folder(name: "TestWorkspace", content: [
            CopyOfFolder(original: testCatalogLocation),
        ])

        let tempURL = try createTemporaryDirectory()

        let workspaceURL = try workspace.write(inside: tempURL)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: workspaceURL)

        let catalogs = try dataProvider.catalogs(options: CatalogDiscoveryOptions())

        XCTAssertEqual(catalogs.count, 1)
        guard let catalog = catalogs.first else { return }

        // Ensure that `customHeader` is `nil` if no top level `header.html`
        // file was found in the catalog
        XCTAssertNil(catalog.customHeader)
        // Ensure that `customFooter` is `nil` if no top level `footer.html`
        // file was found in the catalog
        XCTAssertNil(catalog.customFooter)
    }

    func testCustomTemplatesFound() throws {
        let workspace = Folder(name: "TestCatalog.docc", content:
            allFiles.map { CopyOfFile(original: $0) } + [
                TextFile(name: "header.html", utf8Content: """
                <header><marquee>hello world</marquee></header>
                """),
                TextFile(name: "footer.html", utf8Content: """
                <footer><marquee>goodbye world</marquee></footer>
                """),
            ]
        )

        let tempURL = try createTemporaryDirectory()

        let workspaceURL = try workspace.write(inside: tempURL)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: workspaceURL)

        let catalogs = try dataProvider.catalogs(options: CatalogDiscoveryOptions())

        XCTAssertEqual(catalogs.count, 1)
        guard let catalog = catalogs.first else { return }

        // Ensure that `customHeader` points to the location of a top level
        // `header.html` file if one is found in the catalog
        XCTAssertEqual(catalog.customHeader?.lastPathComponent, "header.html")
        // Ensure that `customFooter` points to the location of a top level
        // `footer.html` file if one is found in the catalog
        XCTAssertEqual(catalog.customFooter?.lastPathComponent, "footer.html")
    }
}
