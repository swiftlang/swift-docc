/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

extension DocumentationContext {
    /// A collection of configuration to apply to a documentation context during initialization.
    public struct Configuration {
        // This type exists so that the context doesn't need to be modified in-between creation and registration of the data provider.
        // It's a small step towards making the context fully immutable.
        
        /// Creates a new default configuration.
        public init() {}
        
        // MARK: Convert Service configuration
       
        /// Configuration specific to the ``ConvertService``.
        var convertServiceConfiguration = ConvertServiceConfiguration()
        
        /// A collection of configuration specific to the ``ConvertService``.
        struct ConvertServiceConfiguration {
            /// The mapping of external symbol identifiers to known disambiguated symbol path components.
            ///
            /// In situations where the local documentation context doesn't contain all of the current module's
            /// symbols, for example when using a ``ConvertService`` with a partial symbol graph,
            /// the documentation context is otherwise unable to accurately detect a collision for a given symbol and correctly
            /// disambiguate its path components. This value can be used to inject already disambiguated symbol
            /// path components into the documentation context.
            var knownDisambiguatedSymbolPathComponents: [String: [String]]?
            
            /// Controls whether bundle registration should allow registering articles when no technology root is defined.
            ///
            /// Set this property to `true` to enable registering documentation for standalone articles,
            /// for example when using ``ConvertService``.
            var allowsRegisteringArticlesWithoutTechnologyRoot = false
            
            /// Controls whether documentation extension files are considered resolved even when they don't match a symbol.
            ///
            /// Set this property to `true` to always consider documentation extensions as "resolved", for example when using  ``ConvertService``.
            ///
            /// > Note:
            /// > Setting this property tor `true` means taking over the responsibility to match documentation extension files to symbols
            /// > diagnosing unmatched documentation extension files, and diagnostic symbols that match multiple documentation extension files.
            var considerDocumentationExtensionsThatDoNotMatchSymbolsAsResolved = false
            
            /// A resolver that attempts to resolve local references to content that wasn't included in the catalog or symbol input.
            ///
            /// > Warning:
            /// > Setting a fallback reference resolver makes accesses to the context non-thread-safe.
            /// > This is because the fallback resolver can run during both local link resolution and during rendering, which both happen concurrently for each page.
            /// > In practice this shouldn't matter because the convert service only builds documentation for one page.
            var fallbackResolver: ConvertServiceFallbackResolver?
            
            /// A closure that modifies each symbol graph before the context registers the symbol graph's information.
            var symbolGraphTransformer: ((inout SymbolGraph) -> ())? = nil
        }
        
        // MARK: External metadata
        
        /// External metadata injected into the context, for example via command line arguments.
        public var externalMetadata = ExternalMetadata()
        
        // MARK: External documentation
        
        /// Configuration related to external sources of documentation.
        public var externalDocumentationConfiguration = ExternalDocumentationConfiguration()
        
        /// A collection of configuration related to external sources of documentation.
        public struct ExternalDocumentationConfiguration {
            /// The lookup of external documentation sources by their bundle identifiers.
            public var sources: [BundleIdentifier: ExternalDocumentationSource] = [:]
            /// A type that resolves all symbols that are referenced in symbol graph files but can't be found in any of the locally available symbol graph files.
            public var globalSymbolResolver: GlobalExternalSymbolResolver?
            /// A list of URLs to documentation archives that the local documentation depends on.
            @_spi(ExternalLinks) // This needs to be public SPI so that the ConvertAction can set it.
            public var dependencyArchives: [URL] = []
        }
        
        // MARK: Experimental coverage
        
        /// Configuration related to the experimental documentation coverage feature.
        package var experimentalCoverageConfiguration = ExperimentalCoverageConfiguration()
        
        /// A collection of configuration related to the experimental documentation coverage feature.
        package struct ExperimentalCoverageConfiguration {
            /// Controls whether the context stores the set of references that are manually curated.
            package var shouldStoreManuallyCuratedReferences: Bool = false
        }
    }
}
