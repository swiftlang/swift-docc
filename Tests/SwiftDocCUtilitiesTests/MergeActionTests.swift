/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
@testable import SwiftDocCUtilities
import SwiftDocCTestUtilities

class MergeActionTests: XCTestCase {
    
    private let testLandingPageInfo = MergeAction.LandingPageInfo.synthesize(
        .init(
            name: "Test Landing Page Name",
            kind: "Test Landing Page Kind",
            style: .detailedGrid
        )
    )
    
    func testCopiesArchivesIntoOutputLocation() async throws {
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
        let action = MergeAction(
            archives: [
                URL(fileURLWithPath: "/First.doccarchive"),
                URL(fileURLWithPath: "/Second.doccarchive"),
            ],
            landingPageInfo: testLandingPageInfo,
            outputURL: URL(fileURLWithPath: "/Output.doccarchive"),
            fileManager: fileSystem
        )
        
        _ = try await action.perform(logHandle: .memory(logStorage))
        XCTAssertEqual(logStorage.text, "", "The action didn't log anything")
        
        // The combined archive as the data and assets from the input archives but only one set of archive template files
        XCTAssertEqual(fileSystem.dump(subHierarchyFrom: "/Output.doccarchive"), """
        Output.doccarchive/
        ├─ css/
        │  ╰─ something.css
        ├─ data/
        │  ├─ documentation.json
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
        
        let synthesizedRootNode = try fileSystem.renderNode(atPath: "/Output.doccarchive/data/documentation.json")
        XCTAssertEqual(synthesizedRootNode.metadata.title, "Test Landing Page Name")
        XCTAssertEqual(synthesizedRootNode.metadata.roleHeading, "Test Landing Page Kind")
        XCTAssertEqual(synthesizedRootNode.topicSectionsStyle, .detailedGrid)
        XCTAssertEqual(synthesizedRootNode.topicSections.flatMap { [$0.title ?? ""] + $0.identifiers }, [
            "Modules",
            "doc://org.swift.test/documentation/first.json",
            "doc://org.swift.test/documentation/second.json",

            "Tutorials",
            "doc://org.swift.test/tutorials/first.json",
            "doc://org.swift.test/tutorials/second.json",
        ])
        XCTAssertEqual(synthesizedRootNode.references.keys.sorted(), [
            "doc://org.swift.test/documentation/first.json",
            "doc://org.swift.test/documentation/second.json",
            "doc://org.swift.test/tutorials/first.json",
            "doc://org.swift.test/tutorials/second.json",
        ])
    }
    
    func testCreatesDataDirectoryWhenMergingSingleEmptyArchive() async throws {
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
        let action = MergeAction(
            archives: [
                URL(fileURLWithPath: "/Empty.doccarchive"),
            ],
            landingPageInfo: testLandingPageInfo,
            outputURL: URL(fileURLWithPath: "/Output.doccarchive"),
            fileManager: fileSystem
        )
        
        _ = try await action.perform(logHandle: .memory(logStorage))
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
    
    func testCanMergeReferenceOnlyArchiveWithTutorialOnlyArchive() async throws {
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
                    tutorialPages: [],
                    images: ["something.png"],
                    videos: ["something.mov"],
                    downloads: ["something.zip"]
                ),
                Self.makeArchive(
                    name: "Second",
                    documentationPages: [],
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
        let action = MergeAction(
            archives: [
                URL(fileURLWithPath: "/First.doccarchive"),
                URL(fileURLWithPath: "/Second.doccarchive"),
            ],
            landingPageInfo: testLandingPageInfo,
            outputURL: URL(fileURLWithPath: "/Output.doccarchive"),
            fileManager: fileSystem
        )
        
        _ = try await action.perform(logHandle: .memory(logStorage))
        XCTAssertEqual(logStorage.text, "", "The action didn't log anything")
        
        // The combined archive as the data, documentation, tutorials, and assets from the both input archives.
        XCTAssertEqual(fileSystem.dump(subHierarchyFrom: "/Output.doccarchive"), """
        Output.doccarchive/
        ├─ css/
        │  ╰─ something.css
        ├─ data/
        │  ├─ documentation.json
        │  ├─ documentation/
        │  │  ├─ first.json
        │  │  ╰─ first/
        │  │     ├─ someclass.json
        │  │     ╰─ someclass/
        │  │        ├─ somefunction(:_).json
        │  │        ╰─ someproperty.json
        │  ╰─ tutorials/
        │     ├─ second.json
        │     ╰─ second/
        │        ╰─ sometutorial.json
        ├─ documentation/
        │  ╰─ first/
        │     ├─ index.html
        │     ╰─ someclass/
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
        
        let synthesizedRootNode = try fileSystem.renderNode(atPath: "/Output.doccarchive/data/documentation.json")
        XCTAssertEqual(synthesizedRootNode.metadata.title, "Test Landing Page Name")
        XCTAssertEqual(synthesizedRootNode.metadata.roleHeading, "Test Landing Page Kind")
        XCTAssertEqual(synthesizedRootNode.topicSectionsStyle, .detailedGrid)
        XCTAssertEqual(synthesizedRootNode.topicSections.flatMap { [$0.title ?? ""] + $0.identifiers }, [
            "Modules",
            "doc://org.swift.test/documentation/first.json",

            "Tutorials",
            "doc://org.swift.test/tutorials/second.json",
        ])
        XCTAssertEqual(synthesizedRootNode.references.keys.sorted(), [
            "doc://org.swift.test/documentation/first.json",
            "doc://org.swift.test/tutorials/second.json",
        ])
    }
    
    func testCanMergeReferenceOnlyArchiveWithTutorialOnlyArchiveWithoutStaticHosting() async throws {
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
                    tutorialPages: [],
                    images: ["something.png"],
                    videos: ["something.mov"],
                    downloads: ["something.zip"],
                    supportsStaticHosting: false
                ),
                Self.makeArchive(
                    name: "Second",
                    documentationPages: [],
                    tutorialPages: [
                        "Second",
                        "Second/SomeTutorial",
                    ],
                    images: ["something.png"],
                    videos: ["something.mov"],
                    downloads: ["something.zip"],
                    supportsStaticHosting: false
                ),
            ]
        )
        
        let logStorage = LogHandle.LogStorage()
        let action = MergeAction(
            archives: [
                URL(fileURLWithPath: "/First.doccarchive"),
                URL(fileURLWithPath: "/Second.doccarchive"),
            ],
            landingPageInfo: testLandingPageInfo,
            outputURL: URL(fileURLWithPath: "/Output.doccarchive"),
            fileManager: fileSystem
        )
        
        _ = try await action.perform(logHandle: .memory(logStorage))
        XCTAssertEqual(logStorage.text, "", "The action didn't log anything")
        
        // The combined archive doesn't have "documentation" or "tutorial" directories because the inputs didn't support static hosting.
        XCTAssertEqual(fileSystem.dump(subHierarchyFrom: "/Output.doccarchive"), """
        Output.doccarchive/
        ├─ css/
        │  ╰─ something.css
        ├─ data/
        │  ├─ documentation.json
        │  ├─ documentation/
        │  │  ├─ first.json
        │  │  ╰─ first/
        │  │     ├─ someclass.json
        │  │     ╰─ someclass/
        │  │        ├─ somefunction(:_).json
        │  │        ╰─ someproperty.json
        │  ╰─ tutorials/
        │     ├─ second.json
        │     ╰─ second/
        │        ╰─ sometutorial.json
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
        
        let synthesizedRootNode = try fileSystem.renderNode(atPath: "/Output.doccarchive/data/documentation.json")
        XCTAssertEqual(synthesizedRootNode.metadata.title, "Test Landing Page Name")
        XCTAssertEqual(synthesizedRootNode.metadata.roleHeading, "Test Landing Page Kind")
        XCTAssertEqual(synthesizedRootNode.topicSectionsStyle, .detailedGrid)
        XCTAssertEqual(synthesizedRootNode.topicSections.flatMap { [$0.title ?? ""] + $0.identifiers }, [
            "Modules",
            "doc://org.swift.test/documentation/first.json",

            "Tutorials",
            "doc://org.swift.test/tutorials/second.json",
        ])
        XCTAssertEqual(synthesizedRootNode.references.keys.sorted(), [
            "doc://org.swift.test/documentation/first.json",
            "doc://org.swift.test/tutorials/second.json",
        ])
    }
    
    func testSupportsArchivesWithoutStaticHosting() async throws {
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
                    downloads: ["something.zip"],
                    supportsStaticHosting: false
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
                    downloads: ["something.zip"],
                    supportsStaticHosting: false
                ),
            ]
        )
        
        let logStorage = LogHandle.LogStorage()
        let action = MergeAction(
            archives: [
                URL(fileURLWithPath: "/First.doccarchive"),
                URL(fileURLWithPath: "/Second.doccarchive"),
            ],
            landingPageInfo: testLandingPageInfo,
            outputURL: URL(fileURLWithPath: "/Output.doccarchive"),
            fileManager: fileSystem
        )
        
        _ = try await action.perform(logHandle: .memory(logStorage))
        XCTAssertEqual(logStorage.text, "", "The action didn't log anything")
        
        // The combined archive doesn't have "documentation" or "tutorial" directories because the inputs didn't support static hosting.
        XCTAssertEqual(fileSystem.dump(subHierarchyFrom: "/Output.doccarchive"), """
        Output.doccarchive/
        ├─ css/
        │  ╰─ something.css
        ├─ data/
        │  ├─ documentation.json
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
        
        let synthesizedRootNode = try fileSystem.renderNode(atPath: "/Output.doccarchive/data/documentation.json")
        XCTAssertEqual(synthesizedRootNode.metadata.title, "Test Landing Page Name")
        XCTAssertEqual(synthesizedRootNode.metadata.roleHeading, "Test Landing Page Kind")
        XCTAssertEqual(synthesizedRootNode.topicSectionsStyle, .detailedGrid)
        XCTAssertEqual(synthesizedRootNode.topicSections.flatMap { [$0.title ?? ""] + $0.identifiers }, [
            "Modules",
            "doc://org.swift.test/documentation/first.json",
            "doc://org.swift.test/documentation/second.json",

            "Tutorials",
            "doc://org.swift.test/tutorials/first.json",
            "doc://org.swift.test/tutorials/second.json",
        ])
        XCTAssertEqual(synthesizedRootNode.references.keys.sorted(), [
            "doc://org.swift.test/documentation/first.json",
            "doc://org.swift.test/documentation/second.json",
            "doc://org.swift.test/tutorials/first.json",
            "doc://org.swift.test/tutorials/second.json",
        ])
    }
    
    func testReferenceOnlyArchivesDoNotSynthesizeTutorialsTopicSection() async throws {
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
                    tutorialPages: []
                ),
                Self.makeArchive(
                    name: "Second",
                    documentationPages: [
                        "Second",
                        "Second/SomeStruct",
                        "Second/SomeStruct/someProperty",
                        "Second/SomeStruct/someFunction(:_)",
                    ],
                    tutorialPages: []
                ),
            ]
        )
        
        let logStorage = LogHandle.LogStorage()
        let action = MergeAction(
            archives: [
                URL(fileURLWithPath: "/First.doccarchive"),
                URL(fileURLWithPath: "/Second.doccarchive"),
            ],
            landingPageInfo: testLandingPageInfo,
            outputURL: URL(fileURLWithPath: "/Output.doccarchive"),
            fileManager: fileSystem
        )
        
        _ = try await action.perform(logHandle: .memory(logStorage))
        XCTAssertEqual(logStorage.text, "", "The action didn't log anything")
        
        let synthesizedRootNode = try fileSystem.renderNode(atPath: "/Output.doccarchive/data/documentation.json")
        XCTAssertEqual(synthesizedRootNode.metadata.title, "Test Landing Page Name")
        XCTAssertEqual(synthesizedRootNode.metadata.roleHeading, "Test Landing Page Kind")
        XCTAssertEqual(synthesizedRootNode.topicSectionsStyle, .detailedGrid)
        XCTAssertEqual(synthesizedRootNode.topicSections.flatMap { [$0.title].compactMap({ $0 }) + $0.identifiers }, [
            // No title
            "doc://org.swift.test/documentation/first.json",
            "doc://org.swift.test/documentation/second.json",
        ])
        XCTAssertEqual(synthesizedRootNode.references.keys.sorted(), [
            "doc://org.swift.test/documentation/first.json",
            "doc://org.swift.test/documentation/second.json",
        ])
    }
    
    func testErrorWhenArchivesContainOverlappingData() async throws {
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
        let action = MergeAction(
            archives: [
                URL(fileURLWithPath: "/First.doccarchive"),
                URL(fileURLWithPath: "/Second.doccarchive"),
                URL(fileURLWithPath: "/Third.doccarchive"),
            ],
            landingPageInfo: testLandingPageInfo,
            outputURL: URL(fileURLWithPath: "/Output.doccarchive"),
            fileManager: fileSystem
        )
        
        do {
            _ = try await action.perform(logHandle: LogHandle.memory(logStorage))
            XCTFail("The action didn't raise an error")
        } catch {
            XCTAssertEqual(error.localizedDescription, """
            Input archives contain overlapping data

            'First.doccarchive', 'Second.doccarchive', and 'Third.doccarchive' all contain '/data/documentation/something/'

            'Second.doccarchive' and 'Third.doccarchive' both contain '/data/tutorials/something/'
            """)
        }
        XCTAssertEqual(logStorage.text, "", "The action didn't log anything")
        
        XCTAssertEqual(fileSystem.dump(subHierarchyFrom: "/Output.doccarchive"), "Output.doccarchive/", "Nothing was written to the output directory")
    }
    
    func testErrorWhenOutputDirectoryIsNotEmpty() async throws {
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
        let action = MergeAction(
            archives: [
                URL(fileURLWithPath: "/First.doccarchive"),
                URL(fileURLWithPath: "/Second.doccarchive"),
            ],
            landingPageInfo: testLandingPageInfo,
            outputURL: URL(fileURLWithPath: "/Output.doccarchive"),
            fileManager: fileSystem
        )
        
        do {
            _ = try await action.perform(logHandle: LogHandle.memory(logStorage))
            XCTFail("The action didn't raise an error")
        } catch {
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
    
    func testErrorWhenSomeArchivesDoNotSupportStaticHosting() async throws {
        let fileSystem = try TestFileSystem(folders: [
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
                downloads: ["something.zip"],
                supportsStaticHosting: false
            ),
        ])
        
        let logStorage = LogHandle.LogStorage()
        let action = MergeAction(
            archives: [
                URL(fileURLWithPath: "/First.doccarchive"),
                URL(fileURLWithPath: "/Second.doccarchive"),
            ],
            landingPageInfo: testLandingPageInfo,
            outputURL: URL(fileURLWithPath: "/Output.doccarchive"),
            fileManager: fileSystem
        )
        
        do {
            _ = try await action.perform(logHandle: LogHandle.memory(logStorage))
            XCTFail("The action didn't raise an error")
        } catch {
            XCTAssertEqual(error.localizedDescription, """
            Different static hosting support in different archives.

            First.doccarchive supports static hosting but Second.doccarchive doesn't.
            """)
        }
        XCTAssertEqual(logStorage.text, "", "The action didn't log anything")
    }
    
    func testMergingArchivesWithPageImages() async throws {
        let fileSystem = try TestFileSystem(folders: [])
        
        let baseOutputDir = URL(fileURLWithPath: "/path/to/some-output-dir")
        try fileSystem.createDirectory(at: baseOutputDir, withIntermediateDirectories: true)
        
        func convertCatalog(named name: String, file: StaticString = #filePath, line: UInt = #line) async throws -> URL {
            let catalog = Folder(name: "\(name).docc", content: [
                TextFile(name: "\(name).md", utf8Content: """
                # My root
                
                A root page with a custom "card" page icon in the "\(name.lowercased())" project that links to <doc:Article#Some-heading>
                
                @Metadata {
                  @PageImage(purpose: card, source: \(name.lowercased())-card)
                }
                """),
                
                DataFile(name: "\(name.lowercased())-card.png", data: Data()),
                
                TextFile(name: "Article.md", utf8Content: """
                # Some article
                
                An article in the "\(name.lowercased())" project.
                
                ## Some heading
                """),
            ])
            
            let catalogDir = URL(fileURLWithPath: "/path/to/inputs/\(catalog.name)")
            try fileSystem.createDirectory(at: catalogDir, withIntermediateDirectories: true)
            try fileSystem.addFolder(catalog, basePath: catalogDir.deletingLastPathComponent())
            
            let (inputs, dataProvider) = try DocumentationContext.InputsProvider(fileManager: fileSystem)
                .inputsAndDataProvider(startingPoint: catalogDir, options: .init())
            XCTAssertEqual(inputs.miscResourceURLs.map(\.lastPathComponent), [
                "\(name.lowercased())-card.png",
            ])
            
            let context = try await DocumentationContext(inputs: inputs, dataProvider: dataProvider, configuration: .init())

            XCTAssert(
                context.problems.filter { $0.diagnostic.identifier != "org.swift.docc.SummaryContainsLink" }.isEmpty,
                "Unexpected problems: \(context.problems.filter { $0.diagnostic.identifier != "org.swift.docc.SummaryContainsLink" }.map(\.diagnostic.summary).joined(separator: "\n"))",
                file: file, line: line
            )
            
            let outputPath = baseOutputDir.appendingPathComponent("\(name).doccarchive", isDirectory: true)
            
            let realTempURL = try createTemporaryDirectory() // The navigator builder only support real file systems
            let indexer = try ConvertAction.Indexer(outputURL: realTempURL, bundleID: inputs.id)
            
            let outputConsumer = ConvertFileWritingConsumer(targetFolder: outputPath, bundleRootFolder: catalogDir, fileManager: fileSystem, context: context, indexer: indexer, transformForStaticHostingIndexHTML: nil, bundleID: inputs.id)
            
            let convertProblems = try ConvertActionConverter.convert(inputs: inputs, context: context, outputConsumer: outputConsumer, sourceRepository: nil, emitDigest: false, documentationCoverageOptions: .noCoverage)
            XCTAssert(convertProblems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary).joined(separator: "\n"))", file: file, line: line)
            
            let navigatorProblems = indexer.finalize(emitJSON: true, emitLMDB: false)
            XCTAssert(navigatorProblems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary).joined(separator: "\n"))", file: file, line: line)
            
            // Move the file from the real file system to the test file system
            let outputIndexDir = outputPath.appendingPathComponent("index")
            try fileSystem.createDirectory(at: outputIndexDir, withIntermediateDirectories: false)
            try fileSystem.createFile(
                at: outputIndexDir.appendingPathComponent("index.json"),
                contents: try Data(contentsOf: realTempURL.appendingPathComponent("index/index.json"))
            )
            
            XCTAssertEqual(fileSystem.dump(subHierarchyFrom: outputPath.path), """
            \(name).doccarchive/
            ├─ data/
            │  ╰─ documentation/
            │     ├─ \(name.lowercased()).json
            │     ╰─ \(name.lowercased())/
            │        ╰─ article.json
            ├─ downloads/
            │  ╰─ \(name)
            ├─ images/
            │  ╰─ \(name)/
            │     ╰─ \(name.lowercased())-card.png
            ├─ index/
            │  ╰─ index.json
            ├─ metadata.json
            ╰─ videos/
               ╰─ \(name)
            """, file: file, line: line)
            
            return outputPath
        }
        
        let firstArchiveDir  = try await convertCatalog(named: "First")
        let secondArchiveDir = try await convertCatalog(named: "Second")
        
        let combinedArchiveDir = URL(fileURLWithPath: "/Output.doccarchive")
        let action = MergeAction(
            archives: [
              firstArchiveDir,
              secondArchiveDir,
            ],
            landingPageInfo: testLandingPageInfo,
            outputURL: combinedArchiveDir,
            fileManager: fileSystem
        )
        
        _ = try await action.perform(logHandle: .none)
        
        XCTAssertEqual(fileSystem.dump(subHierarchyFrom: combinedArchiveDir.path), """
        Output.doccarchive/
        ├─ data/
        │  ├─ documentation.json
        │  ├─ documentation/
        │  │  ├─ first.json
        │  │  ├─ first/
        │  │  │  ╰─ article.json
        │  │  ├─ second.json
        │  │  ╰─ second/
        │  │     ╰─ article.json
        │  ╰─ tutorials/
        ├─ downloads/
        │  ├─ First/
        │  ╰─ Second/
        ├─ images/
        │  ├─ First/
        │  │  ╰─ first-card.png
        │  ╰─ Second/
        │     ╰─ second-card.png
        ├─ index/
        │  ╰─ index.json
        ├─ metadata.json
        ╰─ videos/
           ├─ First/
           ╰─ Second/
        """)
        
        let rootPageData = try fileSystem.contents(of: combinedArchiveDir.appendingPathComponent("data/documentation.json"))
        let rootPage = try JSONDecoder().decode(RenderNode.self, from: rootPageData)
        
        XCTAssertEqual(rootPage.references.keys.sorted(), [
            "First/first-card.png",
            "Second/second-card.png",
            "doc://First/documentation/First",
            "doc://First/documentation/First/Article#Some-heading",
            "doc://Second/documentation/Second",
            "doc://Second/documentation/Second/Article#Some-heading",
        ])
        
        let firstCardRelativeURL = try XCTUnwrap(URL(string: "/images/First/first-card.png"))
        XCTAssertEqual(
            rootPage.references["First/first-card.png"] as? ImageReference,
            ImageReference(
                identifier: RenderReferenceIdentifier("First/first-card.png"),
                imageAsset: DataAsset(
                    variants: [
                        DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard): firstCardRelativeURL
                    ],
                    metadata: [
                        firstCardRelativeURL: DataAsset.Metadata(svgID: nil)
                    ],
                    context: .display
                )
            )
        )
        
        let secondCardRelativeURL = try XCTUnwrap(URL(string: "/images/Second/second-card.png"))
        XCTAssertEqual(
            rootPage.references["Second/second-card.png"] as? ImageReference,
            ImageReference(
                identifier: RenderReferenceIdentifier("Second/second-card.png"),
                imageAsset: DataAsset(
                    variants: [
                        DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard): secondCardRelativeURL
                    ],
                    metadata: [
                        secondCardRelativeURL: DataAsset.Metadata(svgID: nil)
                    ],
                    context: .display
                )
            )
        )
        
        XCTAssertEqual(
            rootPage.references["doc://First/documentation/First/Article#Some-heading"] as? TopicRenderReference,
            TopicRenderReference(
                identifier: RenderReferenceIdentifier("doc://First/documentation/First/Article#Some-heading"),
                title: "Some heading",
                abstract: [],
                url: "/documentation/first/article#Some-heading",
                kind: .section
            )
        )
        
        XCTAssertEqual(
            rootPage.references["doc://Second/documentation/Second/Article#Some-heading"] as? TopicRenderReference,
            TopicRenderReference(
                identifier: RenderReferenceIdentifier("doc://Second/documentation/Second/Article#Some-heading"),
                title: "Some heading",
                abstract: [],
                url: "/documentation/second/article#Some-heading",
                kind: .section
            )
        )
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
            downloads: ["some-download.zip"],
            supportsStaticHosting: false
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
        documentationPages: [String],
        tutorialPages: [String],
        images: [String] = [],
        videos: [String] = [],
        downloads: [String] = [],
        supportsStaticHosting: Bool = true
    ) -> Folder {
        let identifier = "com.example.\(name.lowercased())"
        
        var content: [any File] = [
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
        var dataContent: [any File] = []
        if !documentationPages.isEmpty {
            if supportsStaticHosting {
                content += [
                    Folder(name: "documentation", content: Folder.makeStructure(filePaths: documentationPages.map { "\($0.lowercased())/index.html" })),
                ]
            }
            dataContent += [
                Folder(name: "documentation", content: Folder.makeStructure(filePaths: documentationPages.map { "\($0.lowercased()).json" }, renderNodeReferencePrefix: "/documentation")),
            ]
        }
        if !tutorialPages.isEmpty {
            if supportsStaticHosting {
                content += [
                    Folder(name: "tutorials", content: Folder.makeStructure(filePaths: tutorialPages.map { "\($0.lowercased())/index.html" })),
                ]
            }
            dataContent += [
                Folder(name: "tutorials", content: Folder.makeStructure(filePaths: tutorialPages.map { "\($0.lowercased()).json" }, renderNodeReferencePrefix: "/tutorials")),
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
            
            JSONFile(name: "metadata.json", content: BuildMetadata(bundleDisplayName: name, bundleID: DocumentationContext.Inputs.Identifier(rawValue: identifier)))
        ]
        
        return Folder(name: "\(name).doccarchive", content: content)
    }
}

private extension TestFileSystem {
    func renderNode(atPath path: String) throws -> RenderNode {
        let data = try contents(of: URL(fileURLWithPath: path))
        
        return try JSONDecoder().decode(RenderNode.self, from: data)
    }
}
