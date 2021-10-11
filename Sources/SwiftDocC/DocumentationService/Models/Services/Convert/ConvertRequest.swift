/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit
import Foundation

/// A request to convert in-memory documentation.
public struct ConvertRequest: Codable {
    /// The external IDs of the symbols to convert.
    ///
    /// Use this property to indicate what symbol documentation nodes should be converted. When ``externalIDsToConvert``
    /// and ``documentPathsToConvert`` are both set, the documentation nodes that are in either arrays will be
    /// converted.
    ///
    /// If you want all the symbol render nodes to be returned as part of the conversion's response, set this property to `nil`.
    /// For Swift, the external ID of the symbol is its USR.
    public var externalIDsToConvert: [String]?
    
    /// The mapping of external symbol identifiers to known disambiguated symbol path components.
    ///
    /// Use this property to provide accurately disambiguated symbol path components for symbols
    /// in the given ``symbolGraphs`` that collide with other symbols that exist in the module but
    /// are not included in the given partial symbol graphs.
    public var knownDisambiguatedSymbolPathComponents: [String: [String]]?
    
    /// The paths of the documentation nodes to convert.
    ///
    /// Use this property to indicate what documentation nodes should be converted. When ``externalIDsToConvert``
    /// and ``documentPathsToConvert`` are both set, the documentation nodes that are in either arrays will be
    /// converted.
    ///
    /// If you want all the render nodes to be returned as part of the conversion's response, set this property to `nil`.
    public var documentPathsToConvert: [String]?
    
    /// Whether the conversion's render reference store should be included in the response.
    ///
    /// The ``RenderReferenceStore`` contains compiled information for documentation nodes registered in a context. This
    /// information can be used as a lightweight index of the available documentation content in the bundle that's been converted.
    public var includeRenderReferenceStore: Bool?
    
    /// The file location of the bundle to convert, if any.
    public var bundleLocation: URL?
    
    /// The display name of the documentation bundle to convert.
    ///
    /// ## See Also
    /// - ``DocumentationBundle/displayName``
    public var displayName: String
    
    /// The identifier of the documentation bundle to convert.
    ///
    /// ## See Also
    /// - ``DocumentationBundle/identifier``
    public var identifier: String
    
    /// The version of the documentation bundle to convert.
    ///
    /// ## See Also
    /// - ``DocumentationBundle/version``
    public var version: String
    
    /// The symbols graph data included in the documentation bundle to convert.
    ///
    /// ## See Also
    /// - ``DocumentationBundle/symbolGraphURLs``
    public var symbolGraphs: [Data]
    
    /// The markup file data included in the documentation bundle to convert.
    ///
    /// ## See Also
    /// - ``DocumentationBundle/markupURLs``
    public var markupFiles: [Data]
    
    /// The on-disk resources in the documentation bundle to convert.
    ///
    /// ## See Also
    /// - ``DocumentationBundle/miscResourceURLs``
    public var miscResourceURLs: [URL]
    
    /// The default code listing language for the documentation bundle to convert.
    ///
    /// ## See Also
    /// - ``DocumentationBundle/defaultCodeListingLanguage``
    public var defaultCodeListingLanguage: String?
    
    /// Creates a request to convert in-memory documentation.
    /// - Parameters:
    ///   - externalIDsToConvert: The external IDs of the symbols to convert. In Swift, the external ID of a symbol is its USR.
    ///   - documentPathsToConvert: The paths of the documentation nodes to convert.
    ///   - includeRenderReferenceStore: Whether the conversion's render reference store should be included in the
    ///   response.
    ///   - bundleLocation: The file location of the documentation bundle to convert, if any.
    ///   - displayName: The display name of the documentation bundle to convert.
    ///   - identifier: The identifier of the documentation bundle to convert.
    ///   - version: The version of the documentation bundle to convert.
    ///   - symbolGraphs: The symbols graph data included in the documentation bundle to convert.
    ///   - knownDisambiguatedSymbolPathComponents: The mapping of external symbol identifiers to
    ///   known disambiguated symbol path components.
    ///   - markupFiles: The markup file data included in the documentation bundle to convert.
    ///   - miscResourceURLs: The on-disk resources in the documentation bundle to convert.
    ///   - defaultCodeListingLanguage: The default code listing language for the documentation bundle to convert.
    public init(
        externalIDsToConvert: [String]?,
        documentPathsToConvert: [String]? = nil,
        includeRenderReferenceStore: Bool? = nil,
        bundleLocation: URL? = nil,
        displayName: String,
        identifier: String,
        version: String,
        symbolGraphs: [Data],
        knownDisambiguatedSymbolPathComponents: [String: [String]]? = nil,
        markupFiles: [Data],
        miscResourceURLs: [URL],
        defaultCodeListingLanguage: String?
    ) {
        self.externalIDsToConvert = externalIDsToConvert
        self.documentPathsToConvert = documentPathsToConvert
        self.includeRenderReferenceStore = includeRenderReferenceStore
        self.bundleLocation = bundleLocation
        self.displayName = displayName
        self.identifier = identifier
        self.version = version
        self.symbolGraphs = symbolGraphs
        self.knownDisambiguatedSymbolPathComponents = knownDisambiguatedSymbolPathComponents
        self.markupFiles = markupFiles
        self.miscResourceURLs = miscResourceURLs
        self.defaultCodeListingLanguage = defaultCodeListingLanguage
    }
}
