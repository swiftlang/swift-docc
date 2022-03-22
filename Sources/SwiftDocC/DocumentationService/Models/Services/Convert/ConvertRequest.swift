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
    /// Information about the documentation catalog to convert.
    ///
    /// ## See Also
    /// - ``DocumentationCatalog/Info-swift.struct``
    public var catalogInfo: DocumentationCatalog.Info
    
    @available(*, deprecated, renamed: "catalogInfo")
    public var bundleInfo: DocumentationCatalog.Info {
        get {
            return catalogInfo
        }
        set {
            catalogInfo = newValue
        }
    }
    
    /// Feature flags to enable when performing this convert request.
    public var featureFlags: FeatureFlags
    
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
    /// information can be used as a lightweight index of the available documentation content in the catalog that's been converted.
    public var includeRenderReferenceStore: Bool?
    
    /// The file location of the catalog to convert, if any.
    public var catalogLocation: URL?
    
    @available(*, deprecated, renamed: "catalogLocation")
    public var bundleLocation: URL? {
        get {
            return catalogLocation
        }
        
        set {
            catalogLocation = newValue
        }
    }
    
    /// The display name of the documentation catalog to convert.
    ///
    /// ## See Also
    /// - ``DocumentationCatalog/displayName``
    @available(*, deprecated, message: "Use 'catalogInfo.displayName' instead.")
    public var displayName: String {
        get {
            return catalogInfo.displayName
        }
        set {
            catalogInfo.displayName = newValue
        }
    }
    
    /// The identifier of the documentation catalog to convert.
    ///
    /// ## See Also
    /// - ``DocumentationCatalog/identifier``
    @available(*, deprecated, message: "Use 'catalogInfo.identifier' instead.")
    public var identifier: String {
        get {
            return catalogInfo.identifier
        }
        set {
            catalogInfo.identifier = newValue
        }
    }
    
    /// The version of the documentation catalog to convert.
    ///
    /// ## See Also
    /// - ``DocumentationCatalog/version``
    @available(*, deprecated, message: "Use 'catalogInfo.version' instead.")
    public var version: String {
        get {
            return catalogInfo.version ?? "0.0.1"
        }
        set {
            catalogInfo.version = newValue
        }
    }
    
    /// The symbols graph data included in the documentation catalog to convert.
    ///
    /// ## See Also
    /// - ``DocumentationCatalog/symbolGraphURLs``
    public var symbolGraphs: [Data]
    
    /// The markup file data included in the documentation catalog to convert.
    ///
    /// ## See Also
    /// - ``DocumentationCatalog/markupURLs``
    public var markupFiles: [Data]
    
    /// The on-disk resources in the documentation catalog to convert.
    ///
    /// ## See Also
    /// - ``DocumentationCatalog/miscResourceURLs``
    public var miscResourceURLs: [URL]
    
    /// The default code listing language for the documentation catalog to convert.
    ///
    /// ## See Also
    /// - ``DocumentationCatalog/defaultCodeListingLanguage``
    @available(*, deprecated, message: "Use 'catalogInfo.defaultCodeListingLanguage' instead.")
    public var defaultCodeListingLanguage: String? {
        get {
            return catalogInfo.defaultCodeListingLanguage
        }
        set {
            catalogInfo.defaultCodeListingLanguage = newValue
        }
    }
    
    @available(*, deprecated, message: "Use 'init(catalogInfo:externalIDsToConvert:...)' instead.")
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
        self.catalogLocation = bundleLocation
        self.symbolGraphs = symbolGraphs
        self.knownDisambiguatedSymbolPathComponents = knownDisambiguatedSymbolPathComponents
        self.markupFiles = markupFiles
        self.miscResourceURLs = miscResourceURLs
        self.featureFlags = FeatureFlags()
        
        self.catalogInfo = DocumentationCatalog.Info(
            displayName: displayName,
            identifier: identifier,
            version: version,
            defaultCodeListingLanguage: defaultCodeListingLanguage
        )
    }
    
    /// Creates a request to convert in-memory documentation.
    /// - Parameters:
    ///   - catalogInfo: Information about the catalog to convert.
    ///   - documentPathsToConvert: The paths of the documentation nodes to convert.
    ///   - includeRenderReferenceStore: Whether the conversion's render reference store should be included in the
    ///   response.
    ///   - catalogLocation: The file location of the documentation catalog to convert, if any.
    ///   - symbolGraphs: The symbols graph data included in the documentation catalog to convert.
    ///   - knownDisambiguatedSymbolPathComponents: The mapping of external symbol identifiers to
    ///   known disambiguated symbol path components.
    ///   - markupFiles: The markup file data included in the documentation catalog to convert.
    ///   - miscResourceURLs: The on-disk resources in the documentation catalog to convert.
    public init(
        catalogInfo: DocumentationCatalog.Info,
        featureFlags: FeatureFlags = FeatureFlags(),
        externalIDsToConvert: [String]?,
        documentPathsToConvert: [String]? = nil,
        includeRenderReferenceStore: Bool? = nil,
        catalogLocation: URL? = nil,
        symbolGraphs: [Data],
        knownDisambiguatedSymbolPathComponents: [String: [String]]? = nil,
        markupFiles: [Data],
        miscResourceURLs: [URL]
    ) {
        self.externalIDsToConvert = externalIDsToConvert
        self.documentPathsToConvert = documentPathsToConvert
        self.includeRenderReferenceStore = includeRenderReferenceStore
        self.catalogLocation = catalogLocation
        self.symbolGraphs = symbolGraphs
        self.knownDisambiguatedSymbolPathComponents = knownDisambiguatedSymbolPathComponents
        self.markupFiles = markupFiles
        self.miscResourceURLs = miscResourceURLs
        self.catalogInfo = catalogInfo
        self.featureFlags = featureFlags
    }
    
    @available(*, deprecated, renamed: "init(catalogInfo:featureFlags:externalIDsToConvert:documentPathsToConvert:includeRenderReferenceStore:catalogLocation:symbolGraphs:knownDisambiguatedSymbolPathComponents:markupFiles:miscResourceURLs:)")
    public init(
        bundleInfo: DocumentationCatalog.Info,
        featureFlags: FeatureFlags = FeatureFlags(),
        externalIDsToConvert: [String]?,
        documentPathsToConvert: [String]? = nil,
        includeRenderReferenceStore: Bool? = nil,
        bundleLocation: URL? = nil,
        symbolGraphs: [Data],
        knownDisambiguatedSymbolPathComponents: [String: [String]]? = nil,
        markupFiles: [Data],
        miscResourceURLs: [URL]
    ) {
        self = .init(catalogInfo: bundleInfo, featureFlags: featureFlags, externalIDsToConvert: externalIDsToConvert, includeRenderReferenceStore: includeRenderReferenceStore, catalogLocation: bundleLocation, symbolGraphs: symbolGraphs, knownDisambiguatedSymbolPathComponents: knownDisambiguatedSymbolPathComponents, markupFiles: markupFiles, miscResourceURLs: miscResourceURLs)
    }
}
