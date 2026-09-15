/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import SwiftDocC

struct URL_RelativeTests {
    
    @Test(arguments: [
        ("/Users/username/Documents/Some Folder/", "Some Document.txt"),
        ("/Users/username/Documents/", "Some Folder/Some Document.txt"),
        ("/Users/username/", "Documents/Some Folder/Some Document.txt"),
        ("/Users/", "username/Documents/Some Folder/Some Document.txt"),
        ("/", "Users/username/Documents/Some Folder/Some Document.txt"),
    ])
    func usesPlainSuffixWhenStartingPointIsAncestor(startingPath: String, expected: String) {
        let url = URL(fileURLWithPath: "/Users/username/Documents/Some Folder/Some Document.txt")
        #expect(url.relative(to: URL(fileURLWithPath: startingPath))?.path == expected)
    }
    
    @Test(arguments: [
        ("/Users/username/Documents/Some/Nested/Folders/", "../../../../Some File.txt"),
        ("/Users/username/Documents/Some/Nested/", "../../../Some File.txt"),
        ("/Users/username/Documents/Some/", "../../Some File.txt"),
        ("/Users/username/Documents/", "../Some File.txt"),
    ])
    func usesParentReferencesWhenStartingPointIsDeeper(startingPath: String, expected: String) {
        let url = URL(fileURLWithPath: "/Users/username/Some File.txt")
        #expect(url.relative(to: URL(fileURLWithPath: startingPath))?.path == expected)
    }
    
    @Test(arguments: [
        ("/Users/username/Desktop/", "../Documents/Some Document.txt"),
        ("/Users/username/Desktop/Some/", "../../Documents/Some Document.txt"),
        ("/Users/username/Desktop/Some/Nested/", "../../../Documents/Some Document.txt"),
        ("/Users/username/Desktop/Some/Nested/Folders/", "../../../../Documents/Some Document.txt"),
    ])
    func combinesParentReferencesAndForwardPathForUnrelatedSubtree(startingPath: String, expected: String) {
        let url = URL(fileURLWithPath: "/Users/username/Documents/Some Document.txt")
        #expect(url.relative(to: URL(fileURLWithPath: startingPath))?.path == expected)
    }
    
    @Test
    func returnsEmptyPathWhenStartingPointIsSelf() {
        let url = URL(fileURLWithPath: "/Users/username/Documents/Some Document.txt")
        #expect(url.relative(to: url)?.path == "")
    }
    
    @Test
    func usesSingleParentReferenceForSibling() {
        let url = URL(fileURLWithPath: "/Users/username/Documents/Some Document.txt")
        #expect(url.relative(to: URL(fileURLWithPath: "/Users/username/Documents/Another Document.txt"))?.path
                == "../Some Document.txt")
    }
}
