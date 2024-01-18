/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
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
    
    @available(*, deprecated, renamed: "presentationURLForReference(_:)", message: "Use 'presentationURLForReference(_:)' instead. This dep...")
    public func presentationURLForReference(_ reference: ResolvedTopicReference, requireRelativeURL: Bool) -> URL {
        return presentationURLForReference(reference)
    }
    
    /// Returns the URL for linking to the rendered page of a given reference.
    ///
    /// - Parameters:
    ///   - reference: The reference which the URL generator generates a URL for.
    /// - Returns: The generated URL.
    public func presentationURLForReference(_ reference: ResolvedTopicReference) -> URL {
        // Note: As internal URLs might have a divergence between the presentation URL and the resolved topic reference URL, changing this last line
        // would cause the navigator index to stop working as we need to use the same conversion to normalize the original topic reference.
        return urlGenerator.urlForReference(reference, lowercased: true)
    }
}
