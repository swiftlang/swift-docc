/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that resolves symbol identifiers for symbols in all non-local modules.
///
/// Use this protocol to integrate symbol documentation content from other sources. Your implementation needs to be able to:
///  * Resolve symbols by their precise identifier  and return the symbols reference and external entity.
///
/// If a symbol in a symbol graph file references a symbol in another module—for example, when the symbol conforms to a protocol from another module, when the
/// symbol inherits from a class in another module, or the symbol has arguments or return values that are types from other modules—then this resolver is used to
/// look up those symbols by their unique identifier. This allows references in symbol declarations to be turned into links for external symbols, just like in-bundle
/// symbol references.
///
/// Because symbol identifiers don't specify what bundle the symbol belongs to, a documentation context can only have one global external symbol resolver.
///
/// ## See Also
/// - ``DocumentationContext/globalExternalSymbolResolver``
public protocol GlobalExternalSymbolResolver {
    /// Resolved a symbol identifier and returns the symbol's reference and external content.
    ///
    /// The precise identifier is assumed to be valid and to exist because it either comes from a trusted source, like a symbol graph file.
    ///
    /// - Parameter preciseIdentifier: The precise identifier for an external symbol.
    /// - Returns: The external symbol's reference and content if found; otherwise `nil`.
    @_spi(ExternalLinks) // LinkResolver.ExternalEntity isn't stable API yet
    func symbolReferenceAndEntity(withPreciseIdentifier preciseIdentifier: String) -> (ResolvedTopicReference, LinkResolver.ExternalEntity)?
}
