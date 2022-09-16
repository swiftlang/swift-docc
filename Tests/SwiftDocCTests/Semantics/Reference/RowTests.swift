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

class RowTests: XCTestCase {
    func testNoColumns() throws {
        let (renderBlockContent, problems, row) = try parseDirective(Row.self) {
            """
            @Row
            """
        }
        
        XCTAssertNotNil(row)
        
        XCTAssertEqual(
            problems,
            ["1: warning – org.swift.docc.HasAtLeastOne<Row, Column>"]
        )
        
        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .row(.init(numberOfColumns: 0, columns: []))
        )
    }
    
    func testInvalidParameters() throws {
        do {
            let (renderBlockContent, problems, row) = try parseDirective(Row.self) {
                """
                @Row(columns: 3) {
                    @Column(what: true) {
                        Hello there.
                    }
                
                    @Column(size: true) {
                        Hello there.
                    }
                
                    @Column(size: 4) {
                        Hello there.
                    }
                }
                """
            }
            
            XCTAssertNotNil(row)
            XCTAssertEqual(
                problems,
                [
                    "1: warning – org.swift.docc.UnknownArgument",
                    "2: warning – org.swift.docc.UnknownArgument",
                    "6: warning – org.swift.docc.HasArgument.size.ConversionFailed",
                ]
            )
            
            XCTAssertEqual(renderBlockContent.count, 1)
            XCTAssertEqual(
                renderBlockContent.first,
                .row(RenderBlockContent.Row(
                    numberOfColumns: 6,
                    columns: [
                        RenderBlockContent.Row.Column(size: 1, content: ["Hello there."]),
                        RenderBlockContent.Row.Column(size: 1, content: ["Hello there."]),
                        RenderBlockContent.Row.Column(size: 4, content: ["Hello there."])
                    ]
                ))
            )
        }
        
        do {
            let (_, problems, row) = try parseDirective(Row.self) {
                """
                @Row(numberOfColumns: 3) {
                    @Column(size: 3) {
                        @Row {
                            @Column {
                                @Row {
                                    @Column(weird: false)
                                }
                            }
                        }
                    }
                }
                """
            }
            
            XCTAssertNotNil(row)
            XCTAssertEqual(
                problems,
                [
                    "6: warning – org.swift.docc.UnknownArgument",
                ]
            )
        }
    }
    
    func testInvalidChildren() throws {
        do {
            let (renderBlockContent, problems, row) = try parseDirective(Row.self) {
                """
                @Row {
                    @Row {
                        @Column {
                            Hello there.
                        }
                    }
                }
                """
            }
            
            XCTAssertNotNil(row)
            XCTAssertEqual(
                problems,
                [
                    "1: warning – org.swift.docc.HasAtLeastOne<Row, Column>",
                    "1: warning – org.swift.docc.Row.UnexpectedContent",
                    "2: warning – org.swift.docc.HasOnlyKnownDirectives",
                ]
            )
            
            XCTAssertEqual(renderBlockContent.count, 1)
            XCTAssertEqual(
                renderBlockContent.first,
                .row(RenderBlockContent.Row(
                    numberOfColumns: 0,
                    columns: []
                ))
            )
        }
        
        do {
            let (renderBlockContent, problems, row) = try parseDirective(Row.self) {
                """
                @Row {
                    @Column {
                        @Column {
                            Hello there.
                        }
                    }
                }
                """
            }
            
            XCTAssertNotNil(row)
            XCTAssertEqual(
                problems,
                [
                    "3: warning – org.swift.docc.HasOnlyKnownDirectives",
                ]
            )
            
            XCTAssertEqual(renderBlockContent.count, 1)
            XCTAssertEqual(
                renderBlockContent.first,
                .row(RenderBlockContent.Row(
                    numberOfColumns: 1,
                    columns: [
                        RenderBlockContent.Row.Column(size: 1, content: [])
                    ]
                ))
            )
        }
        
        do {
            let (renderBlockContent, problems, row) = try parseDirective(Row.self) {
                """
                @Row {

                }
                """
            }
            
            XCTAssertNotNil(row)
            XCTAssertEqual(
                problems,
                [
                    "1: warning – org.swift.docc.HasAtLeastOne<Row, Column>",
                ]
            )
            
            XCTAssertEqual(renderBlockContent.count, 1)
            XCTAssertEqual(
                renderBlockContent.first,
                .row(RenderBlockContent.Row(numberOfColumns: 0, columns: []))
            )
        }
    }
    
    func testEmptyColumn() throws {
        let (renderBlockContent, problems, row) = try parseDirective(Row.self) {
            """
            @Row {
                @Column
            
                @Column(size: 3) {
                    This is a wiiiiddde column.
                }
            
                @Column
            }
            """
        }
        
        XCTAssertNotNil(row)
        XCTAssertEqual(problems, [])
        
        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .row(RenderBlockContent.Row(
                numberOfColumns: 5,
                columns: [
                    RenderBlockContent.Row.Column(size: 1, content: []),
                    
                    RenderBlockContent.Row.Column(
                        size: 3,
                        content: ["This is a wiiiiddde column."]
                    ),
                    
                    RenderBlockContent.Row.Column(size: 1, content: []),
                ]
            ))
        )
    }
    
    func testNestedRowAndColumns() throws {
        let (renderBlockContent, problems, row) = try parseDirective(Row.self) {
            """
            @Row {
                @Column {
                    @Row {
                        @Column {
                            Hello
                        }
            
                        @Column {
                            There
                        }
                    }
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
                numberOfColumns: 1,
                columns: [
                    RenderBlockContent.Row.Column(
                        size: 1,
                        content: [
                            .row(RenderBlockContent.Row(
                                numberOfColumns: 2,
                                columns: [
                                    RenderBlockContent.Row.Column(size: 1, content: ["Hello"]),
                                    RenderBlockContent.Row.Column(size: 1, content: ["There"]),
                                ]
                            ))
                        ]
                    )
                ]
            ))
        )
    }

}

extension RenderBlockContent: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = RenderBlockContent.paragraph(Paragraph(inlineContent: [.text(value)]))
    }
}
