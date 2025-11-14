/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocCUtilities

class URL_RelativeTests: XCTestCase {

    func testPathsRelativeToParents() {
        let url = URL(fileURLWithPath: "/Users/username/Documents/Some Folder/Some Document.txt")

        XCTAssertEqual(url.relative(to: URL(fileURLWithPath: "/Users/username/Documents/Some Folder/"))?.path,
                       "Some Document.txt")
        XCTAssertEqual(url.relative(to: URL(fileURLWithPath: "/Users/username/Documents/"))?.path,
                       "Some Folder/Some Document.txt")
        XCTAssertEqual(url.relative(to: URL(fileURLWithPath: "/Users/username/"))?.path,
                       "Documents/Some Folder/Some Document.txt")
        XCTAssertEqual(url.relative(to: URL(fileURLWithPath: "/Users/"))?.path,
                       "username/Documents/Some Folder/Some Document.txt")
        XCTAssertEqual(url.relative(to: URL(fileURLWithPath: "/"))?.path,
                       "Users/username/Documents/Some Folder/Some Document.txt")
    }

    func testPathsRelativeToChildren() {
        let url = URL(fileURLWithPath: "/Users/username/Some File.txt")

        XCTAssertEqual(url.relative(to: URL(fileURLWithPath: "/Users/username/Documents/Some/Nested/Folders/"))?.path,
                       "../../../../Some File.txt")
        XCTAssertEqual(url.relative(to: URL(fileURLWithPath: "/Users/username/Documents/Some/Nested/"))?.path,
                       "../../../Some File.txt")
        XCTAssertEqual(url.relative(to: URL(fileURLWithPath: "/Users/username/Documents/Some/"))?.path,
                       "../../Some File.txt")
        XCTAssertEqual(url.relative(to: URL(fileURLWithPath: "/Users/username/Documents/"))?.path,
                       "../Some File.txt")
    }

    func testPathsRelativeToSiblingsChildren() {
        let url = URL(fileURLWithPath: "/Users/username/Documents/Some Document.txt")

        XCTAssertEqual(url.relative(to: URL(fileURLWithPath: "/Users/username/Desktop/"))?.path,
                       "../Documents/Some Document.txt")
        XCTAssertEqual(url.relative(to: URL(fileURLWithPath: "/Users/username/Desktop/Some/"))?.path,
                       "../../Documents/Some Document.txt")
        XCTAssertEqual(url.relative(to: URL(fileURLWithPath: "/Users/username/Desktop/Some/Nested/"))?.path,
                       "../../../Documents/Some Document.txt")
        XCTAssertEqual(url.relative(to: URL(fileURLWithPath: "/Users/username/Desktop/Some/Nested/Folders/"))?.path,
                       "../../../../Documents/Some Document.txt")
    }

    func testPathsRelativeToSelf() {
        let url = URL(fileURLWithPath: "/Users/username/Documents/Some Document.txt")

        XCTAssertEqual(url.relative(to: url)?.path, "")
    }

    func testPathsRelativeToSibling() {
        let url = URL(fileURLWithPath: "/Users/username/Documents/Some Document.txt")

        XCTAssertEqual(url.relative(to: URL(fileURLWithPath: "/Users/username/Documents/Another Document.txt"))?.path,
                       "../Some Document.txt")
    }

}
