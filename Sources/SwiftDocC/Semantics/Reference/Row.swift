/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

public final class Row: Semantic, AutomaticDirectiveConvertible, MarkupContaining {
    public let originalMarkup: BlockDirective
    
    @DirectiveArgumentWrapped(name: .custom("numberOfColumns"))
    public private(set) var _numberOfColumns: Int? = nil
    
    @ChildDirective(requirements: .oneOrMore)
    public private(set) var columns: [Column]
    
    static var keyPaths: [String : AnyKeyPath] = [
        "_numberOfColumns"   : \Row.__numberOfColumns,
        "columns"           : \Row._columns,
    ]
    
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
    public final class Column: Semantic, AutomaticDirectiveConvertible, MarkupContaining {
        public let originalMarkup: BlockDirective
        
        @DirectiveArgumentWrapped
        public private(set) var size: Int = 1
        
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
