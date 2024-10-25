/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SwiftDocCTestUtilities
@testable import SwiftDocC

class DocumentationInputsProviderTests: XCTestCase {
    
    // After 6.2 we can update this test to verify that the input provider discovers the same inputs regardless of FileManagerProtocol
    // Deprecating the test silences the deprecation warning when running the tests. It doesn't skip the test.
    @available(*, deprecated, message: "This test uses `LocalFileSystemDataProvider` as a `DocumentationWorkspaceDataProvider` which is deprecated and will be removed after 6.2 is released")
    func testDiscoversSameFilesAsPreviousImplementation() throws {
        let folderHierarchy = Folder(name: "one", content: [
            Folder(name: "two", content: [
                // Start search here.
                TextFile(name: "AAA.md", utf8Content: ""),
                
                Folder(name: "three", content: [
                    TextFile(name: "BBB.md", utf8Content: ""),
                    
                    // This is the catalog that both file system should find
                    Folder(name: "Found.docc", content: [
                        // This top-level Info.plist will be read for bundle information
                        InfoPlist(displayName: "CustomDisplayName"),
                        
                        // These top-level files will be treated as a custom footer and a custom theme
                        TextFile(name: "footer.html", utf8Content: ""),
                        TextFile(name: "theme-settings.json", utf8Content: ""),
                        
                        // Top-level content will be found
                        TextFile(name: "CCC.md", utf8Content: ""),
                        JSONFile(name: "SomethingTopLevel.symbols.json", content: makeSymbolGraph(moduleName: "Something")),
                        DataFile(name: "first.png", data: Data()),
                        
                        Folder(name: "Inner", content: [
                            // Nested content will also be found
                            TextFile(name: "DDD.md", utf8Content: ""),
                            JSONFile(name: "SomethingNested.symbols.json", content: makeSymbolGraph(moduleName: "Something")),
                            DataFile(name: "second.png", data: Data()),
                            
                            // A catalog within a catalog is just another directory
                            Folder(name: "Nested.docc", content: [
                                TextFile(name: "EEE.md", utf8Content: ""),
                            ]),
                            
                            // A nested Info.plist is considered a miscellaneous resource.
                            InfoPlist(displayName: "CustomDisplayName"),
                            
                            // A nested file will be treated as a miscellaneous resource.
                            TextFile(name: "header.html", utf8Content: ""),
                        ]),
                    ]),
                    
                    Folder(name: "four", content: [
                        TextFile(name: "FFF.md", utf8Content: ""),
                    ])
                ]),
            ]),
            // This catalog is outside the provider's search scope
            Folder(name: "OutsideSearchScope.docc", content: []),
        ])
        
        let tempDirectory = try createTempFolder(content: [folderHierarchy])
        let realProvider = DocumentationContext.InputsProvider(fileManager: FileManager.default)
        
        let testFileSystem = try TestFileSystem(folders: [folderHierarchy])
        let testProvider = DocumentationContext.InputsProvider(fileManager: testFileSystem)

        let options = BundleDiscoveryOptions(fallbackIdentifier: "com.example.test", additionalSymbolGraphFiles: [
            tempDirectory.appendingPathComponent("/path/to/SomethingAdditional.symbols.json")
        ])
        
        let foundPrevImplBundle = try XCTUnwrap(LocalFileSystemDataProvider(rootURL: tempDirectory.appendingPathComponent("/one/two")).bundles(options: options).first)
        let (foundRealBundle, _) = try XCTUnwrap(realProvider.inputsAndDataProvider(startingPoint: tempDirectory.appendingPathComponent("/one/two"), options: options))

        let (foundTestBundle, _) = try XCTUnwrap(testProvider.inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/one/two"), options: .init(
            infoPlistFallbacks: options.infoPlistFallbacks,
            // The test file system has a default base URL and needs different URLs for the symbol graph files
            additionalSymbolGraphFiles: [
                URL(fileURLWithPath: "/path/to/SomethingAdditional.symbols.json")
            ])
        ))

        for (bundle, relativeBase) in [
            (foundPrevImplBundle, tempDirectory.appendingPathComponent("/one/two/three")),
            (foundRealBundle,     tempDirectory.appendingPathComponent("/one/two/three")),
            (foundTestBundle,     URL(fileURLWithPath: "/one/two/three")),
        ] {
            func relativePathString(_ url: URL) -> String {
                url.relative(to: relativeBase)!.path
            }
            
            XCTAssertEqual(bundle.displayName, "CustomDisplayName")
            XCTAssertEqual(bundle.identifier, "com.example.test")
            XCTAssertEqual(bundle.markupURLs.map(relativePathString).sorted(), [
                "Found.docc/CCC.md",
                "Found.docc/Inner/DDD.md",
                "Found.docc/Inner/Nested.docc/EEE.md",
            ])
            XCTAssertEqual(bundle.miscResourceURLs.map(relativePathString).sorted(), [
                "Found.docc/Info.plist",
                "Found.docc/Inner/Info.plist",
                "Found.docc/Inner/header.html",
                "Found.docc/Inner/second.png",
                "Found.docc/first.png",
                "Found.docc/footer.html",
                "Found.docc/theme-settings.json",
            ])
            XCTAssertEqual(bundle.symbolGraphURLs.map(relativePathString).sorted(), [
                "../../../path/to/SomethingAdditional.symbols.json",
                "Found.docc/Inner/SomethingNested.symbols.json",
                "Found.docc/SomethingTopLevel.symbols.json",
            ])
            XCTAssertEqual(bundle.customFooter.map(relativePathString), "Found.docc/footer.html")
            XCTAssertEqual(bundle.customHeader.map(relativePathString), nil)
            XCTAssertEqual(bundle.themeSettings.map(relativePathString), "Found.docc/theme-settings.json")
        }
    }
    
    func testDefaultsToStartingPointWhenAllowingArbitraryDirectories() throws {
        let fileSystem = try TestFileSystem(folders: [
            Folder(name: "one", content: [
                Folder(name: "two", content: [
                    // Start search here.
                    Folder(name: "three", content: [
                        Folder(name: "four", content: []),
                    ]),
                ]),
                // This catalog is outside the provider's search scope
                Folder(name: "OutsideScope.docc", content: []),
            ])
        ])
        
        let provider = DocumentationContext.InputsProvider(fileManager: fileSystem)
        let startingPoint = URL(fileURLWithPath: "/one/two")

        // Allow arbitrary directories as a fallback
        do {
            let (foundInputs, _) = try provider.inputsAndDataProvider(
                startingPoint: startingPoint,
                allowArbitraryCatalogDirectories: true,
                options: .init()
            )
            XCTAssertEqual(foundInputs.displayName, "two")
            XCTAssertEqual(foundInputs.id, "two")
        }
        
        // Without arbitrary directories as a fallback
        do {
            XCTAssertThrowsError(try provider.inputsAndDataProvider(
                startingPoint: startingPoint,
                allowArbitraryCatalogDirectories: false,
                options: .init()
            )) { error in
                XCTAssertEqual(error.localizedDescription, """
                The information provided as command line arguments isn't enough to generate documentation.
                
                The `<catalog-path>` positional argument '/one/two' isn't a documentation catalog (`.docc` directory) \
                and its directory sub-hierarchy doesn't contain a documentation catalog (`.docc` directory).
                
                To build documentation for the files in '/one/two', either give it a `.docc` file extension to make \
                it a documentation catalog or pass the `--allow-arbitrary-catalog-directories` flag to treat it as \
                a documentation catalog, regardless of file extension.
                
                To build documentation using only in-source documentation comments, pass a directory of symbol graph \
                files (with a `.symbols.json` file extension) for the `--additional-symbol-graph-dir` argument.
                """)
            }
        }
    }
    
    func testRaisesErrorWhenFindingMultipleCatalogs() throws {
        let fileSystem = try TestFileSystem(folders: [
            Folder(name: "one", content: [
                Folder(name: "two", content: [
                    // Start search here.
                    Folder(name: "three", content: [
                        Folder(name: "four.docc", content: []),
                    ]),
                    Folder(name: "five.docc", content: []),
                ]),
            ])
        ])
        
        
        let provider = DocumentationContext.InputsProvider(fileManager: fileSystem)
        
        XCTAssertThrowsError(
            try provider.inputsAndDataProvider(
                startingPoint: URL(fileURLWithPath: "/one/two"),
                options: .init()
            )
        ) { error in
            XCTAssertEqual(error.localizedDescription, """
                Found multiple documentation catalogs in /one/two:
                 - five.docc
                 - three/four.docc
                """
            )
        }
    }

    func testGeneratesInputsFromSymbolGraphWhenThereIsNoCatalog() throws {
        let fileSystem = try TestFileSystem(folders: [
            Folder(name: "one", content: [
                Folder(name: "two", content: [
                    // Start search here.
                    Folder(name: "three", content: [
                        Folder(name: "four", content: []),
                    ]),
                ]),
                // This catalog is outside the provider's search scope
                Folder(name: "OutsideScope.docc", content: []),

            ]),

            Folder(name: "path", content: [
                Folder(name: "to", content: [
                    // The path to this symbol graph file is passed via the options
                    JSONFile(name: "Something.symbols.json", content: makeSymbolGraph(moduleName: "Something")),
                ])
            ])
        ])

        let provider = DocumentationContext.InputsProvider(fileManager: fileSystem)
        let startingPoint = URL(fileURLWithPath: "/one/two")

        let (foundInputs, _) = try provider.inputsAndDataProvider(
            startingPoint: startingPoint,
            options: .init(additionalSymbolGraphFiles: [
                URL(fileURLWithPath: "/path/to/Something.symbols.json")
            ])
        )
        XCTAssertEqual(foundInputs.displayName, "Something")
        XCTAssertEqual(foundInputs.id, "Something")
        XCTAssertEqual(foundInputs.symbolGraphURLs.map(\.path), [
            "/path/to/Something.symbols.json",
        ])
    }
}
