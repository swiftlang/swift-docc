/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown


/// A directive that configures an alternate language representation of a symbol.
///
/// An API that can be called from more than one source language has more than one language representation.
///
/// Whenever possible, prefer to define alternative language representations for a symbol by using in-source annotations
/// such as the `@objc` and `@_objcImplementation` attributes in Swift,
/// or the `NS_SWIFT_NAME` macro in Objective C.
///
/// If your source language doesn’t have a mechanism for specifying alternate representations or if your intended alternate representation isn't compatible with those attributes,
/// you can use the `@AlternateRepresentation` directive to specify another symbol that should be considered an alternate representation of the documented symbol.
///
/// ```md
/// @Metadata {
///     @AlternateRepresentation(MyApp/MyClass/property)
/// }
/// ```
/// If you prefer, you can wrap the symbol link in a set of double backticks (\`\`), or use any other supported syntax for linking to symbols.
/// For more information about linking to symbols, see <doc:linking-to-symbols-and-other-content>.
///
/// This provides a hint to the renderer as to the alternate language representations for the current symbol.
/// The renderer may use this hint to provide a link to these alternate symbols.
/// For example, Swift-DocC-Render shows a toggle between supported languages, where switching to a different language representation will redirect to the documentation for the configured alternate symbol.
///
/// ### Special considerations
///
/// Links containing a colon (`:`) must be wrapped in quotes:
/// ```md
/// @Metadata {
///     @AlternateRepresentation("doc://com.example/documentation/MyClass/property")
///     @AlternateRepresentation("MyClass/myFunc(_:_:)")
/// }
/// ```
///
/// The `@AlternateRepresentation` directive only specifies an alternate language representation in one direction.
/// To define a two-way relationship, add an `@AlternateRepresentation` directive, linking to this symbol, to the other symbol as well.
///
/// You can only configure custom alternate language representations for languages that the documented symbol doesn't already have a language representation for,
/// either from in-source annotations or from a previous `@AlternateRepresentation` directive.
public final class AlternateRepresentation: Semantic, AutomaticDirectiveConvertible {
    public static let introducedVersion = "6.1"
            
    // Directive parameter definition

    /// A link to another symbol that should be considered an alternate language representation of the current symbol.
    ///
    /// If you prefer, you can wrap the symbol link in a set of double backticks (\`\`).
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
