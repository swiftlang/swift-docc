/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A semantic model for a view that arranges its children in a row.
public final class Stack: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// The stack's children.
    ///
    /// A list of media items with attached descriptions.
    @ChildDirective(requirements: .oneOrMore)
    public private(set) var contentAndMedia: [ContentAndMedia]
    
    static var keyPaths: [String : AnyKeyPath] = [
        "contentAndMedia" : \Stack._contentAndMedia,
    ]
    
    override var children: [Semantic] {
        return contentAndMedia
    }
    
    init(originalMarkup: BlockDirective, contentAndMedias: [ContentAndMedia]) {
        self.originalMarkup = originalMarkup
        super.init()
        self.contentAndMedia = contentAndMedias
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
    
    static let childrenLimit = 3
    
    func validate(source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> Bool {
        if contentAndMedia.count > Stack.childrenLimit {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: originalMarkup.range, identifier: "org.swift.docc.HasAtMost<\(Stack.self), \(ContentAndMedia.self)>(\(Stack.childrenLimit))", summary: "\(Stack.directiveName.singleQuoted) directive accepts at most \(Stack.childrenLimit) \(ContentAndMedia.directiveName.singleQuoted) child directives")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
        }
        
        return true
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitStack(self)
    }
}
