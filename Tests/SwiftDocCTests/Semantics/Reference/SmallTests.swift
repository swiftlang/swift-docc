/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable import SwiftDocC
import Markdown

class SmallTests: XCTestCase {
    func testNoContent() throws {
        let (renderBlockContent, problems, small) = try parseDirective(Small.self) {
            """
            @Small
            """
        }
        
        XCTAssertNotNil(small)
        
        XCTAssertEqual(
            problems,
            ["1: warning – org.swift.docc.Small.HasContent"]
        )
        
        XCTAssertEqual(renderBlockContent, [])
    }
    
    func testHasContent() throws {
        do {
            let (renderBlockContent, problems, small) = try parseDirective(Small.self) {
                """
                @Small {
                    This is my copyright text.
                }
                """
            }
            
            XCTAssertNotNil(small)
            
            XCTAssertEqual(problems, [])
            
            XCTAssertEqual(renderBlockContent.count, 1)
            XCTAssertEqual(
                renderBlockContent.first,
                .small(RenderBlockContent.Small(
                    inlineContent: [.text("This is my copyright text.")]
                ))
            )
        }
        
        do {
            let (renderBlockContent, problems, small) = try parseDirective(Small.self) {
                """
                @Small {
                    This is my copyright text.
                
                    And a second line of copyright text.
                }
                """
            }
            
            XCTAssertNotNil(small)
            
            XCTAssertEqual(problems, [])
            
            XCTAssertEqual(renderBlockContent.count, 2)
            XCTAssertEqual(
                renderBlockContent,
                [
                    .small(RenderBlockContent.Small(
                        inlineContent: [.text("This is my copyright text.")]
                    )),
                    .small(RenderBlockContent.Small(
                        inlineContent: [.text("And a second line of copyright text.")]
                    )),
                ]
            )
        }
        
        do {
            let (renderBlockContent, problems, small) = try parseDirective(Small.self) {
                """
                @Small {
                    This is my *formatted* `copyright` **text**.
                }
                """
            }
            
            XCTAssertNotNil(small)
            
            XCTAssertEqual(problems, [])
            
            XCTAssertEqual(renderBlockContent.count, 1)
            XCTAssertEqual(
                renderBlockContent.first,
                .small(RenderBlockContent.Small(
                    inlineContent: [
                        .text("This is my "),
                        .emphasis(inlineContent: [.text("formatted")]),
                        .text(" "),
                        .codeVoice(code: "copyright"),
                        .text(" "),
                        .strong(inlineContent: [.text("text")]),
                        .text(".")
                    ]
                ))
            )
        }
    }
    
    func testEmitsWarningWhenContainsStructuredMarkup() throws {
        do {
            let (renderBlockContent, problems, small) = try parseDirective(Small.self) {
                """
                @Small {
                    This is my copyright text.
                
                    @Row {
                        @Column {
                            This is copyright text in a column.
                        }
                
                        @Column {
                            Second column.
                        }
                    }
                
                    And final copyright text.
                }
                """
            }
            
            XCTAssertNotNil(small)
            XCTAssertEqual(problems, ["4: warning – org.swift.docc.HasOnlyKnownDirectives"])
            XCTAssertEqual(renderBlockContent.count, 3)
        }
    }
    
    func testSmallInsideOfColumn() throws {
        do {
            let (renderBlockContent, problems, row) = try parseDirective(Row.self) {
                """
                @Row {
                    @Column {
                        Regular text.
                
                        @Small {
                            Small text.
                        }
                    }
                
                    @Column {
                        Second column of regular text.
                    }
                }
                """
            }
            
            XCTAssertNotNil(row)
            XCTAssertEqual(problems, [])
            XCTAssertEqual(renderBlockContent.count, 1)
            XCTAssertEqual(
                renderBlockContent.first,
                .row(RenderBlockContent.Row(
                    numberOfColumns: 2,
                    columns: [
                        RenderBlockContent.Row.Column(
                            size: 1,
                            content: [
                                "Regular text.",
                                .small(RenderBlockContent.Small(
                                    inlineContent: [.text("Small text.")]
                                )),
                            ]
                        ),
                        
                        RenderBlockContent.Row.Column(
                            size: 1,
                            content: [
                                "Second column of regular text.",
                            ]
                        ),
                    ]
                ))
            )
            
        }
    }
}
