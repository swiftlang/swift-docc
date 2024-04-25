/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/**
 A semantic object formed from a directive after a series of semantic analysis checks.
 */
public protocol DirectiveConvertible {
    /**
     The name that must match to convert a `BlockDirective` to this type.
     */
    static var directiveName: String { get }
    
    /**
     The earliest release of Swift-DocC that supports this directive.
     */
    static var introducedVersion: String { get }
    
    /**
     The `BlockDirective` that was analyzed and converted to this ``Semantic`` object.
     */
    var originalMarkup: BlockDirective { get }
    
    /// Creates a semantic object from the parsed block directive markup and performs semantic analysis to verify that the semantic object is valid.
    /// - Parameters:
    ///   -  directive: The parsed block directive to create a semantic object from.
    ///   -  source: The location of the source file that contains the markup for the parsed block directive.
    ///   -  bundle: The documentation bundle that owns the directive.
    ///   -  context: The documentation context in which the bundle resides.
    ///   -  problems: An inout array of ``Problem`` to be collected for later diagnostic reporting.
    init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem])
    
    /// Returns a Boolean value indicating whether the `DirectiveConvertible` recognizes the given directive.
    ///
    /// - Parameter directive: The directive to check for conversion compatibility.
    static func canConvertDirective(_ directive: BlockDirective) -> Bool
}

public extension DirectiveConvertible {
    /// Returns a Boolean value indicating whether the `DirectiveConvertible` recognizes the given directive.
    ///
    /// - Parameter directive: The directive to check for conversion compatibility.
    static func canConvertDirective(_ directive: BlockDirective) -> Bool {
        directiveName == directive.name
    }
}

