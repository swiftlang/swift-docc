/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that resolves references to documentation from other sources.
///
/// Use this protocol to integrate documentation content from other sources. Your implementation needs to be able to:
///  * Resolve references for the bundle identifier for which it's registered.
///  * Create entities for the references it was able to resolve.
///
/// When the documentation context encounters a reference that can't be resolved locally, it checks whether an external documentation source is registered in
/// ``DocumentationContext/externalDocumentationSources`` for the bundle identifier of the unresolved reference. If there is, that source is asked to attempt to resolve the reference.
///
/// If the referenced documentation exists in the external source, the source returns a resolved reference to the context. Later, the context uses this resolved reference to ask the source
/// for the external entity with the documentation content for that reference. Because this content isn't part of the compiled bundle, it won't have its own page in the build output.
///
/// If the reference doesn't exist in the external source of documentation or if an error occurs while attempting to resolve the reference, the external source returns information about the error.
///
/// ## See Also
/// - ``DocumentationContext/externalDocumentationSources``
/// - ``GlobalExternalSymbolResolver``
/// - ``TopicReferenceResolutionResult``
public protocol ExternalDocumentationSource {
    
    /// Attempts to resolve an unresolved reference for an external topic.
    ///
    /// Your implementation returns a resolved reference if the topic exists in the external source of documentation, or information about why the reference failed to resolve if the topic doesn't exist in the external source.
    ///
    /// Your implementation will only be called once for a given unresolved reference. Failures are assumed to persist for the duration of the documentation build.
    ///
    /// - Parameter reference: The unresolved external reference.
    /// - Returns: The resolved reference for the topic, or information about why the resolver failed to resolve the reference.
    func resolve(_ reference: TopicReference) -> TopicReferenceResolutionResult
    
    /// Creates a new external entity with the documentation content for a previously resolved external reference.
    ///
    /// - Parameter reference: The external reference that this resolver previously resolved.
    /// - Returns: An external entity with the documentation content for the referenced topic.
    /// - Precondition: The `reference` was previously resolved by this resolver.
    @_spi(ExternalLinks) // LinkResolver.ExternalEntity isn't stable API yet
    func entity(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity
}
