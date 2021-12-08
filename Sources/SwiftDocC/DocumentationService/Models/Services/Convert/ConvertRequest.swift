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
    /// Information about the documentation bundle to convert.
    ///
    /// ## See Also
    /// - ``DocumentationBundle/Info-swift.struct``
    public var bundleInfo: DocumentationBundle.Info
    
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
    /// information can be used as a lightweight index of the available documentation content in the bundle that's been converted.
    public var includeRenderReferenceStore: Bool?
    
    /// The file location of the bundle to convert, if any.
    public var bundleLocation: URL?
    
    /// The display name of the documentation bundle to convert.
    ///
    /// ## See Also
    /// - ``DocumentationBundle/displayName``
    @available(*, deprecated, message: "Use 'bundleInfo.displayName' instead.")
    public var displayName: String {
        get {
            return bundleInfo.displayName
        }
        set {
            bundleInfo.displayName = newValue
        }
    }
    
    /// The identifier of the documentation bundle to convert.
    ///
    /// ## See Also
    /// - ``DocumentationBundle/identifier``
    @available(*, deprecated, message: "Use 'bundleInfo.identifier' instead.")
    public var identifier: String {
        get {
            return bundleInfo.identifier
        }
        set {
            bundleInfo.identifier = newValue
        }
    }
    
    /// The version of the documentation bundle to convert.
    ///
    /// ## See Also
    /// - ``DocumentationBundle/version``
    @available(*, deprecated, message: "Use 'bundleInfo.version' instead.")
    public var version: String {
        get {
            return bundleInfo.version ?? "0.0.1"
        }
        set {
            bundleInfo.version = newValue
        }
    }
    
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
    @available(*, deprecated, message: "Use 'bundleInfo.defaultCodeListingLanguage' instead.")
    public var defaultCodeListingLanguage: String? {
        get {
            return bundleInfo.defaultCodeListingLanguage
        }
        set {
            bundleInfo.defaultCodeListingLanguage = newValue
        }
    }
    
    @available(*, deprecated, message: "Use 'init(bundleInfo:externalIDsToConvert:...)' instead.")
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
        self.symbolGraphs = symbolGraphs
        self.knownDisambiguatedSymbolPathComponents = knownDisambiguatedSymbolPathComponents
        self.markupFiles = markupFiles
        self.miscResourceURLs = miscResourceURLs
        self.featureFlags = FeatureFlags()
        
        self.bundleInfo = DocumentationBundle.Info(
            displayName: displayName,
            identifier: identifier,
            version: version,
            defaultCodeListingLanguage: defaultCodeListingLanguage
        )
    }
    
    /// Creates a request to convert in-memory documentation.
    /// - Parameters:
    ///   - bundleInfo: Information about the bundle to convert.
    ///   - documentPathsToConvert: The paths of the documentation nodes to convert.
    ///   - includeRenderReferenceStore: Whether the conversion's render reference store should be included in the
    ///   response.
    ///   - bundleLocation: The file location of the documentation bundle to convert, if any.
    ///   - symbolGraphs: The symbols graph data included in the documentation bundle to convert.
    ///   - knownDisambiguatedSymbolPathComponents: The mapping of external symbol identifiers to
    ///   known disambiguated symbol path components.
    ///   - markupFiles: The markup file data included in the documentation bundle to convert.
    ///   - miscResourceURLs: The on-disk resources in the documentation bundle to convert.
    public init(
        bundleInfo: DocumentationBundle.Info,
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
        self.externalIDsToConvert = externalIDsToConvert
        self.documentPathsToConvert = documentPathsToConvert
        self.includeRenderReferenceStore = includeRenderReferenceStore
        self.bundleLocation = bundleLocation
        self.symbolGraphs = symbolGraphs
        self.knownDisambiguatedSymbolPathComponents = knownDisambiguatedSymbolPathComponents
        self.markupFiles = markupFiles
        self.miscResourceURLs = miscResourceURLs
        self.bundleInfo = bundleInfo
        self.featureFlags = featureFlags
    }
}
