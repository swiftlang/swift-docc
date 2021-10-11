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
 An informal Xcode requirement for completing an instructional ``Tutorial``.
 */
public final class XcodeRequirement: Semantic, DirectiveConvertible {
    public static let directiveName = "XcodeRequirement"
    public let originalMarkup: BlockDirective
    
    /// Human readable title. 
    public let title: String
    
    /// Domain where requirement applies.
    public let destination: URL
        
    init(originalMarkup: BlockDirective, title: String, destination: URL) {
        self.originalMarkup = originalMarkup
        self.title = title
        self.destination = destination
    }
    
    enum Semantics {
        enum Title: DirectiveArgument {
            typealias ArgumentValue = String
            static let argumentName = "title"
        }
        enum Destination: DirectiveArgument {
            typealias ArgumentValue = URL
            static let argumentName = "destination"
        }
    }

    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == XcodeRequirement.directiveName)
        
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<XcodeRequirement>(severityIfFound: .warning, allowedArguments: [Semantics.Title.argumentName, Semantics.Destination.argumentName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<XcodeRequirement>(severityIfFound: .warning, allowedDirectives: []).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let requiredTitle = Semantic.Analyses.HasArgument<XcodeRequirement, Semantics.Title>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems)
        
        let requiredDestination = Semantic.Analyses.HasArgument<XcodeRequirement, Semantics.Destination>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems)

        guard let title = requiredTitle,
            let destination = requiredDestination else {
                return nil
        }
        
        self.init(originalMarkup: directive, title: title, destination: destination)
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitXcodeRequirement(self)
    }
}
