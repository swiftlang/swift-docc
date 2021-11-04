/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An reference resolver that can be used to resolve references that couldn't be resolved locally.
///
/// Fallback reference resolvers are used by a ``DocumentationContext`` to resolve externally resolve references that
/// couldn't be resolved internally.
///
/// ## See Also
/// - ``DocumentationContext/fallbackReferenceResolvers``
/// - ``ExternalReferenceResolver``
public protocol FallbackReferenceResolver {
    /// Attempts to resolve an unresolved reference for a topic that couldn't be resolved locally.
    ///
    /// Your implementation returns a resolved reference if the topic exists in the external source of documentation, or information about why the reference failed to resolve if the topic doesn't exist in the external source.
    ///
    /// Your implementation will only be called once for a given unresolved reference. Failures are assumed to persist for the duration of the documentation build.
    ///
    /// - Parameters:
    ///   - reference: The unresolved reference.
    ///   - sourceLanguage: The source language of the reference, in case the reference exists in multiple languages.
    /// - Returns: The resolved reference for the topic, or information about why the resolver failed to resolve the reference.
    func resolve(_ reference: TopicReference, sourceLanguage: SourceLanguage) -> TopicReferenceResolutionResult
    
    /// Creates a new documentation node with the documentation content for the external reference, if the given reference was
    /// resolved by this resolver.
    ///
    /// - Parameter reference: The external reference that this resolver may have previously resolved.
    /// - Returns: A node with the documentation content for the referenced topic, or `nil` if the reference wasn't previously
    /// resolved by this resolver.
    ///
    /// ## See Also
    /// - ``ExternalReferenceResolver/resolve(_:sourceLanguage:)``
    func entityIfPreviouslyResolved(
        with reference: ResolvedTopicReference
    ) throws -> DocumentationNode?
    
    /// Returns the web URL for the external topic.
    ///
    /// Some links may add query parameters, for example, to link to a specific language variant of the topic.
    ///
    /// - Parameter reference: The external reference that this resolver may have previously resolved.
    /// - Returns: The web URL for the resolved external reference, of `nil` if the reference wasn't previously resolved by this
    /// resolver.
    ///
    /// ## See Also
    /// - ``ExternalReferenceResolver/urlForResolvedReference(_:)``
    func urlForResolvedReferenceIfPreviouslyResolved(
        _ reference: ResolvedTopicReference
    ) -> URL?
}
