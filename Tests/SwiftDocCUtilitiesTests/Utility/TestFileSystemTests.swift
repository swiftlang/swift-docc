/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
@testable import SwiftDocCUtilities
import SwiftDocCTestUtilities

class TestFileSystemTests: XCTestCase {
    
    func testEmpty() throws {
        let fs = try TestFileSystem(folders: [])
        XCTAssertEqual(fs.currentDirectoryPath, "/")
        XCTAssertFalse(fs.identifier.isEmpty)
        XCTAssertTrue(try fs.bundles().isEmpty)
        var isDirectory = ObjCBool(false)
        XCTAssertTrue(fs.fileExists(atPath: "/", isDirectory: &isDirectory))
        XCTAssertEqual(fs.files.keys.sorted(), ["/"], "The root (/) should be the only existing path.")
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
        /additional
        /main
        /main/nested
        /main/nested/myfile.txt
        """)
    }

    func makeTestFS() throws -> TestFileSystem {
        let folder = Folder(name: "main", content: [
            Folder(name: "nested", content: [
                TextFile(name: "myfile1.txt", utf8Content: "text"),
                TextFile(name: "myfile2.txt", utf8Content: "text"),
            ])
        ])
        
        let fs = try TestFileSystem(folders: [folder])
        
        XCTAssertEqual(fs.dump(), """
        /
        /main
        /main/nested
        /main/nested/myfile1.txt
        /main/nested/myfile2.txt
        """)

        return fs
    }
    
    func testCopyFiles() throws {
        let fs = try makeTestFS()
        
        try fs.copyItem(at: URL(string: "/main/nested/myfile1.txt")!, to: URL(string: "/main/myfile1.txt")!)
        XCTAssertEqual(fs.dump(), """
        /
        /main
        /main/myfile1.txt
        /main/nested
        /main/nested/myfile1.txt
        /main/nested/myfile2.txt
        """)
    }

    func testCopyFolders() throws {
        let fs = try makeTestFS()
        
        try fs.copyItem(at: URL(string: "/main/nested")!, to: URL(string: "/copy")!)
        XCTAssertEqual(fs.dump(), """
        /
        /copy
        /copy/myfile1.txt
        /copy/myfile2.txt
        /main
        /main/nested
        /main/nested/myfile1.txt
        /main/nested/myfile2.txt
        """)
    }

    
    func testMoveFiles() throws {
        let fs = try makeTestFS()
        
        try fs.moveItem(at: URL(string: "/main/nested/myfile1.txt")!, to: URL(string: "/main/myfile1.txt")!)
        XCTAssertEqual(fs.dump(), """
        /
        /main
        /main/myfile1.txt
        /main/nested
        /main/nested/myfile2.txt
        """)
    }

    func testMoveFolders() throws {
        let fs = try makeTestFS()
        
        try fs.moveItem(at: URL(string: "/main/nested")!, to: URL(string: "/main/new")!)
        XCTAssertEqual(fs.dump(), """
        /
        /main
        /main/new
        /main/new/myfile1.txt
        /main/new/myfile2.txt
        """)
    }
    
    func testRemoveFiles() throws {
        let fs = try makeTestFS()
        
        try fs.removeItem(at: URL(string: "/main/nested/myfile1.txt")!)
        XCTAssertEqual(fs.dump(), """
        /
        /main
        /main/nested
        /main/nested/myfile2.txt
        """)
    }

    func testRemoveFolders() throws {
        let fs = try makeTestFS()
        
        try fs.removeItem(at: URL(string: "/main/nested")!)
        XCTAssertEqual(fs.dump(), """
        /
        /main
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
        /main
        /main/nested
        /main/nested/inner
        /main/nested/myfile1.txt
        /main/nested/myfile2.txt
        """)

        try fs.createDirectory(at: URL(string: "/main/nested/inner2")!, withIntermediateDirectories: true)
        XCTAssertEqual(fs.dump(), """
        /
        /main
        /main/nested
        /main/nested/inner
        /main/nested/inner2
        /main/nested/myfile1.txt
        /main/nested/myfile2.txt
        """)

        // Test it throws when parent folder is missing
        XCTAssertThrowsError(try fs.createDirectory(at: URL(string: "/main/nested/missing/inner4")!, withIntermediateDirectories: false))
        
        // Test it creates missing parent folders
        try fs.createDirectory(at: URL(string: "/main/nested/missing/inner4")!, withIntermediateDirectories: true)
        XCTAssertEqual(fs.dump(), """
        /
        /main
        /main/nested
        /main/nested/inner
        /main/nested/inner2
        /main/nested/missing
        /main/nested/missing/inner4
        /main/nested/myfile1.txt
        /main/nested/myfile2.txt
        """)
    }
    
    func testCreateDeeplyNestedDirectory() throws {
        let fs = try TestFileSystem(folders: [])

        // Test if creates deeply nested directory structure
        try fs.createDirectory(at: URL(string: "/one/two/three/four/five/six")!, withIntermediateDirectories: true)
        
        XCTAssertEqual(fs.dump(), """
        /
        /one
        /one/two
        /one/two/three
        /one/two/three/four
        /one/two/three/four/five
        /one/two/three/four/five/six
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
}
