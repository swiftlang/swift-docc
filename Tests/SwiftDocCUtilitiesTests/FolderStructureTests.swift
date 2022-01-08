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

class FolderStructureTests: XCTestCase {

    func testWritingFile() throws {
        let tempFolder = try createTemporaryDirectory()
        let file = TextFile(name: "test.txt", utf8Content: "Lorem ipsum")
        let textFileURL = try file.write(inside: tempFolder)
        
        file.assertExist(at: textFileURL)
        
        XCTAssertEqual(textFileURL.lastPathComponent, file.name)
        XCTAssert(FileManager.default.fileExists(atPath: textFileURL.path))
        XCTAssertEqual(try String(contentsOf: textFileURL), file.utf8Content)
    }

    func testWritingFolder() throws {
        let tempFolder = try createTemporaryDirectory()
        let folder = Folder(name: "Empty folder", content: [])
        let folderURL = try folder.write(inside: tempFolder)
        
        folder.assertExist(at: folderURL)
        
        XCTAssertEqual(folderURL.lastPathComponent, folder.name)
        var isFolder: ObjCBool = false
        XCTAssert(FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isFolder))
        XCTAssert(isFolder.boolValue)
    }
    
    func testWritingFolderHierarchy() throws {
        let tempFolder = try createTemporaryDirectory()
        let folder = Folder(name: "A", content: [
            Folder(name: "B1", content: []),
            Folder(name: "B2", content: [
                Folder(name: "C", content: [
                    TextFile(name: "test.txt", utf8Content: "Lorem ipsum"),
                ]),
            ]),
        ])
        let folderURL = try folder.write(inside: tempFolder)
        
        folder.assertExist(at: folderURL)
        
        let emptySubFolderLocation = folderURL.appendingPathComponent("B1")
        var isFolder: ObjCBool = false
        XCTAssert(FileManager.default.fileExists(atPath: emptySubFolderLocation.path, isDirectory: &isFolder))
        XCTAssert(isFolder.boolValue)
        
        let textFileURL = folderURL
            .appendingPathComponent("B2")
            .appendingPathComponent("C")
            .appendingPathComponent("test.txt")
        
        XCTAssert(FileManager.default.fileExists(atPath: textFileURL.path))
        XCTAssertEqual(try String(contentsOf: textFileURL), "Lorem ipsum")
    }
    
    func testVerifyingPartialFolderHierarchy() throws {
        let tempFolder = try createTemporaryDirectory()
        let completeFolderHierarchy = Folder(name: "A", content: [
            Folder(name: "B1", content: []),
            Folder(name: "B2", content: [
                Folder(name: "C1", content: []),
                Folder(name: "C2", content: []),
            ])
        ])
        let folderURL = try completeFolderHierarchy.write(inside: tempFolder)
        
        completeFolderHierarchy.assertExist(at: folderURL)
        
        let partialFolderHierarchy = Folder(name: "A", content: [
            Folder(name: "B2", content: [
                Folder(name: "C1", content: []),
            ])
        ])
        partialFolderHierarchy.assertExist(at: folderURL)
    }
    
    func testCopyingFolder() throws {
        let tempFolder = try createTemporaryDirectory()
        let exampleFolder = Folder(name: "A", content: [
            TextFile(name: "UPPER", utf8Content: ""),
            TextFile(name: "lower", utf8Content: ""),
        ])
        let folderURL = try exampleFolder.write(inside: tempFolder)
        
        let copyWithOnlyUppercaseFiles = CopyOfFolder(original: folderURL) { $0.lastPathComponent == $0.lastPathComponent.uppercased() }
        let uppercaseCopyURL = try copyWithOnlyUppercaseFiles.write(inside: try createTemporaryDirectory())
        
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: uppercaseCopyURL.path), ["UPPER"])
        
        let copyWithOnlyLowercaseFiles = CopyOfFolder(original: folderURL) { $0.lastPathComponent == $0.lastPathComponent.lowercased() }
        let lowercaseCopyURL = try copyWithOnlyLowercaseFiles.write(inside: try createTemporaryDirectory())
        
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: lowercaseCopyURL.path), ["lower"])
    }
}
