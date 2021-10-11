/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive to set this page as a documentation root-level node.
///
/// This directive is only valid within a top-level ``Metadata`` directive:
/// ```
/// @Metadata {
///    @TechnologyRoot
/// }
/// ```
public final class TechnologyRoot: Semantic, DirectiveConvertible {
    public static let directiveName = "TechnologyRoot"
    public let originalMarkup: BlockDirective
       
    /// Creates a technology-root directive.
    /// - Parameters:
    ///   - originalMarkup: The original markup for this technology root.
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == TechnologyRoot.directiveName)
        
        _ = Semantic.Analyses.HasOnlyKnownArguments<TechnologyRoot>(severityIfFound: .warning, allowedArguments: []).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<TechnologyRoot>(severityIfFound: .warning, allowedDirectives: []).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        if directive.hasChildren {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(TechnologyRoot.directiveName).UnexpectedContent", summary: "\(TechnologyRoot.directiveName.singleQuoted) directive has content but none is expected.")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
        }
        
        self.init(originalMarkup: directive)
    }
}

