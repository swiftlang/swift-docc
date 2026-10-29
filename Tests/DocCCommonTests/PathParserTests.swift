/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import DocCCommon

struct PathParserTests {
    @Test
    func splitsDocumentationLinksFromArchiveIDs() async throws {
        let split = PathParser.split(documentationLink:)
        
        #expect(split("")     == nil)
        #expect(split("doc:") == nil)
        #expect(split("http://example.com") == nil)
        
        #expect(split("doc:Something")  == (link:  "Something", archiveID: nil))
        #expect(split("doc:/Something") == (link: "/Something", archiveID: nil))
        
        #expect(split("doc://com.example")           == (link: "",           archiveID: "com.example"))
        #expect(split("doc://com.example/Something") == (link: "/Something", archiveID: "com.example"))
        
        
        #expect(split("doc://a/b") == (link: "/b", archiveID: "a"))
    }
}

private func == (lhs: PathParser.LinkAndArchiveID?, rhs: (link: String, archiveID: String?)) -> Bool {
    guard let lhs else { return false }
    
    return lhs.link      == rhs.link
        && lhs.archiveID == rhs.archiveID?[...]
}
