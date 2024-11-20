/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown


/// A directive that configures the alternate language representations of a symbol.
///
/// Defines an alternate language representation for the current symbol, such that both symbols are considered to be alternate representations of the same symbol,
/// and are equivalent, even if they are different symbols according to the compiler.
/// These two symbols should not have any source languages in common.
/// ```md
/// @Metadata {
///     @AlternateRepresentation(``MyApp/MyClass/property``)
/// }
/// ```
///
/// External links must be wrapped in quotes:
/// ```md
/// @Metadata {
///     @AlternateRepresentation("doc://com.example/documentation/MyClass/property")
/// }
/// ```
///
/// ### Discussion
/// In Swift-DocC Render, this shows a toggle between supported languages, where switching to the alternate representations will redirect to the documentation for the configured counterpart symbol.
///
/// However whenever possible, prefer to define alternative language representations for a symbol by using in-source annotations
/// such as the `@objc` and `@_objcImplementation` attributes in Swift,
/// or the `NS_SWIFT_NAME` macro in Objective C.
///
/// Only one link is expected per `@AlternateRepresentation` directive, and the link only works in one direction.
/// To define a two-way relationship, specify the `@AlternateRepresentation` directive for both alternate representations of the symbol.
///
/// > Tip:
/// > All link formats supported in markup content are supported within this directive.
///
/// If a language representation already existed for one of the languages the counterpart symbol is available in, the current symbol has precedence over the others.
/// Additionally, if multiple `@AlternateRepresentation` directives define a counterpart for the same source languages, the first directive has precedence over the others.
///
/// For example, if a symbol is already available in Swift and Objective-C, and a Swift counterpart is defined with `@AlternateRepresentation`, the current symbol takes precedence and will be picked as the Swift variant.
///
public final class AlternateRepresentation: Semantic, AutomaticDirectiveConvertible {
    public static let introducedVersion = "6.1"
            
    // Directive parameter definition

    /// The symbol which is an alternate representation of the current symbol.
    @DirectiveArgumentWrapped(
        name: .unnamed,
        parseArgument: { _, argumentValue in
            // Allow authoring of links with leading and trailing "``"s
            var argumentValue = argumentValue
            if argumentValue.hasPrefix("``"), argumentValue.hasSuffix("``") {
                argumentValue = String(argumentValue.dropFirst(2).dropLast(2))
            }
            guard let url = ValidatedURL(parsingAuthoredLink: argumentValue), !url.components.path.isEmpty else {
                return nil
            }
            return .unresolved(UnresolvedTopicReference(topicURL: url))
        }
    )
    public internal(set) var reference: TopicReference

    static var keyPaths: [String : AnyKeyPath] = [
        "reference" : \AlternateRepresentation._reference
    ]

    // Boiler-plate required by conformance to AutomaticDirectiveConvertible
    
    public var originalMarkup: Markdown.BlockDirective

    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible")
    init(originalMarkup: Markdown.BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
