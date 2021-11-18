/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import SwiftDocCTestUtilities

class TempFolderTests: XCTestCase {
    func testCreatesAndDeletesTempFolder() throws {
        var tempFolder: TempFolder! = try TempFolder(content: [
            TextFile(name: "index.html", utf8Content: "index"),
        ], atRoot: createTemporaryDirectory(createDirectoryForLastPathComponent: false))
        
        // Check the folder is created and the file inside exists.
        XCTAssertTrue(FileManager.default.directoryExists(atPath: tempFolder.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempFolder!.url.appendingPathComponent("index.html").path))
        
        let rootTempFolderPath = tempFolder!.url.path
        // Check the temp folder is inside the system temporary folder.
        XCTAssertTrue(tempFolder!.url.path.contains(rootTempFolderPath))
        
        let tempFolderURL = tempFolder.url
        
        tempFolder = nil
        
        // Check the temp folder and contents are deleted immediately.
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempFolderURL.path))
    }
    
    func testCreatesRandomPaths() throws {
        let tempFolder1 = try TempFolder(content: [], atRoot: createTemporaryDirectory(createDirectoryForLastPathComponent: false))
        let tempFolder2 = try TempFolder(content: [], atRoot: createTemporaryDirectory(createDirectoryForLastPathComponent: false))
        
        XCTAssertNotEqual(tempFolder1.url, tempFolder2.url)
    }
}
