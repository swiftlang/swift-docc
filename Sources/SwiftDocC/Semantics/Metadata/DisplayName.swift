/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that controls how the documentation-extension file overrides the symbol's display name.
///
/// The ``name`` property will override the symbol's default display name.
///
/// When the ``style-swift.property`` property is ``Style-swift.enum/conceptual``, the symbol's name is rendered as "conceptual"—same as article names or tutorial names —where applicable. The default style is ``Style-swift.enum/conceptual``.
///
/// When the ``style-swift.property`` property is ``Style-swift.enum/symbol``, the symbol's name is rendered as "symbol"—same as article names or tutorial names —where applicable. The default style is ``Style-swift.enum/conceptual``.
///
/// This directive is only valid within a ``Metadata`` directive:
/// ```
/// @Metadata {
///    @DisplayName("Custom Symbol Name", style: conceptual)
/// }
/// ```
public final class DisplayName: Semantic, DirectiveConvertible {
    public static let directiveName = "DisplayName"
    public let originalMarkup: BlockDirective
    /// The custom display name for this symbol.
    public let name: String
    /// The style of the display name for this symbol.
    ///
    /// Defaults to ``Style-swift.enum/conceptual``.
    public let style: Style
    
    /// The style of the display name for this symbol.
    public enum Style: String, CaseIterable, Codable, DirectiveArgumentValueConvertible {
        ///
        case conceptual = "conceptual"
        
        /// Completely override any in-source content with the content from the documentation-extension.
        case symbol = "symbol"
        
        public init?(rawDirectiveArgumentValue: String) {
            self.init(rawValue: rawDirectiveArgumentValue)
        }
        
        /// A plain-text representation of the behavior.
        public var description: String {
            return self.rawValue
        }
    }

    /// Child semantics for a display name.
    enum Semantics {
        /// An unlabeled name argument.
        enum Name: DirectiveArgument {
            /// The type of value for the name argument.
            typealias ArgumentValue = String
            /// The empty argument name for the unlabeled name argument.
            static let argumentName = ""
        }
        
        /// A style argument.
        enum Style: DirectiveArgument {
            /// The type of value for the style argument.
            typealias ArgumentValue = DisplayName.Style
            /// The argument name for the style argument.
            static let argumentName = "style"
        }
    }
    
    /// Creates a new documentation extension.
    /// - Parameters:
    ///   - originalMarkup: The original markup for this documentation extension.
    ///   - name: The custom display name for this symbol.
    ///   - style: The style of the display name for this symbol.
    init(originalMarkup: BlockDirective, name: String, style: Style) {
        self.originalMarkup = originalMarkup
        self.name = name
        self.style = style
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == DisplayName.directiveName)
        
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<DisplayName>(severityIfFound: .warning, allowedArguments: [Semantics.Name.argumentName, Semantics.Style.argumentName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<DisplayName>(severityIfFound: .warning, allowedDirectives: []).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let requiredName = Semantic.Analyses.HasArgument<DisplayName, Semantics.Name>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems)
        
        let optionalStyle = Semantic.Analyses.HasArgument<DisplayName, Semantics.Style>(severityIfNotFound: nil).analyze(directive, arguments: arguments, problems: &problems)
        
        if directive.hasChildren {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(DisplayName.directiveName).UnexpectedContent", summary: "\(DisplayName.directiveName.singleQuoted) directive has content but none is expected.")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
        }
        
        guard let name = requiredName else {
            return nil
        }
        
        self.init(originalMarkup: directive, name: name, style: optionalStyle ?? .conceptual)
    }
}
