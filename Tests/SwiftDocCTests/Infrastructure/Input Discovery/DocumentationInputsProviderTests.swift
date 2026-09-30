/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Foundation
import DocCTestUtilities
@testable import SwiftDocC

struct DocumentationInputsProviderTests {
    enum FileSystemUnderTest: CaseIterable, CustomTestStringConvertible {
        case onDisk
        case inMemory

        var testDescription: String {
            switch self {
            case .onDisk:   "on-disk file system"
            case .inMemory: "in-memory file system"
            }
        }
    }

    @Test(arguments: FileSystemUnderTest.allCases)
    func discoversAndCategorizesAllCatalogInputs(_ fileSystem: FileSystemUnderTest) throws {
        let folderHierarchy = Folder(name: "one", content: [
            Folder(name: "two", content: [
                // Start search here.
                TextFile(name: "AAA.md", utf8Content: ""),

                Folder(name: "three", content: [
                    TextFile(name: "BBB.md", utf8Content: ""),

                    // This is the catalog that both file systems should find
                    Folder(name: "Found.docc", content: [
                        // This top-level Info.plist will be read for input's information
                        InfoPlist(displayName: "CustomDisplayName"),

                        // These top-level files will be treated as a custom footer, custom theme, and custom favicon
                        TextFile(name: "footer.html", utf8Content: ""),
                        TextFile(name: "theme-settings.json", utf8Content: ""),
                        DataFile(name: "favicon.ico", data: Data()),

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

        let baseDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("TempDirectory-\(ProcessInfo.processInfo.globallyUniqueString)")

        let fileManager: any FileManagerProtocol
        switch fileSystem {
        case .onDisk:
            try Folder(name: baseDirectory.lastPathComponent, content: [folderHierarchy]).write(to: baseDirectory)
            fileManager = FileManager.default
        case .inMemory:
            let testFileSystem = try TestFileSystem(folders: [])
            try testFileSystem.addFolder(folderHierarchy, basePath: baseDirectory)
            fileManager = testFileSystem
        }
        defer { try? FileManager.default.removeItem(at: baseDirectory) }  // No-op for in-memory filesystem

        let inputsProvider = DocumentationContext.InputsProvider(fileManager: fileManager)
        let options = CatalogDiscoveryOptions(fallbackIdentifier: "com.example.test", additionalSymbolGraphFiles: [
            baseDirectory.appendingPathComponent("/path/to/SomethingAdditional.symbols.json")
        ])
        let (inputs, _) = try inputsProvider.inputsAndDataProvider(startingPoint: baseDirectory.appendingPathComponent("/one/two"), options: options)

        func relativePathString(_ url: URL) -> String {
            url.relative(to: baseDirectory.appendingPathComponent("/one/two/three"))!.path
        }

        #expect(inputs.displayName == "CustomDisplayName")
        #expect(inputs.id == "com.example.test")
        #expect(inputs.markupURLs.map(relativePathString).sorted() == [
            "Found.docc/CCC.md",
            "Found.docc/Inner/DDD.md",
            "Found.docc/Inner/Nested.docc/EEE.md",
        ])
        #expect(inputs.miscResourceURLs.map(relativePathString).sorted() == [
            "Found.docc/Info.plist",
            "Found.docc/Inner/Info.plist",
            "Found.docc/Inner/header.html",
            "Found.docc/Inner/second.png",
            "Found.docc/favicon.ico",
            "Found.docc/first.png",
            "Found.docc/footer.html",
            "Found.docc/theme-settings.json",
        ])
        #expect(inputs.symbolGraphURLs.map(relativePathString).sorted() == [
            "../../../path/to/SomethingAdditional.symbols.json",
            "Found.docc/Inner/SomethingNested.symbols.json",
            "Found.docc/SomethingTopLevel.symbols.json",
        ])
        #expect(inputs.customFooter.map(relativePathString) == "Found.docc/footer.html")
        #expect(inputs.customHeader.map(relativePathString) == nil)
        #expect(inputs.themeSettings.map(relativePathString) == "Found.docc/theme-settings.json")
        #expect(inputs.customFavicon.map(relativePathString) == "Found.docc/favicon.ico")
    }

    @Test
    func treatsStartingPointAsCatalogWhenAllowingArbitraryDirectories() throws {
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

        let (foundInputs, _) = try provider.inputsAndDataProvider(
            startingPoint: URL(fileURLWithPath: "/one/two"),
            allowArbitraryCatalogDirectories: true,
            options: .init()
        )
        #expect(foundInputs.displayName == "two")
        #expect(foundInputs.id == "two")
    }

    @Test
    func raisesErrorWhenStartingPointIsNotACatalogAndArbitraryDirectoriesDisallowed() throws {
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

        let error = #expect(throws: (any Error).self) {
            try provider.inputsAndDataProvider(
                startingPoint: URL(fileURLWithPath: "/one/two"),
                allowArbitraryCatalogDirectories: false,
                options: .init()
            )
        }
        #expect(error?.localizedDescription == """
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

    @Test
    func raisesErrorWhenFindingMultipleCatalogs() throws {
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

        let error = #expect(throws: (any Error).self) {
            try provider.inputsAndDataProvider(
                startingPoint: URL(fileURLWithPath: "/one/two"),
                options: .init()
            )
        }
        #expect(error?.localizedDescription == """
        Found multiple documentation catalogs in /one/two:
         - five.docc
         - three/four.docc
        """)
    }

    @Test
    func generatesInputsFromSymbolGraphWhenThereIsNoCatalog() throws {
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

        let (foundInputs, _) = try provider.inputsAndDataProvider(
            startingPoint: URL(fileURLWithPath: "/one/two"),
            options: .init(additionalSymbolGraphFiles: [
                URL(fileURLWithPath: "/path/to/Something.symbols.json")
            ])
        )
        #expect(foundInputs.displayName == "Something")
        #expect(foundInputs.id == "Something")
        #expect(foundInputs.symbolGraphURLs.map(\.path) == [
            "/path/to/Something.symbols.json",
        ])
    }
}
