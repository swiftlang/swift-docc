/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
@testable import SwiftDocCUtilities
import SwiftDocCTestUtilities

class FileTests: XCTestCase {
    func testAbsoluteURL() {
        XCTAssertEqual(TextFile(name: "myfile.txt", utf8Content: "").absoluteURL.path, "/myfile.txt")
        XCTAssertEqual(Folder(name: "myDir", content: []).absoluteURL.path, "/myDir")
        XCTAssertEqual(CopyOfFile(original: URL(fileURLWithPath: "myfile.txt")).absoluteURL.path, "/myfile.txt")
        XCTAssertEqual(CopyOfFile(original: URL(fileURLWithPath: "myfile.txt"), newName: "yourfile.txt").absoluteURL.path, "/yourfile.txt")
    }
    
    func testCreateFromDisk() throws {
        let testBundleURL = Bundle.module.url(
            forResource: "DoNotUseInNewTests", withExtension: "docc", subdirectory: "Test Bundles")!
        
        // Generates a list of all paths recursively inside a folder
        func pathsIn(folder: Folder, url: URL) -> [String] {
            var result = [String]()
            for file in folder.content {
                result.append(url.appendingPathComponent(file.name).path)

                switch file {
                    case let folder as Folder:
                        result.append(contentsOf: pathsIn(folder: folder, url: url.appendingPathComponent(file.name)))
                    default: break
                }
            }
            return result
        }

        // Load the contents of a folder on disk
        guard let diskContent = FileManager.default.enumerator(at: testBundleURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)?.allObjects as? [URL] else {
            XCTFail("Could not read \(testBundleURL.path)")
            return
        }
        let diskPaths = Set(diskContent.map({ $0.path.replacingOccurrences(of: testBundleURL.path, with: "") })).sorted()
        
        // Load the disk folder in a `Folder` instance
        let folder = try Folder.createFromDisk(url: testBundleURL)
        let folderPaths = pathsIn(folder: folder, url: URL(string: "/")!).sorted()
        
        // Compare the paths from disk and in the `Folder` are identical
        XCTAssertEqual(diskPaths.count, folderPaths.count)
        XCTAssertEqual(diskPaths, folderPaths)
    }
    
    func testMakingDirectoryStructure() throws {
        XCTAssertEqual(Folder.makeStructure(filePaths: ["one/two/a.json", "one/two/b.json"]).first!.dump(), """
        one/
        ╰─ two/
           ├─ a.json
           ╰─ b.json
        """)
        
        XCTAssertEqual(Folder.makeStructure(filePaths: ["one/two.json", "one/two/three.json"]).first!.dump(), """
        one/
        ├─ two.json
        ╰─ two/
           ╰─ three.json
        """)
        
        XCTAssertEqual(Folder.makeStructure(filePaths: [
            "documentation/first/index.html",
            "documentation/first/abc-page/index.html",
            "documentation/first/xyz-page/index.html",
        ]).first!.dump(), """
        documentation/
        ╰─ first/
           ├─ abc-page/
           │  ╰─ index.html
           ├─ index.html
           ╰─ xyz-page/
              ╰─ index.html
        """)
        
        XCTAssertEqual(Folder.makeStructure(filePaths: [
            "data/documentation/first.json",
            "data/documentation/first/abc-page.json",
            "data/documentation/first/xyz-page.json",
        ]).first!.dump(), """
        data/
        ╰─ documentation/
           ├─ first.json
           ╰─ first/
              ├─ abc-page.json
              ╰─ xyz-page.json
        """)
    }
}
