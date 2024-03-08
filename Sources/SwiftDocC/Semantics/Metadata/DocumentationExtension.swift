/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// Defines whether the content in a documentation extension file amends or replaces in-source documentation.
///
/// By default, content from the documentation-extension file is added after the content from the in-source documentation for that symbol.
///
/// You get this default behavior in two cases:
/// - when the documentation-extension file doesn't have a `DocumentationExtension` directive
/// - when the `DocumentationExtension` directive explicitly specifies the ``Behavior/append`` behavior
///
/// The other merge behavior completely replaces the content from the in-source documentation for that symbol with the content from the documentation-extension file. To get this behavior, specify ``Behavior/override`` as the merge behavior.
///
/// ```
/// @Metadata {
///    @DocumentationExtension(mergeBehavior: override)
/// }
/// ```
///
/// The `DocumentationExtension` is only valid within a ``Metadata`` directive.
public final class DocumentationExtension: Semantic, AutomaticDirectiveConvertible {
    public static let introducedVersion = "5.5"
    public let originalMarkup: BlockDirective
    
    /// A value of `append` or `override`, denoting whether an extension file's content amends or replaces the in-source documentation.
    @DirectiveArgumentWrapped(name: .custom("mergeBehavior"))
    public var behavior: Behavior
    
    static var keyPaths: [String : AnyKeyPath] = [
        "behavior" : \DocumentationExtension._behavior,
    ]
    
    /// The merge behavior in a documentation extension.
    public enum Behavior: String, CaseIterable, DirectiveArgumentValueConvertible {
        /// Append the documentation-extension content to the in-source content and process them together.
        case append
        
        /// Completely override any in-source content with the content from the documentation-extension.
        case override
    }
    
    func validate(source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> Bool {
        if behavior == .append {
            let diagnostic = Diagnostic(
                source: source,
                severity: .warning,
                range: originalMarkup.range,
                identifier: "org.swift.docc.\(Self.directiveName).NoConfiguration",
                summary: "\(Self.directiveName.singleQuoted) doesn't change default configuration and has no effect"
            )
            
            let solutions = originalMarkup.range.map {
                [Solution(summary: "Remove this \(Self.directiveName.singleQuoted) directive.", replacements: [Replacement(range: $0, replacement: "")])]
            } ?? []
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: solutions))
        }
        
        return true
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
