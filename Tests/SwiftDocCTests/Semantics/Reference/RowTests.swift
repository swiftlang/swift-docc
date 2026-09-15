/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import Testing
@testable public import SwiftDocC
import Markdown

struct RowTests {
    @Test(arguments: [
        """
        @Row
        """,

        """
        @Row {

        }
        """,
    ])
    func warnsAboutRowWithoutColumns(directive: String) async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            directive
        }

        #expect(row != nil)

        #expect(diagnostics == ["1: warning – org.swift.docc.HasAtLeastOne<Row, Column>"])

        #expect(renderBlockContent.count == 1)
        #expect(renderBlockContent.first == .row(.init(numberOfColumns: 0, columns: [])))
    }
    
    @Test func unknownArguments() async throws {
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

        #expect(row != nil)
        #expect(diagnostics == [
            "1: warning – org.swift.docc.UnknownArgument",
            "2: warning – org.swift.docc.UnknownArgument",
            "6: warning – org.swift.docc.HasArgument.size.ConversionFailed",
        ])

        #expect(renderBlockContent.count == 1)
        #expect(renderBlockContent.first == .row(RenderBlockContent.Row(
            numberOfColumns: 6,
            columns: [
                RenderBlockContent.Row.Column(size: 1, alignment: .leading, content: ["Hello there."]),
                RenderBlockContent.Row.Column(size: 1, alignment: .leading, content: ["Hello there."]),
                RenderBlockContent.Row.Column(size: 4, alignment: .leading, content: ["Hello there."])
            ]
        )))
    }

    @Test func unknownArgumentInNestedRow() async throws {
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

        #expect(row != nil)
        #expect(diagnostics == ["6: warning – org.swift.docc.UnknownArgument"])
    }
    
    @Test func invalidChildrenNestedRow() async throws {
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

        #expect(row != nil)
        #expect(diagnostics == [
            "1: warning – org.swift.docc.HasAtLeastOne<Row, Column>",
            "1: warning – org.swift.docc.Row.UnexpectedContent",
            "2: warning – org.swift.docc.HasOnlyKnownDirectives",
        ])

        #expect(renderBlockContent.count == 1)
        #expect(renderBlockContent.first == .row(RenderBlockContent.Row(
            numberOfColumns: 0,
            columns: []
        )))
    }

    @Test func invalidChildrenNestedColumn() async throws {
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

        #expect(row != nil)
        #expect(diagnostics == ["3: warning – org.swift.docc.HasOnlyKnownDirectives"])

        #expect(renderBlockContent.count == 1)
        #expect(renderBlockContent.first == .row(RenderBlockContent.Row(
            numberOfColumns: 1,
            columns: [
                RenderBlockContent.Row.Column(size: 1, alignment: .leading, content: [])
            ]
        )))
    }

    @Test func emptyColumn() async throws {
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

        #expect(row != nil)
        #expect(diagnostics == [])

        #expect(renderBlockContent.count == 1)
        #expect(renderBlockContent.first == .row(RenderBlockContent.Row(
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
        )))
    }
    
    @Test func nestedRowAndColumns() async throws {
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

        #expect(row != nil)
        #expect(diagnostics == [])

        #expect(renderBlockContent.count == 1)
        #expect(renderBlockContent.first == .row(RenderBlockContent.Row(
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
        )))
    }

    @Test func columnWithAlignmentOnly() async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            """
            @Row {
                @Column(alignment: center) {
                    Centered content
                }
            }
            """
        }

        #expect(row != nil)
        #expect(diagnostics == [])

        #expect(renderBlockContent.count == 1)
        #expect(renderBlockContent.first == .row(RenderBlockContent.Row(
            numberOfColumns: 1,
            columns: [
                RenderBlockContent.Row.Column(
                    size: 1,
                    alignment: .center,
                    content: ["Centered content"]
                )
            ]
        )))
    }

    @Test func columnWithSizeAndAlignment() async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            """
            @Row {
                @Column(size: 2, alignment: trailing) {
                    Trailing aligned
                }
            }
            """
        }

        #expect(row != nil)
        #expect(diagnostics == [])

        #expect(renderBlockContent.count == 1)
        #expect(renderBlockContent.first == .row(RenderBlockContent.Row(
            numberOfColumns: 2,
            columns: [
                RenderBlockContent.Row.Column(
                    size: 2,
                    alignment: .trailing,
                    content: ["Trailing aligned"]
                )
            ]
        )))
    }

    @Test func columnWithoutAlignment() async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            """
            @Row {
                @Column(size: 2) {
                    Default alignment
                }
            }
            """
        }

        #expect(row != nil)
        #expect(diagnostics == [])

        #expect(renderBlockContent.count == 1)
        #expect(renderBlockContent.first == .row(RenderBlockContent.Row(
            numberOfColumns: 2,
            columns: [
                RenderBlockContent.Row.Column(
                    size: 2,
                    alignment: .leading,
                    content: ["Default alignment"]
                )
            ]
        )))
    }

    @Test(arguments: [
        ("alignment: invalid", 1),
        ("alignment: true", 1),
        ("size: 2, alignment: 123", 2),
    ])
    func columnWithUnparseableAlignment(columnArgs: String, expectedColumnSize: Int) async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            """
            @Row {
                @Column(\(columnArgs)) {
                    Content
                }
            }
            """
        }

        #expect(row != nil)
        #expect(diagnostics == ["2: warning – org.swift.docc.HasArgument.alignment.ConversionFailed"])

        #expect(renderBlockContent.count == 1)
        if case let .row(row) = renderBlockContent.first {
            #expect(row.columns.count == 1)
            #expect(row.columns.first?.size == expectedColumnSize)
            #expect(row.columns.first?.alignment == .leading)
        } else {
            Issue.record("Expected row but got \(String(describing: renderBlockContent.first))")
        }
    }

    @Test(arguments: [
        ("leading", RenderBlockContent.Row.Column.Alignment.leading),
        ("center", .center),
        ("trailing", .trailing),
    ])
    func columnAlignment(alignmentString: String, expectedAlignment: RenderBlockContent.Row.Column.Alignment) async throws {
        let (renderBlockContent, diagnostics, row) = try await parseDirective(Row.self) {
            """
            @Row {
                @Column(alignment: \(alignmentString)) {
                    Content
                }
            }
            """
        }

        #expect(row != nil)
        #expect(diagnostics == [])
        #expect(renderBlockContent.count == 1)

        if case let .row(row) = renderBlockContent.first {
            #expect(row.columns.count == 1)
            #expect(row.columns.first?.alignment == expectedAlignment)
        } else {
            Issue.record("Expected row but got \(String(describing: renderBlockContent.first))")
        }
    }

    @Test func multipleColumnsWithMixedAlignment() async throws {
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

        #expect(row != nil)
        #expect(diagnostics == [])

        #expect(renderBlockContent.count == 1)
        #expect(renderBlockContent.first == .row(RenderBlockContent.Row(
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
        )))
    }

    @Test func multipleColumnsWithInvalidAlignment() async throws {
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

        #expect(row != nil)
        #expect(diagnostics == ["6: warning – org.swift.docc.HasArgument.alignment.ConversionFailed"])

        #expect(renderBlockContent.count == 1)
        #expect(renderBlockContent.first == .row(RenderBlockContent.Row(
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
        )))
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
