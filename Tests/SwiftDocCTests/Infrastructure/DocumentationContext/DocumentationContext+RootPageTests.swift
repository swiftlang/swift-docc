/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SymbolKit
@testable import SwiftDocC
import SwiftDocCTestUtilities

class DocumentationContext_RootPageTests: XCTestCase {
    func testNoSGFBundle() throws {
        let tempFolderURL = try createTempFolder(content: [
            Folder(name: "no-sgf-test.docc", content: [
                // Root page for the collection
                TextFile(name: "ReleaseNotes.md", utf8Content: """
                # Release Notes
                @Metadata {
                   @TechnologyRoot
                }
                Learn about recent changes.
                ## Topics
                ### Release Notes
                 - <doc:documentation/TechnologyX/ReleaseNotes-1.2>
                """),
                // A curated article
                TextFile(name: "ReleaseNotes 1.2.md", utf8Content: """
                # Release Notes for version 1.2
                Learn about changes in version 1.2
                ## See Also
                 - <doc:documentation/TechnologyX/ReleaseNotes>
                """),
                InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            ]),
        ])
        
        // Parse this test content
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: tempFolderURL.appendingPathComponent("no-sgf-test.docc"))
        try workspace.registerProvider(dataProvider)
        
        // Verify all articles were loaded in the context
        XCTAssertEqual(context.knownIdentifiers.count, 2)
        
        // Verify /documentation/ReleaseNotes is a root node
        XCTAssertEqual(context.rootModules.map({ $0.url.path }), ["/documentation/ReleaseNotes"])
        
        // Verify the root was crawled
        XCTAssertEqual(context.topicGraph.edges[ResolvedTopicReference(bundleIdentifier: "com.test.example", path: "/documentation/ReleaseNotes", sourceLanguage: .swift)]?.map({ $0.url.path }),
                       ["/documentation/TestBundle/ReleaseNotes-1.2"])
    }

    func testWarnForSidecarRootPage() throws {
        let tempFolderURL = try createTempFolder(content: [
            Folder(name: "no-sgf-test.docc", content: [
                // Root page for the collection
                TextFile(name: "ReleaseNotes.md", utf8Content: """
                # Release Notes
                @Metadata {
                   @TechnologyRoot
                }
                Learn about recent changes.
                ## Topics
                ### Release Notes
                 - <doc:documentation/TechnologyX/ReleaseNotes-1.2>
                """),
                // A sidecar documentation file
                TextFile(name: "MyClass.md", utf8Content: """
                # ``ReleaseNotes/MyClass``
                @Metadata {
                   @TechnologyRoot
                }
                """),
                InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            ]),
        ])
        
        // Parse this test content
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: tempFolderURL.appendingPathComponent("no-sgf-test.docc"))
        try workspace.registerProvider(dataProvider)
        
        // Verify that we emit a warning when trying to make a symbol a root page
        XCTAssertTrue(context.problems.contains(where: { problem -> Bool in
            return problem.diagnostic.identifier == "org.swift.docc.UnexpectedTechnologyRoot"
                && problem.diagnostic.source?.path == "ReleaseNotes/MyClass"
        }))
    }
    
}
