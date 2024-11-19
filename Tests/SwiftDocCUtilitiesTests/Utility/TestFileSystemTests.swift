/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SwiftDocC
@testable import SwiftDocCTestUtilities

class TestFileSystemTests: XCTestCase {
    
    func testEmpty() throws {
        let fs = try TestFileSystem(folders: [])
        XCTAssertEqual(fs.currentDirectoryPath, "/")
        var isDirectory = ObjCBool(false)
        XCTAssertTrue(fs.fileExists(atPath: "/", isDirectory: &isDirectory))
        XCTAssertEqual(fs.files.keys.sorted(), ["/", "/tmp"], "The root (/) should be the only existing path.")
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertFalse(fs.disableWriting)
    }
    
    func testInitialContentMultipleFolders() throws {
        let folder1 = Folder(name: "main", content: [
            Folder(name: "nested", content: [
                TextFile(name: "myfile.txt", utf8Content: "text"),
            ]),
        ])
        let folder2 = Folder(name: "additional", content: [])
        
        let fs = try TestFileSystem(folders: [folder1, folder2])
        
        // Verify correct folders & files
        var isDirectory = ObjCBool(false)
        XCTAssertTrue(fs.fileExists(atPath: "/additional", isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertTrue(fs.fileExists(atPath: "/main", isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertTrue(fs.fileExists(atPath: "/main/nested/myfile.txt", isDirectory: &isDirectory))
        XCTAssertFalse(isDirectory.boolValue)
        XCTAssertFalse(fs.fileExists(atPath: "/main/nested/myfile-non-existing.txt", isDirectory: &isDirectory))
        XCTAssertFalse(isDirectory.boolValue)

        // Verify correct file tree
        XCTAssertEqual(fs.dump(), """
        /
        ├─ additional/
        ├─ main/
        │  ╰─ nested/
        │     ╰─ myfile.txt
        ╰─ tmp/
        """)
    }

    private func makeTestFS() throws -> TestFileSystem {
        let folder = Folder(name: "main", content: [
            Folder(name: "nested", content: [
                TextFile(name: "myfile1.txt", utf8Content: "text"),
                TextFile(name: "myfile2.txt", utf8Content: "text"),
            ])
        ])
        
        let fs = try TestFileSystem(folders: [folder])
        
        XCTAssertEqual(fs.dump(), """
        /
        ├─ main/
        │  ╰─ nested/
        │     ├─ myfile1.txt
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)

        return fs
    }
    
    func testDumpSubpath() throws {
        let fs = try makeTestFS()
        XCTAssertEqual(fs.dump(), """
        /
        ├─ main/
        │  ╰─ nested/
        │     ├─ myfile1.txt
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)
        
        XCTAssertEqual(fs.dump(subHierarchyFrom: "/main"), """
        main/
        ╰─ nested/
           ├─ myfile1.txt
           ╰─ myfile2.txt
        """)
        
        XCTAssertEqual(fs.dump(subHierarchyFrom: "/main/nested"), """
        nested/
        ├─ myfile1.txt
        ╰─ myfile2.txt
        """)
    }
    
    func testCopyFiles() throws {
        let fs = try makeTestFS()
        
        try fs.copyItem(at: URL(string: "/main/nested/myfile1.txt")!, to: URL(string: "/main/myfile1.txt")!)
        XCTAssertEqual(fs.dump(), """
        /
        ├─ main/
        │  ├─ myfile1.txt
        │  ╰─ nested/
        │     ├─ myfile1.txt
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)
    }

    func testCopyFolders() throws {
        let fs = try makeTestFS()
        
        try fs.copyItem(at: URL(string: "/main/nested")!, to: URL(string: "/copy")!)
        XCTAssertEqual(fs.dump(), """
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
    }

    
    func testMoveFiles() throws {
        let fs = try makeTestFS()
        
        try fs.moveItem(at: URL(string: "/main/nested/myfile1.txt")!, to: URL(string: "/main/myfile1.txt")!)
        XCTAssertEqual(fs.dump(), """
        /
        ├─ main/
        │  ├─ myfile1.txt
        │  ╰─ nested/
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)
    }

    func testMoveFolders() throws {
        let fs = try makeTestFS()
        
        try fs.moveItem(at: URL(string: "/main/nested")!, to: URL(string: "/main/new")!)
        XCTAssertEqual(fs.dump(), """
        /
        ├─ main/
        │  ╰─ new/
        │     ├─ myfile1.txt
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)
    }
    
    func testRemoveFiles() throws {
        let fs = try makeTestFS()
        
        try fs.removeItem(at: URL(string: "/main/nested/myfile1.txt")!)
        XCTAssertEqual(fs.dump(), """
        /
        ├─ main/
        │  ╰─ nested/
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)
    }

    func testRemoveFolders() throws {
        let fs = try makeTestFS()
        
        try fs.removeItem(at: URL(string: "/main/nested")!)
        XCTAssertEqual(fs.dump(), """
        /
        ├─ main/
        ╰─ tmp/
        """)
    }

    func testCreateFiles() throws {
        let fs = try makeTestFS()

        // Test creating a non-empty file
        XCTAssertNoThrow(try fs.createFile(at: URL(string:"/test.txt")!, contents: "12345".data(using: .utf8)!))
        XCTAssertEqual(fs.contents(atPath: "/test.txt")?.count, 5)
    }
    
    func testCreateFolders() throws {
        let fs = try makeTestFS()
        
        try fs.createDirectory(at: URL(string: "/main/nested/inner")!, withIntermediateDirectories: false)
        XCTAssertEqual(fs.dump(), """
        /
        ├─ main/
        │  ╰─ nested/
        │     ├─ inner/
        │     ├─ myfile1.txt
        │     ╰─ myfile2.txt
        ╰─ tmp/
        """)

        try fs.createDirectory(at: URL(string: "/main/nested/inner2")!, withIntermediateDirectories: true)
        XCTAssertEqual(fs.dump(), """
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
        XCTAssertThrowsError(try fs.createDirectory(at: URL(string: "/main/nested/missing/inner4")!, withIntermediateDirectories: false))
        
        // Test it creates missing parent folders
        try fs.createDirectory(at: URL(string: "/main/nested/missing/inner4")!, withIntermediateDirectories: true)
        XCTAssertEqual(fs.dump(), """
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
    }
    
    func testCreateDeeplyNestedDirectory() throws {
        let fs = try TestFileSystem(folders: [])

        // Test if creates deeply nested directory structure
        try fs.createDirectory(at: URL(string: "/one/two/three/four/five/six")!, withIntermediateDirectories: true)
        
        XCTAssertEqual(fs.dump(), """
        /
        ├─ one/
        │  ╰─ two/
        │     ╰─ three/
        │        ╰─ four/
        │           ╰─ five/
        │              ╰─ six/
        ╰─ tmp/
        """)
    }
    
    func testFileExists() throws {
        let fs = try makeTestFS()
        
        XCTAssertTrue(fs.fileExists(atPath: "/"))
        XCTAssertTrue(fs.fileExists(atPath: "/main"))
        XCTAssertTrue(fs.fileExists(atPath: "/main/nested/myfile1.txt"))
        
        XCTAssertFalse(fs.fileExists(atPath: "/missing"))
        XCTAssertFalse(fs.fileExists(atPath: "/main/nested/myfile3.txt"))
    }
    
    func testFileContents() throws {
        let fs = try makeTestFS()

        // Test it fails to write to incorrect paths
        XCTAssertThrowsError(try fs.createFile(at: URL(string:"/main/missing/test.txt")!, contents: Data(base64Encoded: "TEST")!))

        // Test it returns `nil` for not existing file paths
        XCTAssertNil(fs.contents(atPath: "/\\//asdsj//fm--"))
        XCTAssertNil(fs.contents(atPath: "/main/missing/test.txt"))
        XCTAssertNil(fs.contents(atPath: "/main/missingFile.txt"))
        
        // Test it writes a file and reads it back
        XCTAssertNoThrow(try fs.createFile(at: URL(string:"/main/test.txt")!, contents: Data(base64Encoded: "TEST")!))
        XCTAssertEqual(fs.contents(atPath: "/main/test.txt"), Data(base64Encoded: "TEST"))
        
        // Copy a file and test the contents are identical with original
        try fs.copyItem(at: URL(string: "/main/test.txt")!, to: URL(string: "/main/clone.txt")!)
        XCTAssertTrue(fs.contentsEqual(atPath: "/main/test.txt", andPath: "/main/clone.txt"))
        
        _ = try fs.createFile(at: URL(string:"/main/notclone.txt")!, contents: Data(base64Encoded: "TESTTEST")!)
        XCTAssertFalse(fs.contentsEqual(atPath: "/main/test.txt", andPath: "/main/notclone.txt"))
        XCTAssertFalse(fs.contentsEqual(atPath: "/main/test.txt", andPath: "/main/missing.txt"))
    }
    
    func testBundleUsesFileURLs() throws {
        let emptySymbolGraphData = try JSONEncoder().encode(makeSymbolGraph(moduleName: "Something"))
        
        // A docc catalog with an article, a resource, an Info.plist file, and a symbol graph file
        let folders = Folder(name: "something.docc", content: [
            TextFile(name: "article.md", utf8Content: ""),
            DataFile(name: "image.png", data: Data()),
            InfoPlist(displayName: "unit-test", identifier: "com.example"),
            DataFile(name: "Something.symbols.json", data: emptySymbolGraphData)
        ])
        let fs = try TestFileSystem(folders: [folders])
        
        let (bundle, _) = try DocumentationContext.InputsProvider(fileManager: fs)
            .inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/"), options: .init())
        
        XCTAssertFalse(bundle.markupURLs.isEmpty)
        XCTAssertFalse(bundle.miscResourceURLs.isEmpty)
        XCTAssertFalse(bundle.symbolGraphURLs.isEmpty)
        
        XCTAssert(bundle.markupURLs.allSatisfy(\.isFileURL))
        XCTAssert(bundle.miscResourceURLs.allSatisfy(\.isFileURL))
        XCTAssert(bundle.symbolGraphURLs.allSatisfy(\.isFileURL))
    }
    
    func testBundleDiscovery() throws {
        let somethingSymbolGraphData = try JSONEncoder().encode(makeSymbolGraph(moduleName: "Something"))
        
        do {
            let fs = try TestFileSystem(folders: [
                Folder(name: "CatalogName.docc", content: [
                    InfoPlist(displayName: "DisplayName", identifier: "com.example"),
                    DataFile(name: "Something.symbols.json", data: somethingSymbolGraphData),
                ])
            ])
            let (bundle, _) = try DocumentationContext.InputsProvider(fileManager: fs)
                .inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/"), options: .init())
            XCTAssertEqual(bundle.displayName, "DisplayName", "Display name is read from Info.plist")
            XCTAssertEqual(bundle.identifier, "com.example", "Identifier is read from Info.plist")
        }
         
        do {
            let fs = try TestFileSystem(folders: [
                Folder(name: "CatalogName.docc", content: [
                    // No Info.plist
                    DataFile(name: "Something.symbols.json", data: somethingSymbolGraphData),
                ])
            ])
            let (bundle, _) = try DocumentationContext.InputsProvider(fileManager: fs)
                .inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/"), options: .init())
            XCTAssertEqual(bundle.displayName, "CatalogName", "Display name is derived from catalog name")
            XCTAssertEqual(bundle.displayName, "CatalogName", "Identifier is derived the display name")
        }
    }
}
