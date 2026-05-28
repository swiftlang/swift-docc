/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable public import SwiftDocC
import Markdown

class RowTests: XCTestCase {
    func testNoColumns() async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            """
            @Row
            """
        }
        
        XCTAssertNotNil(row)
        
        XCTAssertEqual(
            diagnostics,
            ["1: warning – org.swift.docc.HasAtLeastOne<Row, Column>"]
        )
        
        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .row(.init(numberOfColumns: 0, columns: []))
        )
    }
    
    func testInvalidParameters() async throws {
        do {
            let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
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
                diagnostics,
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
                        RenderBlockContent.Row.Column(size: 1, alignment: .leading, content: ["Hello there."]),
                        RenderBlockContent.Row.Column(size: 1, alignment: .leading, content: ["Hello there."]),
                        RenderBlockContent.Row.Column(size: 4, alignment: .leading, content: ["Hello there."])
                    ]
                ))
            )
        }
        
        do {
            let (_, diagnostics, row) = try await parseDirective(Row.self) {
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
                diagnostics,
                [
                    "6: warning – org.swift.docc.UnknownArgument",
                ]
            )
        }
    }
    
    func testInvalidChildren() async throws {
        do {
            let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
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
                diagnostics,
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
            let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
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
                diagnostics,
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
                        RenderBlockContent.Row.Column(size: 1, alignment: .leading, content: [])
                    ]
                ))
            )
        }
        
        do {
            let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
                """
                @Row {

                }
                """
            }
            
            XCTAssertNotNil(row)
            XCTAssertEqual(
                diagnostics,
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
    
    func testEmptyColumn() async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
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
        XCTAssertEqual(diagnostics, [])

        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .row(RenderBlockContent.Row(
                numberOfColumns: 5,
                columns: [
                    RenderBlockContent.Row.Column(size: 1, alignment: .leading, content: []),
                    
                    RenderBlockContent.Row.Column(
                        size: 3,
                        alignment: .leading,
                        content: ["This is a wiiiiddde column."]
                    ),
                    
                    RenderBlockContent.Row.Column(size: 1, alignment: .leading, content: []),
                ]
            ))
        )
    }
    
    func testNestedRowAndColumns() async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
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
        XCTAssertEqual(diagnostics, [])
        
        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .row(RenderBlockContent.Row(
                numberOfColumns: 1,
                columns: [
                    RenderBlockContent.Row.Column(
                        size: 1,
                        alignment: .leading,
                        content: [
                            .row(RenderBlockContent.Row(
                                numberOfColumns: 2,
                                columns: [
                                    RenderBlockContent.Row.Column(size: 1, alignment: .leading, content: ["Hello"]),
                                    RenderBlockContent.Row.Column(size: 1, alignment: .leading, content: ["There"]),
                                ]
                            ))
                        ]
                    )
                ]
            ))
        )
    }

    func testColumnWithAlignmentOnly() async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            """
            @Row {
                @Column(alignment: center) {
                    Centered content
                }
            }
            """
        }

        XCTAssertNotNil(row)
        XCTAssertEqual(diagnostics, [])

        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .row(RenderBlockContent.Row(
                numberOfColumns: 1,
                columns: [
                    RenderBlockContent.Row.Column(
                        size: 1,
                        alignment: .center,
                        content: ["Centered content"]
                    )
                ]
            ))
        )
    }

    func testColumnWithSizeAndAlignment() async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            """
            @Row {
                @Column(size: 2, alignment: trailing) {
                    Trailing aligned
                }
            }
            """
        }

        XCTAssertNotNil(row)
        XCTAssertEqual(diagnostics, [])

        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .row(RenderBlockContent.Row(
                numberOfColumns: 2,
                columns: [
                    RenderBlockContent.Row.Column(
                        size: 2,
                        alignment: .trailing,
                        content: ["Trailing aligned"]
                    )
                ]
            ))
        )
    }

    func testColumnWithoutAlignment() async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            """
            @Row {
                @Column(size: 2) {
                    Default alignment
                }
            }
            """
        }

        XCTAssertNotNil(row)
        XCTAssertEqual(diagnostics, [])

        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .row(RenderBlockContent.Row(
                numberOfColumns: 2,
                columns: [
                    RenderBlockContent.Row.Column(
                        size: 2,
                        alignment: .leading,
                        content: ["Default alignment"]
                    )
                ]
            ))
        )
    }

    func testInvalidAlignmentValue() async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            """
            @Row {
                @Column(alignment: invalid) {
                    Content
                }
            }
            """
        }

        XCTAssertNotNil(row)
        XCTAssertEqual(
            diagnostics,
            ["2: warning – org.swift.docc.HasArgument.alignment.ConversionFailed"]
        )

        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .row(RenderBlockContent.Row(
                numberOfColumns: 1,
                columns: [
                    RenderBlockContent.Row.Column(
                        size: 1,
                        alignment: .leading,
                        content: ["Content"]
                    )
                ]
            ))
        )
    }

    func testAllAlignmentValues() async throws {
        let alignmentValues: [(String, RenderBlockContent.Row.Column.Alignment)] = [
            ("leading", .leading),
            ("center", .center),
            ("trailing", .trailing)
        ]

        for (stringValue, expectedAlignment) in alignmentValues {
            let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
                """
                @Row {
                    @Column(alignment: \(stringValue)) {
                        Content
                    }
                }
                """
            }

            XCTAssertNotNil(row)
            XCTAssertEqual(diagnostics, [])
            XCTAssertEqual(renderBlockContent.count, 1)

            if case let .row(row) = renderBlockContent.first {
                XCTAssertEqual(row.columns.count, 1)
                XCTAssertEqual(row.columns.first?.alignment, expectedAlignment)
            } else {
                XCTFail("Expected row but got \(String(describing: renderBlockContent.first))")
            }
        }
    }

    func testMultipleColumnsWithMixedAlignment() async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            """
            @Row {
                @Column(size: 1, alignment: leading) {
                    Left aligned
                }

                @Column(size: 1, alignment: center) {
                    Center aligned
                }

                @Column(size: 1) {
                    Default aligned
                }
            }
            """
        }

        XCTAssertNotNil(row)
        XCTAssertEqual(diagnostics, [])

        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .row(RenderBlockContent.Row(
                numberOfColumns: 3,
                columns: [
                    RenderBlockContent.Row.Column(
                        size: 1,
                        alignment: .leading,
                        content: ["Left aligned"]
                    ),
                    RenderBlockContent.Row.Column(
                        size: 1,
                        alignment: .center,
                        content: ["Center aligned"]
                    ),
                    RenderBlockContent.Row.Column(
                        size: 1,
                        alignment: .leading,
                        content: ["Default aligned"]
                    )
                ]
            ))
        )
    }

    func testAlignmentWithInvalidType() async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            """
            @Row {
                @Column(alignment: true) {
                    Content
                }
            }
            """
        }

        XCTAssertNotNil(row)
        XCTAssertEqual(
            diagnostics,
            ["2: warning – org.swift.docc.HasArgument.alignment.ConversionFailed"]
        )

        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .row(RenderBlockContent.Row(
                numberOfColumns: 1,
                columns: [
                    RenderBlockContent.Row.Column(
                        size: 1,
                        alignment: .leading,
                        content: ["Content"]
                    )
                ]
            ))
        )
    }

    func testAlignmentWithSizeInvalidType() async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            """
            @Row {
                @Column(size: 2, alignment: 123) {
                    Content
                }
            }
            """
        }

        XCTAssertNotNil(row)
        XCTAssertEqual(
            diagnostics,
            ["2: warning – org.swift.docc.HasArgument.alignment.ConversionFailed"]
        )

        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .row(RenderBlockContent.Row(
                numberOfColumns: 2,
                columns: [
                    RenderBlockContent.Row.Column(
                        size: 2,
                        alignment: .leading,
                        content: ["Content"]
                    )
                ]
            ))
        )
    }

    func testMultipleColumnsWithInvalidAlignment() async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            """
            @Row {
                @Column(alignment: leading) {
                    Valid
                }

                @Column(alignment: badvalue) {
                    Invalid
                }

                @Column(alignment: trailing) {
                    Valid
                }
            }
            """
        }

        XCTAssertNotNil(row)
        XCTAssertEqual(
            diagnostics,
            ["6: warning – org.swift.docc.HasArgument.alignment.ConversionFailed"]
        )

        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .row(RenderBlockContent.Row(
                numberOfColumns: 3,
                columns: [
                    RenderBlockContent.Row.Column(
                        size: 1,
                        alignment: .leading,
                        content: ["Valid"]
                    ),
                    RenderBlockContent.Row.Column(
                        size: 1,
                        alignment: .leading,
                        content: ["Invalid"]
                    ),
                    RenderBlockContent.Row.Column(
                        size: 1,
                        alignment: .trailing,
                        content: ["Valid"]
                    )
                ]
            ))
        )
    }

}

// Use fully-qualified types to silence a warning about retroactively conforming a type from another module to a new protocol (SE-0364).
// The `@retroactive` attribute is new in the Swift 6 compiler. The backwards compatible syntax for a retroactive conformance is fully-qualified types.
//
// It is safe to add a retroactively conformance here because the other module (SwiftDocC) is in the same package.
extension SwiftDocC.RenderBlockContent: Swift.ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = RenderBlockContent.paragraph(Paragraph(inlineContent: [.text(value)]))
    }
}
