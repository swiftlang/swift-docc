/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown


/// A directive that specifies an additional URL for the page where the directive appears.
///
/// Use this directive to declare a URL where a piece of content was previously located.
/// For example, if you host the compiled documentation on a web server,
/// that server can read this data and set an HTTP "301 Moved Permanently" redirect from
/// the declared URL to the page's current URL and avoid breaking any existing links to the content.
public final class Redirect: Semantic, DirectiveConvertible {
    public static let directiveName = "Redirected"
    public let originalMarkup: BlockDirective
    
    /// The URL that redirects to the page associated with the directive.
    public let oldPath: URL
    
    enum Semantics {
        enum From: DirectiveArgument {
            typealias ArgumentValue = URL
            static let argumentName = "from"
        }
    }
    
    init(originalMarkup: BlockDirective, oldPath: URL) {
        self.originalMarkup = originalMarkup
        self.oldPath = oldPath
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Redirect.directiveName)
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<Redirect>(severityIfFound: .warning, allowedArguments: [Semantics.From.argumentName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)

        Semantic.Analyses.HasOnlyKnownDirectives<Redirect>(severityIfFound: .warning, allowedDirectives: []).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let requiredFromURL = Semantic.Analyses.HasArgument<Redirect, Semantics.From>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems)

        if directive.hasChildren {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(Redirect.self).UnexpectedContent", summary: "\(Redirect.directiveName.singleQuoted) directive has content but none is expected.")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
        }
        
        guard let fromURL = requiredFromURL else {
            return nil
        }
        
        self.init(originalMarkup: directive, oldPath: fromURL)
    }
}

