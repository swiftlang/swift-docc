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
        let fileSystem = try TestFileSystem(
            folders: [
                Folder(name: "Output.doccarchive", content: []),
                Self.makeArchive(
                    name: "First",
                    documentationPages: [
                        "First",
                        "First/SomeClass",
                        "First/SomeClass/someProperty",
                        "First/SomeClass/someFunction(:_)",
                    ],
                    tutorialPages: [
                        "First",
                        "First/SomeTutorial",
                    ],
                    images: ["something.png"],
                    videos: ["something.mov"],
                    downloads: ["something.zip"]
                ),
                Self.makeArchive(
                    name: "Second",
                    documentationPages: [
                        "Second",
                        "Second/SomeStruct",
                        "Second/SomeStruct/someProperty",
                        "Second/SomeStruct/someFunction(:_)",
                    ],
                    tutorialPages: [
                        "Second",
                        "Second/SomeTutorial",
                    ],
                    images: ["something.png"],
                    videos: ["something.mov"],
                    downloads: ["something.zip"]
                ),
            ]
        )
        
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
        │  ├─ documentation/
        │  │  ├─ first.json
        │  │  ├─ first/
        │  │  │  ├─ someclass.json
        │  │  │  ╰─ someclass/
        │  │  │     ├─ somefunction(:_).json
        │  │  │     ╰─ someproperty.json
        │  │  ├─ second.json
        │  │  ╰─ second/
        │  │     ├─ somestruct.json
        │  │     ╰─ somestruct/
        │  │        ├─ somefunction(:_).json
        │  │        ╰─ someproperty.json
        │  ╰─ tutorials/
        │     ├─ first.json
        │     ├─ first/
        │     │  ╰─ sometutorial.json
        │     ├─ second.json
        │     ╰─ second/
        │        ╰─ sometutorial.json
        ├─ documentation/
        │  ├─ first/
        │  │  ├─ index.html
        │  │  ╰─ someclass/
        │  │     ├─ index.html
        │  │     ├─ somefunction(:_)/
        │  │     │  ╰─ index.html
        │  │     ╰─ someproperty/
        │  │        ╰─ index.html
        │  ╰─ second/
        │     ├─ index.html
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
        ├─ tutorials/
        │  ├─ first/
        │  │  ├─ index.html
        │  │  ╰─ sometutorial/
        │  │     ╰─ index.html
        │  ╰─ second/
        │     ├─ index.html
        │     ╰─ sometutorial/
        │        ╰─ index.html
        ╰─ videos/
           ├─ com.example.first/
           │  ╰─ something.mov
           ╰─ com.example.second/
              ╰─ something.mov
        """)
    }
    
    func testCreatesDataDirectoryWhenMergingSingleEmptyArchive() throws {
        let fileSystem = try TestFileSystem(
            folders: [
                Folder(name: "Output.doccarchive", content: []),
                Self.makeArchive(
                    name: "Empty",
                    documentationPages: [],
                    tutorialPages: [],
                    images: [],
                    videos: [],
                    downloads: []
                ),
                
            ]
        )
        
        let logStorage = LogHandle.LogStorage()
        var action = MergeAction(
            archives: [
                URL(fileURLWithPath: "/Empty.doccarchive"),
            ],
            outputURL: URL(fileURLWithPath: "/Output.doccarchive"),
            fileManager: fileSystem
        )
        
        _ = try action.perform(logHandle: .memory(logStorage))
        XCTAssertEqual(logStorage.text, "", "The action didn't log anything")
        
        
        // The empty archive doesn't have a "data" subdirectory
        XCTAssertEqual(fileSystem.dump(subHierarchyFrom: "/Empty.doccarchive"), """
        Empty.doccarchive/
        ├─ css/
        │  ╰─ something.css
        ├─ downloads/
        │  ╰─ com.example.empty/
        ├─ favicon.svg
        ├─ images/
        │  ╰─ com.example.empty/
        ├─ img/
        │  ╰─ something.svg
        ├─ index/
        │  ╰─ index.json
        ├─ js/
        │  ╰─ something.js
        ├─ metadata.json
        ╰─ videos/
           ╰─ com.example.empty/
        """)
        
        // The combined archive has a "data" subdirectory.
        // This allows other archives to copy their documentation and tutorial data without needing to check or create intermediate directories. 
        XCTAssertEqual(fileSystem.dump(subHierarchyFrom: "/Output.doccarchive"), """
        Output.doccarchive/
        ├─ css/
        │  ╰─ something.css
        ├─ data/
        ├─ downloads/
        │  ╰─ com.example.empty/
        ├─ favicon.svg
        ├─ images/
        │  ╰─ com.example.empty/
        ├─ img/
        │  ╰─ something.svg
        ├─ index/
        │  ╰─ index.json
        ├─ js/
        │  ╰─ something.js
        ├─ metadata.json
        ╰─ videos/
           ╰─ com.example.empty/
        """)
    }
    
    func testErrorWhenArchivesContainOverlappingData() throws {
        let fileSystem = try TestFileSystem(
            folders: [
                Folder(name: "Output.doccarchive", content: []),
                Self.makeArchive(
                    name: "First",
                    documentationPages: [
                        "Something",
                        "Something/SomeClass",
                        "Something/SomeClass/someProperty",
                        "Something/SomeClass/someFunction(:_)",
                    ],
                    tutorialPages: [],
                    images: ["something.png"],
                    videos: ["something.mov"],
                    downloads: ["something.zip"]
                ),
                Self.makeArchive(
                    name: "Second",
                    documentationPages: [
                        "Something",
                        "Something/SomeStruct",
                        "Something/SomeStruct/someProperty",
                        "Something/SomeStruct/someFunction(:_)",
                    ],
                    tutorialPages: [
                        "Something",
                        "Something/SomeTutorial",
                    ],
                    images: ["something.png"],
                    videos: ["something.mov"],
                    downloads: ["something.zip"]
                ),
                Self.makeArchive(
                    name: "Third",
                    documentationPages: [
                        "Something",
                        "Something/SomeStruct",
                        "Something/SomeStruct/someProperty",
                        "Something/SomeStruct/someFunction(:_)",
                    ],
                    tutorialPages: [
                        "Something",
                        "Something/SomeTutorial",
                    ],
                    images: ["something.png"],
                    videos: ["something.mov"],
                    downloads: ["something.zip"]
                ),
            ]
        )
        
        let logStorage = LogHandle.LogStorage()
        var action = MergeAction(
            archives: [
                URL(fileURLWithPath: "/First.doccarchive"),
                URL(fileURLWithPath: "/Second.doccarchive"),
                URL(fileURLWithPath: "/Third.doccarchive"),
            ],
            outputURL: URL(fileURLWithPath: "/Output.doccarchive"),
            fileManager: fileSystem
        )
        
        XCTAssertThrowsError(try action.perform(logHandle: LogHandle.memory(logStorage))) { error in
            XCTAssertEqual(error.localizedDescription, """
            Input archives contain overlapping data

            'First.doccarchive', 'Second.doccarchive', and 'Third.doccarchive' all contain '/data/documentation/something/'

            'Second.doccarchive' and 'Third.doccarchive' both contain '/data/tutorials/something/'
            """)
        }
        XCTAssertEqual(logStorage.text, "", "The action didn't log anything")
        
        XCTAssertEqual(fileSystem.dump(subHierarchyFrom: "/Output.doccarchive"), "Output.doccarchive/", "Nothing was written to the output directory")
    }
    
    func testErrorWhenOutputDirectoryIsNotEmpty() throws {
        let fileSystem = try TestFileSystem(folders: [
            Self.makeArchive(name: "Output", documentationPages: [
                "Something",
            ], tutorialPages: [], images: [], videos: [], downloads: []),
            Self.makeArchive(name: "First", documentationPages: [
                "First",
                "First/SomeClass",
                "First/SomeClass/someProperty",
                "First/SomeClass/someFunction(:_)",
            ], tutorialPages: [], images: ["something.png"], videos: ["something.mov"], downloads: ["something.zip"]),
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
        
        XCTAssertThrowsError(try action.perform(logHandle: LogHandle.memory(logStorage))) { error in
            XCTAssertEqual(error.localizedDescription, """
            Output directory is not empty. It contains:
             - css/
             - data/
             - documentation/
             - downloads/
             - favicon.svg
            and 6 more files and directories
            """)
        }
        XCTAssertEqual(logStorage.text, "", "The action didn't log anything")
    }
    
    // MARK: Test helpers
    
    func testMakeArchive() throws {
        XCTAssertEqual(Self.makeArchive(name: "Something", documentationPages: [], tutorialPages: []).dump(), """
        Something.doccarchive/
        ├─ css/
        │  ╰─ something.css
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
            documentationPages: [
                "Something",
                "Something/SomeClass",
                "Something/SomeClass/someProperty",
                "Something/SomeClass/someFunction(:_)",
            ],
            tutorialPages: [
                "Something",
                "Something/SomeTutorial",
            ],
            images: ["first-image.png", "second-image.png"],
            videos: ["some-video.mov"],
            downloads: ["some-download.zip"]
        ).dump(), """
        Something.doccarchive/
        ├─ css/
        │  ╰─ something.css
        ├─ data/
        │  ├─ documentation/
        │  │  ├─ something.json
        │  │  ╰─ something/
        │  │     ├─ someclass.json
        │  │     ╰─ someclass/
        │  │        ├─ somefunction(:_).json
        │  │        ╰─ someproperty.json
        │  ╰─ tutorials/
        │     ├─ something.json
        │     ╰─ something/
        │        ╰─ sometutorial.json
        ├─ documentation/
        │  ╰─ something/
        │     ├─ index.html
        │     ╰─ someclass/
        │        ├─ index.html
        │        ├─ somefunction(:_)/
        │        │  ╰─ index.html
        │        ╰─ someproperty/
        │           ╰─ index.html
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
        ├─ tutorials/
        │  ╰─ something/
        │     ├─ index.html
        │     ╰─ sometutorial/
        │        ╰─ index.html
        ╰─ videos/
           ╰─ com.example.something/
              ╰─ some-video.mov
        """)
    }
    
    static func makeArchive(
        name: String,
        documentationPages: [String],
        tutorialPages: [String],
        images: [String] = [],
        videos: [String] = [],
        downloads: [String] = []
    ) -> Folder {
        let identifier = "com.example.\(name.lowercased())"
        
        var content: [File] = [
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
        ]
        
        // Content
        var dataContent: [File] = []
        if !documentationPages.isEmpty {
            content += [
                Folder(name: "documentation", content: Folder.makeStructure(filePaths: documentationPages.map { "\($0.lowercased())/index.html" })),
            ]
            dataContent += [
                Folder(name: "documentation", content: Folder.makeStructure(filePaths: documentationPages.map { "\($0.lowercased()).json" })),
            ]
        }
        if !tutorialPages.isEmpty {
            content += [
                Folder(name: "tutorials", content: Folder.makeStructure(filePaths: tutorialPages.map { "\($0.lowercased())/index.html" })),
            ]
            dataContent += [
                Folder(name: "tutorials", content: Folder.makeStructure(filePaths: tutorialPages.map { "\($0.lowercased()).json" })),
            ]
        }
        if !dataContent.isEmpty {
            content += [
                Folder(name: "data", content: dataContent)
            ]
        }
        
        content += [
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
        ]
        
        return Folder(name: "\(name).doccarchive", content: content)
    }
}
