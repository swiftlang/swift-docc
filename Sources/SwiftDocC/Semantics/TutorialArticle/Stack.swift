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
public final class Stack: Semantic, DirectiveConvertible {
    public static let directiveName = "Stack"
    public let originalMarkup: BlockDirective
    
    /// The stack's children.
    ///
    /// A list of media items with attached descriptions.
    public let contentAndMedia: [ContentAndMedia]
    
    override var children: [Semantic] {
        return contentAndMedia
    }
    
    init(originalMarkup: BlockDirective, contentAndMedias: [ContentAndMedia]) {
        self.originalMarkup = originalMarkup
        self.contentAndMedia = contentAndMedias
    }
    
    static let childrenLimit = 3
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Stack.directiveName)
        
        _ = Semantic.Analyses.HasOnlyKnownArguments<Stack>(severityIfFound: .warning, allowedArguments: [])
            .analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<Stack>(severityIfFound: .warning, allowedDirectives: [ContentAndMedia.directiveName], allowsMarkup: false)
            .analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let (contentAndMedias, _) = Semantic.Analyses.HasAtLeastOne<Stack, ContentAndMedia>(severityIfNotFound: .warning)
            .analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        if contentAndMedias.count > Stack.childrenLimit {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.HasAtMost<\(Stack.self), \(ContentAndMedia.self)>(\(Stack.childrenLimit))", summary: "\(Stack.directiveName.singleQuoted) directive accepts at most \(Stack.childrenLimit) \(ContentAndMedia.directiveName.singleQuoted) child directives")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
        }
        
        self.init(originalMarkup: directive, contentAndMedias: contentAndMedias)
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitStack(self)
    }
}
