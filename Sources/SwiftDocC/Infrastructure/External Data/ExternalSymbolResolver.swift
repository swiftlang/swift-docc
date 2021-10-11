/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that resolves references to symbols outside of the documentation bundle and creates documentation nodes with basic information about the resolved symbol.
///
/// Use this protocol to integrate symbol documentation content from other sources. Your implementation needs to be able to:
///  * Create documentation nodes for precise identifiers encountered in a symbol graph file.
///  * Resolve authored symbol references and return the precise identifier for the resolved symbol.
///  * Return an external URL for the references that it was able to resolve.
///
/// If a symbol in a symbol graph file references a type that's not in the local bundle — for a example, the symbol conforms to a protocol that's not defined in the local bundle, the
/// symbol inherits from a class that's not defined in the local bundle, or the symbol has arguments or return values that are types which are not defined in the local bundle —
/// then this external resolver can resolve those symbol references. This allows references in symbol declarations to be turned into links for external references, just like in-bundle
/// symbol references can be.
///
/// It's also possible to author a reference to an external symbol. When a documentation context encounters a symbol reference that's not found in the local bundle, it asks the external
/// resolver to resolve the precise identifier for the reference.
///
/// Because symbol reference don't have a bundle identifier, a documentation context can only have one registered, external symbol resolver.
///
/// ## See Also
/// - ``DocumentationContext/externalSymbolResolver``
/// - ``LinkDestinationSummary``
/// - ``ExternalReferenceResolver``
public protocol ExternalSymbolResolver {
    
    /// Creates a new documentation node with the documentation content for the external symbol based on its precise identifier.
    ///
    /// The precise identifier is assumed to be valid and to exist because it either comes from a trusted source, like a symbol graph file, or was
    /// returned by the external symbol resolver or an authored symbol reference.
    ///
    /// This node is not part of the local bundle and won't be part of the rendered output. Because of this, your implementation only needs to return a node with the subset of content
    /// that correspond to the non-optional properties of a ``LinkDestinationSummary``; the node's kind, title, abstract, relative path, reference URL, the language of the node,
    /// and the set of languages where the nodes is available.
    ///
    /// - Parameter preciseIdentifier: The precise identifier for an external symbol.
    /// - Returns: A documentation node with documentation content for the resolved symbol.
    /// - Throws: Whether no external symbol has this precise identifier.
    func symbolEntity(withPreciseIdentifier preciseIdentifier: String) throws -> DocumentationNode
    
    /// Returns the web URL for the external symbol.
    ///
    /// Some links may add query parameters, for example, to link to a specific language variant of the topic.
    ///
    /// - Parameter reference:The external symbol reference that this resolver previously resolved.
    /// - Returns: The web URL for the resolved external symbol.
    func urlForResolvedSymbol(reference: ResolvedTopicReference) -> URL?
    
    /// Attempts to find the precise identifier for an authored symbol reference.
    ///
    /// The symbol resolver assumes the precise identifier is valid and exists when creating a symbol node. Pass authored
    /// symbol references to this method to check if they exist before creating a documentation node for that symbol.
    ///
    /// - Parameter reference: An authored reference to an external symbol.
    /// - Returns: The precise identifier of the referenced symbol, or `nil` if the reference is not for a resolved external symbol.
    func preciseIdentifier(forExternalSymbolReference reference: TopicReference) -> String?
}
