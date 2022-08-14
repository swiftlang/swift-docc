/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/**
 A short justification as to whether a ``Choice`` is correct for a question.
 */
public final class Justification: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// The explanatory content for this justification.
    @ChildMarkup(numberOfParagraphs: .zeroOrMore)
    public private(set) var content: MarkupContainer
    
    /// The reaction to the reader selecting the containing ``Choice``. Defaults to nil.
    @DirectiveArgumentWrapped
    public private(set) var reaction: String? = nil
    
    static var keyPaths: [String : AnyKeyPath] = [
        "content"   : \Justification._content,
        "reaction"  : \Justification._reaction
    ]
    
    override var children: [Semantic] {
        return [content]
    }
    
    init(originalMarkup: BlockDirective, content: MarkupContainer, reaction: String?) {
        self.originalMarkup = originalMarkup
        super.init()
        
        self.content = content
        self.reaction = reaction
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitJustification(self)
    }
}
