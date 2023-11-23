/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
@testable import SwiftDocCUtilities
@_spi(FileManagerProtocol) import SwiftDocCTestUtilities

class MergeActionTests: XCTestCase {
    
    func testCopiesArchivesIntoOutputLocation() throws {
        let fileSystem = try TestFileSystem(folders: [
            Folder(name: "Output.doccarchive", content: []),
            Self.makeArchive(name: "First", pages: [
                "First/SomeClass",
                "First/SomeClass/someProperty",
                "First/SomeClass/someFunction(:_)",
            ], images: ["something.png"], videos: ["something.mov"], downloads: ["something.zip"]),
            Self.makeArchive(name: "Second", pages: [
                "Second/SomeStruct",
                "Second/SomeStruct/someProperty",
                "Second/SomeStruct/someFunction(:_)",
            ], images: ["something.png"], videos: ["something.mov"], downloads: ["something.zip"]),
        ])
        
        let logStorage = LogHandle.LogStorage()
        var action = MergeAction(
            archives: [
                URL(fileURLWithPath: "/First.doccarchive"),
                URL(fileURLWithPath: "/Second.doccarchive"),
            ],
            outputURL: URL(fileURLWithPath: "/Output.doccarchive"),
            fileManager: fileSystem
        )
        
        _ = try action.perform(logHandle: .memory(logStorage))
        XCTAssertEqual(logStorage.text, "", "The action didn't log anything")
        
        // The combined archive as the data and assets from the input archives but only one set of archive template files
        XCTAssertEqual(fileSystem.dump(subHierarchyFrom: "/Output.doccarchive"), """
        Output.doccarchive/
        ├─ css/
        │  ╰─ something.css
        ├─ data/
        │  ╰─ documentation/
        │     ├─ first/
        │     │  ├─ someclass.json
        │     │  ╰─ someclass/
        │     │     ├─ somefunction(:_).json
        │     │     ╰─ someproperty.json
        │     ╰─ second/
        │        ├─ somestruct.json
        │        ╰─ somestruct/
        │           ├─ somefunction(:_).json
        │           ╰─ someproperty.json
        ├─ documentation/
        │  ├─ first/
        │  │  ╰─ someclass/
        │  │     ├─ index.html
        │  │     ├─ somefunction(:_)/
        │  │     │  ╰─ index.html
        │  │     ╰─ someproperty/
        │  │        ╰─ index.html
        │  ╰─ second/
        │     ╰─ somestruct/
        │        ├─ index.html
        │        ├─ somefunction(:_)/
        │        │  ╰─ index.html
        │        ╰─ someproperty/
        │           ╰─ index.html
        ├─ downloads/
        │  ├─ com.example.first/
        │  │  ╰─ something.zip
        │  ╰─ com.example.second/
        │     ╰─ something.zip
        ├─ favicon.svg
        ├─ images/
        │  ├─ com.example.first/
        │  │  ╰─ something.png
        │  ╰─ com.example.second/
        │     ╰─ something.png
        ├─ img/
        │  ╰─ something.svg
        ├─ index/
        │  ╰─ index.json
        ├─ js/
        │  ╰─ something.js
        ├─ metadata.json
        ╰─ videos/
           ├─ com.example.first/
           │  ╰─ something.mov
           ╰─ com.example.second/
              ╰─ something.mov
        """)
    }
    
    // MARK: Test helpers
    
    func testMakeArchive() throws {
        XCTAssertEqual(Self.makeArchive(name: "Something", pages: []).dump(), """
        Something.doccarchive/
        ├─ css/
        │  ╰─ something.css
        ├─ data/
        │  ╰─ documentation/
        ├─ documentation/
        ├─ downloads/
        │  ╰─ com.example.something/
        ├─ favicon.svg
        ├─ images/
        │  ╰─ com.example.something/
        ├─ img/
        │  ╰─ something.svg
        ├─ index/
        │  ╰─ index.json
        ├─ js/
        │  ╰─ something.js
        ├─ metadata.json
        ╰─ videos/
           ╰─ com.example.something/
        """)
        
        XCTAssertEqual(Self.makeArchive(
            name: "Something",
            pages: [
                "SomeClass",
                "SomeClass/someProperty",
                "SomeClass/someFunction(:_)",
            ],
            images: ["first-image.png", "second-image.png"],
            videos: ["some-video.mov"],
            downloads: ["some-download.zip"]
        ).dump(), """
        Something.doccarchive/
        ├─ css/
        │  ╰─ something.css
        ├─ data/
        │  ╰─ documentation/
        │     ├─ someclass.json
        │     ╰─ someclass/
        │        ├─ somefunction(:_).json
        │        ╰─ someproperty.json
        ├─ documentation/
        │  ╰─ someclass/
        │     ├─ index.html
        │     ├─ somefunction(:_)/
        │     │  ╰─ index.html
        │     ╰─ someproperty/
        │        ╰─ index.html
        ├─ downloads/
        │  ╰─ com.example.something/
        │     ╰─ some-download.zip
        ├─ favicon.svg
        ├─ images/
        │  ╰─ com.example.something/
        │     ├─ first-image.png
        │     ╰─ second-image.png
        ├─ img/
        │  ╰─ something.svg
        ├─ index/
        │  ╰─ index.json
        ├─ js/
        │  ╰─ something.js
        ├─ metadata.json
        ╰─ videos/
           ╰─ com.example.something/
              ╰─ some-video.mov
        """)
    }
    
    static func makeArchive(
        name: String,
        pages: [String],
        images: [String] = [],
        videos: [String] = [],
        downloads: [String] = []
    ) -> Folder {
        let identifier = "com.example.\(name.lowercased())"
        
        return Folder(name: "\(name).doccarchive", content: [
            // Template files
            Folder(name: "css", content: [
                TextFile(name: "something.css", utf8Content: ""),
            ]),
            Folder(name: "js", content: [
                TextFile(name: "something.js", utf8Content: ""),
            ]),
            Folder(name: "img", content: [
                TextFile(name: "something.svg", utf8Content: ""),
            ]),
            TextFile(name: "favicon.svg", utf8Content: ""),
            
            // Content
            Folder(name: "documentation", content: Folder.makeStructure(filePaths: pages.map { $0.lowercased() + "/index.html" })),
            Folder(name: "data", content: [
                Folder(name: "documentation", content: Folder.makeStructure(filePaths: pages.map { $0.lowercased() + ".json" })),
            ]),
            Folder(name: "images", content: [
                Folder(name: identifier, content: images.map {
                    DataFile(name: $0, data: Data())
                }),
            ]),
            Folder(name: "videos", content: [
                Folder(name: identifier, content: videos.map {
                    DataFile(name: $0, data: Data())
                }),
            ]),
            Folder(name: "downloads", content: [
                Folder(name: identifier, content: downloads.map {
                    DataFile(name: $0, data: Data())
                }),
            ]),
            
            // Additional data
            Folder(name: "index", content: [
                JSONFile(name: "index.json", content: RenderIndex(interfaceLanguages: [:], includedArchiveIdentifiers: [identifier]))
            ]),
            
            JSONFile(name: "metadata.json", content: BuildMetadata(bundleDisplayName: name, bundleIdentifier: identifier))
        ])
    }
}
