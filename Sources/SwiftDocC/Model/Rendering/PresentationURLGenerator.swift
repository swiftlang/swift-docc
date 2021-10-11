/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A type that generates URLs that you use to link to rendered pages.
/// 
/// Compared to a ``NodeURLGenerator``, this type also supports resolving presentation URLs via external resolvers.
public struct PresentationURLGenerator {
    /// The documentation context the URL generator queries for external reference resolvers.
    var context: DocumentationContext
    /// The URL generator for in-bundle references.
    let urlGenerator: NodeURLGenerator
    
    /// Creates a new URL generator.
    ///
    /// - Parameters:
    ///   - context: The documentation context the URL generator will queries for external reference resolvers.
    ///   - baseURL: The base URL for in-bundle references.
    public init(context: DocumentationContext, baseURL: URL) {
        self.context = context
        self.urlGenerator = NodeURLGenerator(baseURL: baseURL)
    }
    
    /// Returns the URL for linking to the rendered page of a given reference.
    ///
    /// - Note: Some contexts, such as topic groups, require the URL to be relative. This breaks links to external content since the local
    ///         preview server only had data to serve for in bundle pages.
    ///
    /// - Parameters:
    ///   - reference: The reference which the URL generator generates a URL for.
    ///   - requireRelativeURL: If `true`, the returned URL will be relative. If `false` the returned URL may be either relative or absolute.
    /// - Returns: The generated URL.
    public func presentationURLForReference(_ reference: ResolvedTopicReference, requireRelativeURL: Bool = false) -> URL {
        if let url = context.externalReferenceResolvers[reference.bundleIdentifier].map({ $0.urlForResolvedReference(reference) }) ??
            context.fallbackReferenceResolvers[reference.bundleIdentifier].flatMap({ $0.urlForResolvedReferenceIfPreviouslyResolved(reference) })
        {
            // General external references may need to be made relative.
            // Internal references and external symbols and are already relative.
            return requireRelativeURL ? url.withoutHostAndPortAndScheme() : url
        }
        if context.externallyResolvedSymbols.contains(reference), let symbolURL = context.externalSymbolResolver?.urlForResolvedSymbol(reference: reference) {
            // External symbol resolver
            return symbolURL
        }
        // Internal reference
        // Note: As internal URLs might have a divergence between the presentation URL and the resolved topic reference URL, changing this last line
        // would cause the navigator index to stop working as we need to use the same conversion to normalize the original topic reference.
        return urlGenerator.urlForReference(reference, lowercased: true)
    }
}
