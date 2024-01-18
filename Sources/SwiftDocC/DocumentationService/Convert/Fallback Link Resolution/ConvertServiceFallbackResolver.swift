/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A resolver that attempts to resolve local references that wasn't included in the catalog or symbol input.
///
/// The ``ConvertService`` builds documentation for a single page at a time. If this page's content contains references to other local symbols, pages, or
/// assets that aren't included in the original ``ConvertRequest``, this fallback resolver resolves those references.
///
/// The ``ConvertService`` only renders the one page that it provided inputs for. Because of this, the content that this fallback resolver returns is considered
/// "external" content, even if it represents pages that would be "local" if the full project was built together.
protocol ConvertServiceFallbackResolver {
    
    // MARK: References
    
    /// Attempts to resolve an unresolved reference for a page that couldn't be resolved locally.
    ///
    /// - Parameter reference: The unresolved local reference.
    /// - Returns: The resolved reference, or information about why the resolver failed to resolve the reference.
    func resolve(_ reference: TopicReference) -> TopicReferenceResolutionResult
    
    /// Returns a  Creates a new documentation node with the documentation content for the external reference, if the given reference was
    /// resolved by this resolver.
    ///
    /// - Parameter reference: The local reference that this resolver may have previously resolved.
    /// - Returns: A node with the documentation content for the referenced topic, or `nil` if the reference wasn't previously resolved by this resolver.
    func entityIfPreviouslyResolved(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity?
    
    // MARK:  Assets
    
    /// Attempts to resolve an asset that couldn't be resolved locally.
    ///
    /// - Parameter assetName: The name of the local asset to resolve.
    /// - Returns: The local asset with the given name if found; otherwise `nil`.
    func resolve(assetNamed assetName: String) -> DataAsset?
}
