/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@testable import SwiftDocC
import XCTest

class SortByKeyPathTests: XCTestCase {
    private static var testURLs: [URL] = [
        URL(fileURLWithPath: "/foo/bar"),
        URL(fileURLWithPath: "/bar/foo"),
        URL(fileURLWithPath: "/123/345"),
        URL(fileURLWithPath: "/456/789"),
        URL(fileURLWithPath: "/wxy/abc"),
    ]
    
    func testSort() {
        var urls = Self.testURLs
        
        urls.shuffle()
        urls.sort(by: \.path)
        XCTAssertEqual(
            urls,
            [
                URL(fileURLWithPath: "/123/345"),
                URL(fileURLWithPath: "/456/789"),
                URL(fileURLWithPath: "/bar/foo"),
                URL(fileURLWithPath: "/foo/bar"),
                URL(fileURLWithPath: "/wxy/abc"),
            ]
        )
        
        urls.shuffle()
        urls.sort(by: \.lastPathComponent)
        XCTAssertEqual(
            urls,
            [
                URL(fileURLWithPath: "/123/345"),
                URL(fileURLWithPath: "/456/789"),
                URL(fileURLWithPath: "/wxy/abc"),
                URL(fileURLWithPath: "/foo/bar"),
                URL(fileURLWithPath: "/bar/foo"),
            ]
        )
    }

    func testSorted() {
        XCTAssertEqual(
            Self.testURLs.shuffled().sorted(by: \.path),
            [
                URL(fileURLWithPath: "/123/345"),
                URL(fileURLWithPath: "/456/789"),
                URL(fileURLWithPath: "/bar/foo"),
                URL(fileURLWithPath: "/foo/bar"),
                URL(fileURLWithPath: "/wxy/abc"),
            ]
        )
        
        XCTAssertEqual(
            Self.testURLs.shuffled().sorted(by: \.lastPathComponent),
            [
                URL(fileURLWithPath: "/123/345"),
                URL(fileURLWithPath: "/456/789"),
                URL(fileURLWithPath: "/wxy/abc"),
                URL(fileURLWithPath: "/foo/bar"),
                URL(fileURLWithPath: "/bar/foo"),
            ]
        )
    }
}
