/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

public final class Snippet: Semantic, DirectiveConvertible {
    public static let directiveName = "Snippet"

    enum Semantics {
        enum Path: DirectiveArgument {
            static let argumentName = "path"
        }
        enum Slice: DirectiveArgument {
            static let argumentName = "slice"
        }
    }

    public let originalMarkup: BlockDirective
    
    /// The path components of a symbol link that would be used to resolve a reference to a snippet,
    /// only occurring as a block directive argument.
    public let path: String
    
    /// An optional named range to limit the lines shown.
    public let slice: String?

    public init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        let arguments = Semantic.Analyses
            .HasOnlyKnownArguments<Snippet>(severityIfFound: .warning, allowedArguments: [Semantics.Path.argumentName, Semantics.Slice.argumentName])
            .analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)

        let requiredPath = Semantic.Analyses.HasArgument<Snippet, Semantics.Path>(severityIfNotFound: .warning)
            .analyze(directive, arguments: arguments, problems: &problems)
        
        let optionalSlice = Semantic.Analyses.HasArgument<Snippet, Semantics.Slice>(severityIfNotFound: nil)
            .analyze(directive, arguments: arguments, problems: &problems)

        if directive.childCount != 0 {
            let removeInnerContentReplacement: [Solution] = directive.children.range.map {
                return [Solution(summary: "Remove inner content", replacements: [
                Replacement(range: $0, replacement: "")])]

            } ?? []
            problems.append(Problem(diagnostic: Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.Snippet.NoInnerContentAllowed", summary: "Snippets cannot have inner content; elements inside this directive will be ignored"), possibleSolutions: removeInnerContentReplacement))
        }

        guard let path = requiredPath else {
            return nil
        }

        guard !path.isEmpty else {
            problems.append(Problem(diagnostic: Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.EmptySnippetLink", summary: "No path provided to snippet; use a symbol link path to a known snippet"), possibleSolutions: []))
            return nil
        }

        self.originalMarkup = directive
        self.path = path
        self.slice = optionalSlice
    }
}
