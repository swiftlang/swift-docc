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
    /// - ``DocumentationBundle/Info``
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
    
    /// The mapping of external symbol identifiers to lines of a documentation comment that overrides the value in the symbol graph.
    ///
    /// Use this property to override the `docComment` mixin of a symbol entry in a symbol graph. This allows
    /// the client to pass a more up-to-date value than is available in the symbol graph.
    public var overridingDocumentationComments: [String: [Line]]? = nil
    
    /// Whether the conversion's rendered documentation should include source file location metadata.
    public var emitSymbolSourceFileURIs: Bool
    
    /// The article and documentation extension file data included in the documentation bundle to convert.
    ///
    /// ## See Also
    /// - ``DocumentationBundle/markupURLs``
    public var markupFiles: [Data]
    
    
    /// The tutorial file data included in the documentation bundle to convert.
    public var tutorialFiles: [Data]
    
    /// The on-disk resources in the documentation bundle to convert.
    ///
    /// ## See Also
    /// - ``DocumentationBundle/miscResourceURLs``
    public var miscResourceURLs: [URL]
    
    /// The symbol identifiers that have an expanded documentation page available if they meet the associated access level requirement.
    ///
    /// For each of these symbols DocC sets the ``RenderMetadata/hasNoExpandedDocumentation`` property to `true`
    /// if the symbol fails to meet its provided requirements. This information in the page's ``RenderMetadata`` can be used to display
    /// a "View More" link that navigates the user to the full version of the documentation page.
    public var symbolIdentifiersWithExpandedDocumentation: [String: ExpandedDocumentationRequirements]?
    
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
        self.tutorialFiles = []
        self.miscResourceURLs = miscResourceURLs
        self.featureFlags = FeatureFlags()
        self.emitSymbolSourceFileURIs = true
        
        self.bundleInfo = DocumentationBundle.Info(
            displayName: displayName,
            identifier: identifier,
            version: version,
            defaultCodeListingLanguage: defaultCodeListingLanguage
        )
        
        self.symbolIdentifiersWithExpandedDocumentation = nil
    }
    
    /// Creates a request to convert in-memory documentation.
    /// - Parameters:
    ///   - bundleInfo: Information about the bundle to convert.
    ///   - documentPathsToConvert: The paths of the documentation nodes to convert.
    ///   - includeRenderReferenceStore: Whether the conversion's render reference store should be included in the
    ///   response.
    ///   - bundleLocation: The file location of the documentation bundle to convert, if any.
    ///   - symbolGraphs: The symbols graph data included in the documentation bundle to convert.
    ///   - overridingDocumentationComments: The mapping of external symbol identifiers to lines of a
    ///   documentation comment that overrides the value in the symbol graph.
    ///   - emitSymbolSourceFileURIs: Whether the conversion's rendered documentation should include source file location metadata.
    ///   - knownDisambiguatedSymbolPathComponents: The mapping of external symbol identifiers to
    ///   known disambiguated symbol path components.
    ///   - markupFiles: The article and documentation extension file data included in the documentation bundle to convert.
    ///   - tutorialFiles: The tutorial file data included in the documentation bundle to convert.
    ///   - miscResourceURLs: The on-disk resources in the documentation bundle to convert.
    ///   - symbolIdentifiersWithExpandedDocumentation: A dictionary of identifiers to requirements for these symbols to have expanded
    ///   documentation available.
    public init(
        bundleInfo: DocumentationBundle.Info,
        featureFlags: FeatureFlags = FeatureFlags(),
        externalIDsToConvert: [String]?,
        documentPathsToConvert: [String]? = nil,
        includeRenderReferenceStore: Bool? = nil,
        bundleLocation: URL? = nil,
        symbolGraphs: [Data],
        overridingDocumentationComments: [String: [Line]]? = nil,
        knownDisambiguatedSymbolPathComponents: [String: [String]]? = nil,
        emitSymbolSourceFileURIs: Bool = true,
        markupFiles: [Data],
        tutorialFiles: [Data] = [],
        miscResourceURLs: [URL],
        symbolIdentifiersWithExpandedDocumentation: [String: ExpandedDocumentationRequirements]? = nil
    ) {
        self.externalIDsToConvert = externalIDsToConvert
        self.documentPathsToConvert = documentPathsToConvert
        self.includeRenderReferenceStore = includeRenderReferenceStore
        self.bundleLocation = bundleLocation
        self.symbolGraphs = symbolGraphs
        self.overridingDocumentationComments = overridingDocumentationComments
        self.knownDisambiguatedSymbolPathComponents = knownDisambiguatedSymbolPathComponents
        
        // The default value for this is `true` to enable the inclusion of symbol declaration file paths
        // in the produced render json by default.
        // This default to true, because the render nodes created by `ConvertService` are intended for
        // local uses of documentation where this information could be relevant and we don't have the
        // privacy concerns that come with including this information in public releases of docs.
        self.emitSymbolSourceFileURIs = emitSymbolSourceFileURIs
        self.markupFiles = markupFiles
        self.tutorialFiles = tutorialFiles
        self.miscResourceURLs = miscResourceURLs
        self.bundleInfo = bundleInfo
        self.featureFlags = featureFlags
        self.symbolIdentifiersWithExpandedDocumentation = symbolIdentifiersWithExpandedDocumentation
    }
}

extension ConvertRequest {
    /// A line of text in source code.
    public struct Line: Codable {
        /// The string contents of a line.
        ///
        /// Do not include newline characters in this property.
        public var text: String
        
        /// The line's range in a document if available.
        public var sourceRange: SourceRange?
        
        /// Creates a line of text from source code.
        /// - Parameters:
        ///   - text: The strings contents of a line. Do not include newline characters.
        ///   - sourceRange: The line's range in a document if available.
        public init(
            text: String,
            sourceRange: SourceRange? = nil
        ) {
            self.text = text
            self.sourceRange = sourceRange
        }
    }
    
    /// Represents a selection in text.
    public struct SourceRange: Codable {
        /// The range's start position.
        public var start: Position
        
        /// The range's end position.
        public var end: Position
        
        /// Creates a new source range with the given start and end positions.
        public init(
            start: Position,
            end: Position
        ) {
            self.start = start
            self.end = end
        }
    }
    
    /// Represents a cursor position in text.
    public struct Position: Codable {
        /// The zero-based line number in a document.
        public var line: Int
        
        /// The zero-based byte offset into a line.
        public var character: Int
        
        /// Creates a new cursor position with the given line number and character offset.
        public init(line: Int, character: Int) {
            self.line = line
            self.character = character
        }
    }
    
    /// Represents any requirements needed for a symbol to have additional documentation available in the client.
    public struct ExpandedDocumentationRequirements: Codable {
        /// Access control levels required for the symbol to have additional documentation available.
        public let accessControlLevels: [String]
        /// Whether the client provides additional documentation for the symbol despite it being prefixed with an underscore.
        public let canBeUnderscored: Bool
        
        public init(accessControlLevels: [String], canBeUnderscored: Bool = false) {
            self.accessControlLevels = accessControlLevels
            self.canBeUnderscored = canBeUnderscored
        }
    }
}
