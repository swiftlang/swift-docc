/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A container directive that arranges content into a grid-based row and column
/// layout.
///
/// Create a new row by creating an `@Row` that contains child `@Column` directives.
///
/// ```md
/// @Row {
///    @Column {
///       @Image(source: "icon-power-icon", alt: "A blue square containing a snowflake.") {
///          Ice power
///       }
///    }
///
///    @Column {
///       @Image(source: "fire-power-icon", alt: "A red square containing a flame.") {
///          Fire power
///       }
///    }
///
///    @Column {
///       @Image(source: "wind-power-icon", alt: "A teal square containing a breath of air.") {
///          Wind power
///       }
///    }
///
///    @Column {
///       @Image(source: "lightning-power-icon", alt: "A yellow square containing a lightning bolt.") {
///          Lightning power
///       }
///    }
/// }
/// ```
public final class Row: Semantic, AutomaticDirectiveConvertible, MarkupContaining {
    public let originalMarkup: BlockDirective
    
    @DirectiveArgumentWrapped(name: .custom("numberOfColumns"))
    public private(set) var _numberOfColumns: Int? = nil
    
    /// The columns that make up this row.
    @ChildDirective(requirements: .oneOrMore)
    public private(set) var columns: [Column]
    
    static var keyPaths: [String : AnyKeyPath] = [
        "_numberOfColumns"   : \Row.__numberOfColumns,
        "columns"           : \Row._columns,
    ]
    
    /// The number of columns in this row.
    ///
    /// This may be different then the count of ``columns`` array. For example, there may be
    /// individual columns that span multiple columns (specified with the column's
    /// ``Column/size`` argument) or the row could be not fully filled with columns.
    public var numberOfColumns: Int {
        return _numberOfColumns ?? columns.map(\.size).reduce(0, +)
    }
    
    override var children: [Semantic] {
        return columns
    }
    
    var childMarkup: [Markup] {
        return columns.flatMap(\.childMarkup)
    }
    
    @available(*, deprecated,
        message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'."
    )
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}

extension Row {
    /// A container directive that holds general markup content describing a column
    /// with a row in a grid-based layout.
    public final class Column: Semantic, AutomaticDirectiveConvertible, MarkupContaining {
        public let originalMarkup: BlockDirective
        
        /// The size of this column.
        ///
        /// Specify a value greater than `1` to make this column span multiple columns
        /// in the parent ``Row``.
        @DirectiveArgumentWrapped
        public private(set) var size: Int = 1
        
        /// The markup content in this column.
        @ChildMarkup(numberOfParagraphs: .zeroOrMore, supportsStructure: true)
        public private(set) var content: MarkupContainer
        
        static var keyPaths: [String : AnyKeyPath] = [
            "size"      : \Column._size,
            "content"   : \Column._content,
        ]
        
        override var children: [Semantic] {
            return [content]
        }
        
        var childMarkup: [Markup] {
            return content.elements
        }
        
        @available(*, deprecated,
            message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'."
        )
        init(originalMarkup: BlockDirective) {
            self.originalMarkup = originalMarkup
        }
    }
}

extension Row: RenderableDirectiveConvertible {
    func render(with contentCompiler: inout RenderContentCompiler) -> [RenderContent] {
        let renderedColumns = columns.map { column in
            return RenderBlockContent.Row.Column(
                size: column.size,
                content: column.content.elements.flatMap { markupElement in
                    return contentCompiler.visit(markupElement) as! [RenderBlockContent]
                }
            )
        }
        
        let renderedRow = RenderBlockContent.Row(
            numberOfColumns: numberOfColumns,
            columns: renderedColumns
        )
        
        return [RenderBlockContent.row(renderedRow)]
    }
}
