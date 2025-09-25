/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A resolver that attempts to resolve local references to content that wasn't included in the catalog or symbol input.
///
/// The ``ConvertService`` builds documentation for a single page, which doesn't have to be a top-level page. If this page's content contains references to other local
/// symbols, pages, or assets that aren't included in the ``ConvertRequest``, this fallback resolver resolves those references to on-demand fill in the missing local content.
///
/// For example, when building documentation for `someFunction()` that's a member of `SomeClass` in `SomeModule`, the ``ConvertService`` can pass a
/// "partial" symbol graph file that only contains `someFunction()` and its relationships but not `SomeClass` or any other symbols. If `someFunction()` has a local
/// documentation link or symbol link to another symbol or page, DocC won't be able to find the page that the link refers to and will ask the fallback resolver to attempt to resolve it.
///
/// > Note: The ``ConvertService`` only renders the one page that it provided inputs for. Because of this, the content that this fallback resolver returns is considered
/// "external" content, even if it represents pages that would be "local" if the full project was built together.
protocol ConvertServiceFallbackResolver {
    
    /// The bundle identifier for the fallback resolver.
    ///
    /// The fallback resolver will only resolve links with this bundle identifier.
    var bundleID: DocumentationContext.Inputs.Identifier { get }
    
    // MARK: References
    
    /// Attempts to resolve an unresolved reference for a page that couldn't be resolved locally.
    ///
    /// - Parameter reference: The unresolved local reference.
    /// - Returns: The resolved reference, or information about why the resolver failed to resolve the reference.
    func resolve(_ reference: TopicReference) -> TopicReferenceResolutionResult
    
    /// Returns an external entity with the documentation content for a local resolved reference if the reference was previously resolved by this resolver.
    ///
    /// - Parameter reference: The local reference that this resolver may have previously resolved.
    /// - Returns: An entity with the documentation content for the referenced page or landmark, or `nil` if the reference wasn't previously resolved by this resolver.
    func entityIfPreviouslyResolved(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity?
    
    // MARK:  Assets
    
    /// Attempts to resolve an asset that couldn't be resolved locally.
    ///
    /// - Parameter assetName: The name of the local asset to resolve.
    /// - Returns: The local asset with the given name if found; otherwise `nil`.
    func resolve(assetNamed assetName: String) -> DataAsset?
}
