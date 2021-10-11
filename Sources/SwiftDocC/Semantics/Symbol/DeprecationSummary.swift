/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive to add custom deprecation summary to an already deprecated symbol.
public final class DeprecationSummary: Semantic, DirectiveConvertible {
    public static let directiveName = "DeprecationSummary"
    
    public let originalMarkup: BlockDirective

    /// The contents of the summary.
    public let content: MarkupContainer
    
    override var children: [Semantic] {
        return [content]
    }
    
    /// Creates a new deprecation summary from the content of the given directive.
    /// - Parameters:
    ///   - originalMarkup: The source markup as a directive.
    ///   - content: The markup content for the summary.
    init(originalMarkup: BlockDirective, content: MarkupContainer) {
        self.originalMarkup = originalMarkup
        self.content = content
        super.init()
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == DeprecationSummary.directiveName)
        self.init(originalMarkup: directive, content: MarkupContainer(directive.children))
    }
    
    public override func accept<V>(_ visitor: inout V) -> V.Result where V : SemanticVisitor {
        return visitor.visitDeprecationSummary(self)
    }
}
