/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import DocCHTML

struct WordBreakTests {
    @Test
    func insertsWordBreaks() {
        assertWordBreaks(for: "doSomething<Generic>(withFirst:andSecond:)", matches: """
        do
        <wbr>
        Something&lt;
        <wbr>
        Generic>(
        <wbr>
        with
        <wbr>
        First:
        <wbr>
        and
        <wbr>
        Second:)
        """)
        
        assertWordBreaks(for: "doSomethingWithFirst:andSecond:", matches: """
        do
        <wbr>
        Something
        <wbr>
        With
        <wbr>
        First:
        <wbr>
        and
        <wbr>
        Second:
        """)
        
        assertWordBreaks(for: "SomeVeryLongClassName", matches: """
        Some
        <wbr>
        Very
        <wbr>
        Long
        <wbr>
        Class
        <wbr>
        Name
        """)
        
        assertWordBreaks(for: "TLASomeClass", matches: """
        TLASome
        <wbr>
        Class
        """)
    }
    
    private func assertWordBreaks(
        for symbolName: String,
        matches expectedHTML: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        line: UInt = #line
    ) {
        let withWordBreaks = RenderHelpers.wordBreak(symbolName: symbolName)
            .map { String(decoding: HTMLFormatter.format($0), as: UTF8.self) }
            .joined(separator: "\n")
        
        #expect(withWordBreaks == expectedHTML, sourceLocation: sourceLocation)
    }
}
