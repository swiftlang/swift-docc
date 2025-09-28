/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import HTML

final class MarkupRenderer_WordBreakTests: XCTestCase {
    func testWordBreaks() {
        assertWordBreaks(for: "doSomething<Generic>(withFirst:andSecond:)", matches: """
        do
        <wbr/>
        Something&lt;
        <wbr/>
        Generic&gt;(
        <wbr/>
        with
        <wbr/>
        First:
        <wbr/>
        and
        <wbr/>
        Second:)
        """)
        
        assertWordBreaks(for: "doSomethingWithFirst:andSecond:", matches: """
        do
        <wbr/>
        Something
        <wbr/>
        With
        <wbr/>
        First:
        <wbr/>
        and
        <wbr/>
        Second:
        """)
        
        assertWordBreaks(for: "SomeVeryLongClassName", matches: """
        Some
        <wbr/>
        Very
        <wbr/>
        Long
        <wbr/>
        Class
        <wbr/>
        Name
        """)
        
        assertWordBreaks(for: "TLASomeClass", matches: """
        TLASome
        <wbr/>
        Class
        """)
    }
    
    private func assertWordBreaks(
        for symbolName: String,
        matches expectedHTML: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let withWordBreaks = MarkupRenderer<TestLinkProvider>.wordBreak(symbolName: symbolName)
            .map { $0.xmlString(options: [.nodePrettyPrint, .nodeCompactEmptyElement] )}
            .joined(separator: "\n")
        
        XCTAssertEqual(withWordBreaks, expectedHTML, file: file, line: line)
    }
}
