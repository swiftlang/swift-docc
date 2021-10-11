/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that controls how the documentation-extension file merges with or overrides the in-source documentation.
///
/// When the ``behavior-swift.property`` property is ``Behavior-swift.enum/append``, the content from the documentation-extension file is added after the content from
/// the in-source documentation for that symbol.
/// If a documentation-extension file doesn't have a `DocumentationExtension` directive, then it has the ``Behavior-swift.enum/append`` behavior.
///
/// When the ``behavior-swift.property`` property is ``Behavior-swift.enum/override``, the content from the documentation-extension file completely replaces the content
/// from the in-source documentation for that symbol
///
/// This directive is only valid within a ``Metadata`` directive:
/// ```
/// @Metadata {
///    @DocumentationExtension(mergeBehavior: override)
/// }
/// ```
public final class DocumentationExtension: Semantic, DirectiveConvertible {
    public static let directiveName = "DocumentationExtension"
    public let originalMarkup: BlockDirective
    /// The merge behavior for this documentation extension.
    public let behavior: Behavior
    
    /// The merge behavior in a documentation extension.
    public enum Behavior: String, CaseIterable, Codable, DirectiveArgumentValueConvertible {
        /// Append the documentation-extension content to the in-source content and process them together.
        case append = "append"
        
        /// Completely override any in-source content with the content from the documentation-extension.
        case override = "override"
        
        public init?(rawDirectiveArgumentValue: String) {
            self.init(rawValue: rawDirectiveArgumentValue)
        }
        
        /// A plain-text representation of the behavior.
        public var description: String {
            return self.rawValue
        }
    }

    /// Child semantics for a documentation extension.
    enum Semantics {
        /// A merge-behavior argument.
        enum Behavior: DirectiveArgument {
            /// The type of value for the merge-behavior argument.
            typealias ArgumentValue = DocumentationExtension.Behavior
            /// The argument name for the merge-behavior argument.
            static let argumentName = "mergeBehavior"
        }
    }
    
    /// Creates a new documentation extension.
    /// - Parameters:
    ///   - originalMarkup: The original markup for this documentation extension.
    ///   - behavior: The merge behavior of this documentation extension.
    init(originalMarkup: BlockDirective, behavior: Behavior) {
        self.originalMarkup = originalMarkup
        self.behavior = behavior
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == DocumentationExtension.directiveName)

        let arguments = Semantic.Analyses.HasOnlyKnownArguments<DocumentationExtension>(severityIfFound: .warning, allowedArguments: [Semantics.Behavior.argumentName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<DocumentationExtension>(severityIfFound: .warning, allowedDirectives: []).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)

        let requiredBehavior = Semantic.Analyses.HasArgument<DocumentationExtension, Semantics.Behavior>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems)
        
        if directive.hasChildren {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(DocumentationExtension.directiveName).UnexpectedContent", summary: "\(DocumentationExtension.directiveName.singleQuoted) directive has content but none is expected.")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
        }
        
        guard let behavior = requiredBehavior else {
            return nil
        }
        
        self.init(originalMarkup: directive, behavior: behavior)
    }
}
