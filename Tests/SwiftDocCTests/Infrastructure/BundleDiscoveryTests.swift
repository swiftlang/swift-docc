/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import SwiftDocCTestUtilities

class BundleDiscoveryTests: XCTestCase {
    
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
    
    // This tests registration of multiple catalogs which is deprecated
    // Deprecating the test silences the deprecation warning when running the tests. It doesn't skip the test.
    @available(*, deprecated, message: "This deprecated API will be removed after 6.2 is released")
    func testFirstBundle() throws {
        let url = try createTemporaryDirectory()
        // Create 3 minimal doc bundles
        for i in 1 ... 3 {
            let nestedBundle = Folder(name: "TestBundle\(i).docc", content: [
                InfoPlist(displayName: "Test Bundle \(i)", identifier: "com.example.bundle\(i)"),
                TextFile(name: "Root.md", utf8Content: """
                # Test Bundle \(i)
                @Metadata {
                   @TechnologyRoot
                }
                Abstract.
                
                Content.
                """),
            ])
            _ = try nestedBundle.write(inside: url)
        }
        
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: url)
        try workspace.registerProvider(dataProvider)
        
        // Verify all bundles are loaded
        XCTAssertEqual(context.registeredBundles.map { $0.identifier }.sorted(),
            ["com.example.bundle1", "com.example.bundle2", "com.example.bundle3"]
        )
        
        // Verify the first one is bundle1
        let converter = DocumentationConverter(documentationBundleURL: url, emitDigest: false, documentationCoverageOptions: .noCoverage, currentPlatforms: nil, workspace: workspace, context: context, dataProvider: dataProvider, bundleDiscoveryOptions: .init())
        XCTAssertEqual(converter.firstAvailableBundle()?.identifier, "com.example.bundle1")
    }
    
    // This test registration more than once data provider which is deprecated.
    // Deprecating the test silences the deprecation warning when running the tests. It doesn't skip the test.
    @available(*, deprecated, message: "This deprecated API will be removed after 6.2 is released")
    func testLoadComplexWorkspace() throws {
        let allFiles = try flatListOfFiles()
        let workspace = Folder(name: "TestWorkspace", content: [
            CopyOfFolder(original: testBundleLocation),
            Folder(name: "nested", content: [
                Folder(name: "irrelevant", content: [
                    TextFile(name: "irrelevant.txt", utf8Content: "distraction"),
                ]),
                TextFile(name: "irrelevant.txt", utf8Content: "distraction"),
                Folder(name: "TestBundle2.docc", content: [
                    InfoPlist(displayName: "Test Bundle", identifier: "com.example.bundle2"),
                    Folder(name: "Subfolder", content: // All files flattened into one folder
                        allFiles.map { CopyOfFile(original: $0) }
                    ),
                ]),
            ]),
        ])
        
        let tempURL = try createTemporaryDirectory()
        
        let workspaceURL = try workspace.write(inside: tempURL)

        let dataProvider = try LocalFileSystemDataProvider(rootURL: workspaceURL)

        let bundles = (try dataProvider.bundles()).sorted { (bundle1, bundle2) -> Bool in
            return bundle1.identifier < bundle2.identifier
        }

        XCTAssertEqual(bundles.count, 2)
        
        guard bundles.count == 2 else { return }
        
        XCTAssertEqual(bundles[0].identifier, "com.example.bundle2")
        XCTAssertEqual(bundles[1].identifier, "org.swift.docc.example")
        
        func checkBundle(_ bundle: DocumentationBundle) {
            XCTAssertEqual(bundle.displayName, "Test Bundle")
            XCTAssertEqual(bundle.symbolGraphURLs.count, 4)
            XCTAssertTrue(bundle.symbolGraphURLs.map { $0.lastPathComponent }.contains("mykit-iOS.symbols.json"))
            XCTAssertTrue(bundle.symbolGraphURLs.map { $0.lastPathComponent }.contains("MyKit@SideKit.symbols.json"))
            XCTAssertTrue(bundle.symbolGraphURLs.map { $0.lastPathComponent }.contains("sidekit.symbols.json"))
            XCTAssertTrue(bundle.symbolGraphURLs.map { $0.lastPathComponent }.contains("FillIntroduced.symbols.json"))
            XCTAssertFalse(bundle.markupURLs.isEmpty)
            XCTAssertTrue(bundle.miscResourceURLs.map { $0.lastPathComponent }.sorted().contains("intro.png"))
        }
        
        for bundle in bundles {
            checkBundle(bundle)
        }
    }
    
    func testBundleFormat() throws {
        let allFiles = try flatListOfFiles()
        
        func parsedBundle(from folder: File) throws -> DocumentationBundle {
            let fileSystem = try TestFileSystem(folders: [
                Folder(name: "path", content: [
                    Folder(name: "to", content: [
                        folder
                    ])
                ])
            ])
            
            let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)
            let (bundle, _) = try inputProvider.inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/"), options: .init())
            return bundle
        }
        
        let expectedBundle = try parsedBundle(from: CopyOfFolder(original: testBundleLocation))
        
        func checkExpectedFilesFoundIn(_ folder: File, file: StaticString = #file, line: UInt = #line) throws {
            let bundle = try parsedBundle(from: folder)
            
            XCTAssertEqual(bundle.id, expectedBundle.id)
            XCTAssertEqual(bundle.displayName, expectedBundle.displayName)
            
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
            
            assertEqualFiles(bundle.symbolGraphURLs, expectedBundle.symbolGraphURLs, file: (file), line: line)
            assertEqualFiles(bundle.markupURLs, expectedBundle.markupURLs, file: (file), line: line)
            assertEqualFiles(bundle.miscResourceURLs, expectedBundle.miscResourceURLs, file: (file), line: line)
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
        
        // Deeply nested subfolders inside the bundle
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
                    // The test bundle without all the symbol graph files
                    CopyOfFolder(original: testBundleLocation, filter: { !DocumentationBundleFileTypes.isSymbolGraphFile($0) }),
                    
                    // Just the symbol graph files in a non-bundle folder
                    CopyOfFolder(original: testBundleLocation, newName: "Not a catalog", filter: { DocumentationBundleFileTypes.isSymbolGraphFile($0) }),
                ])
            ])
        ])
        
        let bundleDiscoveryOptions = BundleDiscoveryOptions(
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
        let (bundle, _) = try inputProvider.inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/"), options: bundleDiscoveryOptions)
        
        // The bundle information was overridden from the options
        XCTAssertEqual(bundle.id, "org.swift.docc.example")
        XCTAssertEqual(bundle.displayName, "Test Bundle") // The fallback should not override this value
        
        // The additional symbol graph files are part of the bundle
        XCTAssertEqual(bundle.symbolGraphURLs.count, 3)
        XCTAssertTrue(bundle.symbolGraphURLs.map { $0.lastPathComponent }.contains("mykit-iOS.symbols.json"))
        XCTAssertTrue(bundle.symbolGraphURLs.map { $0.lastPathComponent }.contains("MyKit@SideKit.symbols.json"))
        XCTAssertTrue(bundle.symbolGraphURLs.map { $0.lastPathComponent }.contains("sidekit.symbols.json"))
        
        // The symbol graph files are not located inside the doc bundle
        for symbolGraphFile in bundle.symbolGraphURLs {
            XCTAssertFalse(symbolGraphFile.pathComponents.contains(where: { $0.hasSuffix(".docc") }))
        }
    }
    
    func testNoInfoPlist() throws {
        let catalog = Folder(name: "Something.docc", content: [])

        let bundleDiscoveryOptions = BundleDiscoveryOptions(
            infoPlistFallbacks: [
                "CFBundleDisplayName": "Fallback Display Name",
                "CFBundleIdentifier": "com.fallback.bundle.identifier"
            ],
            additionalSymbolGraphFiles: []
        )
        
        let fileSystem = try TestFileSystem(folders: [catalog])
        
        let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)
        let (bundle, _) = try inputProvider.inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/\(catalog.name)"), options: bundleDiscoveryOptions)
        
        // The bundle information was specified via the options
        XCTAssertEqual(bundle.id, "com.fallback.bundle.identifier")
        XCTAssertEqual(bundle.displayName, "Fallback Display Name")
    }

    func testNoCustomTemplates() throws {
        let catalog = Folder(name: "Something.docc", content: [])

        let fileSystem = try TestFileSystem(folders: [catalog])
        
        let inputProvider = DocumentationContext.InputsProvider(fileManager: fileSystem)
        let (bundle, _) = try inputProvider.inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/\(catalog.name)"), options: .init())

        // Ensure that `customHeader` is `nil` if no top level `header.html`
        // file was found in the bundle
        XCTAssertNil(bundle.customHeader)
        // Ensure that `customFooter` is `nil` if no top level `footer.html`
        // file was found in the bundle
        XCTAssertNil(bundle.customFooter)
        // Ensure that `themeSettings` is `nil` if no `theme-settings.json`
        // file was found in the bundle
        XCTAssertNil(bundle.themeSettings)
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
        let (bundle, _) = try inputProvider.inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/\(catalog.name)"), options: .init())

        // Ensure that `customHeader` points to the location of a top level
        // `header.html` file if one is found in the bundle
        XCTAssertEqual(bundle.customHeader?.lastPathComponent, "header.html")
        // Ensure that `customFooter` points to the location of a top level
        // `footer.html` file if one is found in the bundle
        XCTAssertEqual(bundle.customFooter?.lastPathComponent, "footer.html")
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
        let (bundle, _) = try inputProvider.inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/\(catalog.name)"), options: .init())

        // Ensure that `themeSettings` points to the location of a
        // `theme-settings.json` file if one is found in the bundle
        XCTAssertEqual(bundle.themeSettings?.lastPathComponent, "theme-settings.json")
    }
}
