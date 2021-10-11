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
 A general purpose comment directive. All contents inside are stripped from
 
 > Warning: Content inside a comment should be considered absolutely confidential to the author. Never emit comments in anything that an end-user can receive. As an example, comments should not be emitted in ``RenderNode`` JSON.
 */
public final class Comment: Semantic, DirectiveConvertible {
    public static let directiveName = "Comment"
    public let originalMarkup: BlockDirective
    
    /// The comment content.
    public let content: MarkupContainer
    
    override var children: [Semantic] {
        return [content]
    }
    
    init(originalMarkup: BlockDirective, content: MarkupContainer) {
        self.originalMarkup = originalMarkup
        self.content = content
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Comment.directiveName)
        self.init(originalMarkup: directive, content: MarkupContainer(directive.children))
    }
}
