/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import SwiftDocC

private typealias Parser = PathHierarchy.PathParser

struct PathParserTests {
    @Test
    func splitsDocumentationLinksFromArchiveIDs() async throws {
        let split = Parser.extractLinkFromVerifiedDocumentationLink(_:)
        
        #expect(split("doc:Something")  == (link:  "Something", archiveID: nil))
        #expect(split("doc:/Something") == (link: "/Something", archiveID: nil))
        
        #expect(split("doc://com.example")           == (link: "",           archiveID: "com.example"))
        #expect(split("doc://com.example/Something") == (link: "/Something", archiveID: "com.example"))
        
        // Check short strings to verify that both the 8-byte at-a-time and the 1-byte at-a-time logic is executed
        #expect(split("doc:b")     == (link:  "b", archiveID: nil))
        #expect(split("doc://a/b") == (link: "/b", archiveID: "a"))
    }
}
