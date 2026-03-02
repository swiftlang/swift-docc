/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Foundation
import SwiftDocC
@testable import DocCTestUtilities

struct TestFileSystemTests {
    @Test
    func noContent() throws {
        let fileSystem = try TestFileSystem(folders: [])
        #expect(fileSystem.currentDirectoryPath == "/")
        #expect(fileSystem.directoryExists(atPath: "/"))
        
        #expect(fileSystem._allFilePaths().sorted() == ["/", "/tmp"], "The root (/) should be the only existing path.")
        #expect(!fileSystem.disableWriting)
    }
    
    @Test
    func initialContent() throws {
        let fileSystem = try TestFileSystem {
            Folder(name: "main") {
                Folder(name: "nested") {
                    TextFile(name: "myfile.txt") { "text" }
                }
            }
            Folder(name: "additional") { /* empty */}
        }
        
        // Verify that all the files and folders exist
        #expect(fileSystem.directoryExists(atPath: "/additional"))
        #expect(fileSystem.directoryExists(atPath: "/main"))
        #expect(fileSystem.fileExists(atPath: "/main/nested/myfile.txt"))
        #expect(!fileSystem.directoryExists(atPath: "/main/nested/myfile.txt"), "Files are not directories")
        #expect(!fileSystem.directoryExists(atPath: "/main/nested/myfile-non-existing.txt"))

        // Verify correct file tree
        #expect(fileSystem.dump() == """
        /
        ├─ additional/
        ├─ main/
        │  ╰─ nested/
        │     ╰─ myfile.txt
        ╰─ tmp/
        """)
    }
    
    @Test(arguments: [1, 2, 11])
    func resultBuilderCapabilities(seed: Int) throws {
        let fileSystem = try TestFileSystem {
            Folder(name: "Always Included") {
                for number in 1...3 {
                    TextFile(name: "File\(number)", { number })
                }
            }
            
            if seed < 10 {
                Folder(name: "Small number") { }
            }
            
            if seed.isMultiple(of: 2) {
                Folder(name: "Even number") { }
            } else {
                Folder(name: "Odd number") { }
            }
            
            switch seed {
            case 2:
                Folder(name: "Exactly 2") { }
            default:
                Folder(name: "Number \(seed)") { }
            }
        }
        
        var expectedDump = """
        /
        ├─ Always Included/
        │  ├─ File1
        │  ├─ File2
        │  ╰─ File3
        """
        
        var otherTopLevelFolders = seed < 10 ? ["Small number"] : []
        if seed == 2 {
            otherTopLevelFolders.append(contentsOf: ["Even number", "Exactly 2"])
        } else {
            otherTopLevelFolders.append(contentsOf: ["Odd number", "Number \(seed)"])
        }
        expectedDump.append(otherTopLevelFolders.sorted().map{ "\n├─ \($0)/" }.joined())
        expectedDump.append("\n╰─ tmp/")
        #expect(fileSystem.dump() == expectedDump)
    }

    private func makeTestFileSystemWithExampleStructure() throws -> TestFileSystem {
        try TestFileSystem {
            Folder(name: "main") {
                Folder(name: "nested") {
                    for number in 1...2 {
                        TextFile(name: "myfile\(number).txt") { "text" }
                    }
                }
            }
        }
    }
    
    @Test
    func dumpSubpath() throws {
        let fileSystem = try makeTestFileSystemWithExampleStructure()
        #expect(fileSystem.dump() == """
        /
        ├─ main/
        │  ╰─ nested/
        │     ├─ myfile1.txt
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)
        
        #expect(fileSystem.dump(subHierarchyFrom: "/main") == """
        main/
        ╰─ nested/
           ├─ myfile1.txt
           ╰─ myfile2.txt
        """)
        
        #expect(fileSystem.dump(subHierarchyFrom: "/main/nested") == """
        nested/
        ├─ myfile1.txt
        ╰─ myfile2.txt
        """)
    }
    
    @Test
    func copyFiles() throws {
        let fileSystem = try makeTestFileSystemWithExampleStructure()
        
        try fileSystem._copyItem(at: URL(fileURLWithPath: "/main/nested/myfile1.txt"), to: URL(fileURLWithPath: "/main/myfile1.txt"))
        #expect(fileSystem.dump() == """
        /
        ├─ main/
        │  ├─ myfile1.txt
        │  ╰─ nested/
        │     ├─ myfile1.txt
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)
    }

    @Test
    func copyFolders() throws {
        let fileSystem = try makeTestFileSystemWithExampleStructure()
        
        try fileSystem._copyItem(at: URL(fileURLWithPath: "/main/nested"), to: URL(fileURLWithPath: "/copy"))
        #expect(fileSystem.dump() == """
        /
        ├─ copy/
        │  ├─ myfile1.txt
        │  ╰─ myfile2.txt
        ├─ main/
        │  ╰─ nested/
        │     ├─ myfile1.txt
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)
        
        let filesIterator = fileSystem.recursiveFiles(startingPoint: URL(fileURLWithPath: "/"))
        #expect(filesIterator.prefix(2).map(\.path).sorted() == [
            // Shallow files first
            "/copy/myfile1.txt",
            "/copy/myfile2.txt",
        ])
        #expect(filesIterator.dropFirst(2).map(\.path).sorted() == [
            // Deeper files after
            "/main/nested/myfile1.txt",
            "/main/nested/myfile2.txt",
        ])
    }

    @Test
    func moveFiles() throws {
        let fileSystem = try makeTestFileSystemWithExampleStructure()
        
        try fileSystem.moveItem(at: URL(fileURLWithPath: "/main/nested/myfile1.txt"), to: URL(fileURLWithPath: "/main/myfile1.txt"))
        #expect(fileSystem.dump() == """
        /
        ├─ main/
        │  ├─ myfile1.txt
        │  ╰─ nested/
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)
    }
    
    @Test
    func moveFolders() throws {
        let fileSystem = try makeTestFileSystemWithExampleStructure()
        
        try fileSystem.moveItem(at: URL(fileURLWithPath: "/main/nested"), to: URL(fileURLWithPath: "/main/new"))
        #expect(fileSystem.dump() == """
        /
        ├─ main/
        │  ╰─ new/
        │     ├─ myfile1.txt
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)
    }
    
    @Test
    func removeFiles() throws {
        let fileSystem = try makeTestFileSystemWithExampleStructure()
        
        try fileSystem.removeItem(at: URL(fileURLWithPath: "/main/nested/myfile1.txt"))
        #expect(fileSystem.dump() == """
        /
        ├─ main/
        │  ╰─ nested/
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)
        
        #expect(fileSystem.recursiveFiles(startingPoint: URL(fileURLWithPath: "/")).map(\.lastPathComponent) == [
            "myfile2.txt",
        ])
    }
    
    @Test
    func removeFolders() throws {
        let fileSystem = try makeTestFileSystemWithExampleStructure()
        
        try fileSystem.removeItem(at: URL(fileURLWithPath: "/main/nested"))
        #expect(fileSystem.dump() == """
        /
        ├─ main/
        ╰─ tmp/
        """)
    }

    @Test
    func createFiles() throws {
        let fileSystem = try makeTestFileSystemWithExampleStructure()

        // Test creating a non-empty file
        try fileSystem.createFile(at: URL(fileURLWithPath:"/test.txt"), contents: "12345".data(using: .utf8)!)
        #expect(fileSystem.contents(atPath: "/test.txt")?.count == 5)
    }
    
    @Test
    func createFolders() throws {
        let fileSystem = try makeTestFileSystemWithExampleStructure()
        
        try fileSystem.createDirectory(at: URL(fileURLWithPath: "/main/nested/inner"), withIntermediateDirectories: false)
        #expect(fileSystem.dump() == """
        /
        ├─ main/
        │  ╰─ nested/
        │     ├─ inner/
        │     ├─ myfile1.txt
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)

        try fileSystem.createDirectory(at: URL(fileURLWithPath: "/main/nested/inner2"), withIntermediateDirectories: true)
        #expect(fileSystem.dump() == """
        /
        ├─ main/
        │  ╰─ nested/
        │     ├─ inner/
        │     ├─ inner2/
        │     ├─ myfile1.txt
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)

        // Test it throws when parent folder is missing
        do {
            try fileSystem.createDirectory(at: URL(fileURLWithPath: "/main/nested/missing/inner4"), withIntermediateDirectories: false)
            Issue.record("Did not raise error ")
        } catch {
            //
        }
        
        // Test it creates missing parent folders
        try fileSystem.createDirectory(at: URL(fileURLWithPath: "/main/nested/missing/inner4"), withIntermediateDirectories: true)
        #expect(fileSystem.dump() == """
        /
        ├─ main/
        │  ╰─ nested/
        │     ├─ inner/
        │     ├─ inner2/
        │     ├─ missing/
        │     │  ╰─ inner4/
        │     ├─ myfile1.txt
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)
        
        #expect(fileSystem.recursiveFiles(startingPoint: URL(fileURLWithPath: "/")).map(\.lastPathComponent).sorted() == [
            "myfile1.txt", "myfile2.txt",
        ])
    }
    
    @Test
    func createDeeplyNestedDirectory() throws {
        let fileSystem = try TestFileSystem(folders: [])

        // Test if creates deeply nested directory structure
        try fileSystem.createDirectory(at: URL(fileURLWithPath: "/one/two/three/four/five/six"), withIntermediateDirectories: true)
        
        #expect(fileSystem.dump() == """
        /
        ├─ one/
        │  ╰─ two/
        │     ╰─ three/
        │        ╰─ four/
        │           ╰─ five/
        │              ╰─ six/
        ╰─ tmp/
        """)
        
        #expect(fileSystem.recursiveFiles(startingPoint: URL(fileURLWithPath: "/")).map(\.lastPathComponent) == [], "Only directories. No files.")
    }
    
    @Test
    func fileExists() throws {
        let fileSystem = try makeTestFileSystemWithExampleStructure()
        
        #expect(fileSystem.fileExists(atPath: "/"))
        #expect(fileSystem.fileExists(atPath: "/main"))
        #expect(fileSystem.fileExists(atPath: "/main/nested/myfile1.txt"))
        
        #expect(fileSystem.directoryExists(atPath: "/main"))
        #expect(fileSystem.directoryExists(atPath: "/main/nested"))
        
        #expect(!fileSystem.fileExists(atPath: "/missing"))
        #expect(!fileSystem.fileExists(atPath: "/main/nested/myfile3.txt"))
    }
    
    @Test
    func readingFileContents() throws {
        let fileSystem = try makeTestFileSystemWithExampleStructure()

        // Test it fails to write to incorrect paths
        do {
            try fileSystem.createFile(at: URL(string:"/main/missing/test.txt")!, contents: Data(base64Encoded: "TEST")!)
            Issue.record("Did not raise error ")
        } catch {
            //
        }

        // Test it returns `nil` for not existing file paths
        #expect(fileSystem.contents(atPath: "/\\//asdsj//fm--")       == nil)
        #expect(fileSystem.contents(atPath: "/main/missing/test.txt") == nil)
        #expect(fileSystem.contents(atPath: "/main/missingFile.txt")  == nil)
        
        // Test it writes a file and reads it back
        try fileSystem.createFile(at: URL(string:"/main/test.txt")!, contents: Data(base64Encoded: "TEST")!)
        #expect(fileSystem.contents(atPath: "/main/test.txt") == Data(base64Encoded: "TEST"))
        
        // Copy a file and test the contents are identical with original
        try fileSystem._copyItem(at: URL(string: "/main/test.txt")!, to: URL(string: "/main/clone.txt")!)
        #expect(fileSystem.contentsEqual(atPath: "/main/test.txt", andPath: "/main/clone.txt"))
        
        _ = try fileSystem.createFile(at: URL(string:"/main/notclone.txt")!, contents: Data(base64Encoded: "TESTTEST")!)
        #expect(!fileSystem.contentsEqual(atPath: "/main/test.txt", andPath: "/main/notclone.txt"))
        #expect(!fileSystem.contentsEqual(atPath: "/main/test.txt", andPath: "/main/missing.txt"))
    }
    
    @Test
    func testBundleUsesFileURLs() throws {
        let fileSystem = try TestFileSystem {
            // A docc catalog with an article, a resource, an Info.plist file, and a symbol graph file
            Folder(name: "something.docc") {
                TextFile(name: "article.md", utf8Content: "")
                DataFile(name: "image.png", data: Data())
                InfoPlist(displayName: "unit-test", identifier: "com.example")
                JSONFile(symbolGraph: makeSymbolGraph(moduleName: "Something"))
            }
        }
        
        let (inputs, _) = try DocumentationContext.InputsProvider(fileManager: fileSystem)
            .inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/"), options: .init())
        
        #expect(inputs.markupURLs.map(\.lastPathComponent).sorted()       == ["article.md"])
        #expect(inputs.miscResourceURLs.map(\.lastPathComponent).sorted() == ["Info.plist", "image.png"])
        #expect(inputs.symbolGraphURLs.map(\.lastPathComponent).sorted()  == ["Something.symbols.json"])
        
        #expect(inputs.markupURLs.allSatisfy { $0.isFileURL })
        #expect(inputs.miscResourceURLs.allSatisfy { $0.isFileURL })
        #expect(inputs.symbolGraphURLs.allSatisfy { $0.isFileURL })
    }
    
    @Test(arguments: [true, false])
    func discoverInputs(withInfoPlistInCatalog: Bool) throws {
        let fileSystem = try TestFileSystem {
            Folder(name: "CatalogName.docc") {
                if withInfoPlistInCatalog {
                    InfoPlist(displayName: "DisplayName", identifier: "com.example")
                }
                JSONFile(symbolGraph: makeSymbolGraph(moduleName: "Something"))
            }
        }
        let (inputs, _) = try DocumentationContext.InputsProvider(fileManager: fileSystem)
            .inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/"), options: .init())
        
        if withInfoPlistInCatalog {
            #expect(inputs.displayName == "DisplayName", "Display name is read from Info.plist")
            #expect(inputs.id == "com.example", "Identifier is read from Info.plist")
        } else {
            #expect(inputs.displayName == "CatalogName", "Display name is derived from catalog name")
            #expect(inputs.id == "CatalogName", "Identifier is derived the display name")
        }
    }
}
