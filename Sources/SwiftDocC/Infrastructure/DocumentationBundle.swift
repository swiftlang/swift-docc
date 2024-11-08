/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A collection of the build inputs for a unit of documentation.
///
/// A unit of documentation may for example cover a framework, library, or tool.
/// Projects or packages may have multiple units of documentation to represent the different consumable products in that project or package.
///
/// ## Topics
///
/// ### Input files
///
/// - ``markupURLs``
/// - ``symbolGraphURLs``
/// - ``miscResourceURLs``
///
/// ### Render customization
///
/// - ``customHeader``
/// - ``customFooter``
/// - ``themeSettings``
///
/// ### Metadata
///
/// - ``info``
/// - ``displayName``
/// - ``identifier``
public struct DocumentationBundle {
    public enum PropertyListError: DescribedError {
        case invalidVersionString(String)
        case keyNotFound(String)
        
        public var errorDescription: String {
            switch self {
            case .invalidVersionString(let versionString):
                return "'\(versionString)' is not a valid version string"
            case .keyNotFound(let name):
                return "Expected key \(name.singleQuoted) not found"
            }
        }
    }
    
    /// Non-content information or metadata about this unit of documentation.
    public let info: Info
    
    /// A human-readable display name for this unit of documentation.
    public var displayName: String {
        info.displayName
    }
    
    /// A identifier for this unit of documentation
    ///
    /// The string is typically in reverse DNS format using only the Roman alphabet in upper and lower case (A–Z, a–z), the dot (“.”), and the hyphen (“-”).
    public var identifier: String {
        info.identifier
    }

    /**
     The documentation bundle's version.

     It's not safe to make computations based on assumptions about the format of bundle's version. The version can be in any format.
     */
    @available(*, deprecated, message: "This deprecated API will be removed after 6.2 is released")
    public var version: String? {
        info.version
    }
    
    /// Code listings extracted from the documented modules' source, indexed by their identifier.
    @available(*, deprecated, message: "This deprecated API will be removed after 6.1 is released")
    public var attributedCodeListings: [String: AttributedCodeListing] = [:]
    
    /// Symbol graph JSON input files for the module that's represented by this unit of documentation.
    ///
    /// Tutorial or article-only documentation won't have any symbol graph JSON files.
    ///
    /// ## See Also
    ///
    /// - ``DocumentationBundleFileTypes/isSymbolGraphFile(_:)``
    public let symbolGraphURLs: [URL]
    
    /// Documentation markup input files for this unit of documentation.
    ///
    /// Documentation markup files include both articles, documentation extension files, and tutorial files.
    ///
    /// ## See Also
    ///
    /// - ``DocumentationBundleFileTypes/isMarkupFile(_:)``
    public let markupURLs: [URL]
    
    /// Miscellaneous resources (for example images, videos, or downloadable assets) for this unit of documentation.
    public let miscResourceURLs: [URL]

    /// A custom HTML file to use as the header for rendered output.
    public let customHeader: URL?

    /// A custom HTML file to use as the footer for rendered output.
    public let customFooter: URL?

    /// A custom JSON settings file used to theme renderer output.
    public let themeSettings: URL?
    
    /// A URL prefix to be appended to the relative presentation URL.
    ///
    /// This is used when a built documentation is hosted in a known location.
    public let baseURL: URL
    
    /// Creates a new collection of build inputs for a unit of documentation.
    ///
    /// - Parameters:
    ///   - info: Non-content information or metadata about this unit of documentation.
    ///   - baseURL: A URL prefix to be appended to the relative presentation URL.
    ///   - symbolGraphURLs: Symbol graph JSON input files for the module that's represented by this unit of documentation.
    ///   - markupURLs: Documentation markup input files for this unit of documentation.
    ///   - miscResourceURLs: Miscellaneous resources (for example images, videos, or downloadable assets) for this unit of documentation.
    ///   - customHeader: A custom HTML file to use as the header for rendered output.
    ///   - customFooter: A custom HTML file to use as the footer for rendered output.
    ///   - themeSettings: A custom JSON settings file used to theme renderer output.
    public init(
        info: Info,
        baseURL: URL = URL(string: "/")!,
        symbolGraphURLs: [URL],
        markupURLs: [URL],
        miscResourceURLs: [URL],
        customHeader: URL? = nil,
        customFooter: URL? = nil,
        themeSettings: URL? = nil
    ) {
        self.info = info
        self.baseURL = baseURL
        self.symbolGraphURLs = symbolGraphURLs
        self.markupURLs = markupURLs
        self.miscResourceURLs = miscResourceURLs
        self.customHeader = customHeader
        self.customFooter = customFooter
        self.themeSettings = themeSettings
        self.rootReference = ResolvedTopicReference(bundleIdentifier: info.identifier, path: "/", sourceLanguage: .swift)
        self.documentationRootReference = ResolvedTopicReference(bundleIdentifier: info.identifier, path: NodeURLGenerator.Path.documentationFolder, sourceLanguage: .swift)
        self.tutorialTableOfContentsContainer = ResolvedTopicReference(bundleIdentifier: info.identifier, path: NodeURLGenerator.Path.tutorialsFolder, sourceLanguage: .swift)
        self.tutorialsContainerReference = tutorialTableOfContentsContainer.appendingPath(urlReadablePath(info.displayName))
        self.articlesDocumentationRootReference = documentationRootReference.appendingPath(urlReadablePath(info.displayName))
    }
    
    @available(*, deprecated, renamed: "init(info:baseURL:symbolGraphURLs:markupURLs:miscResourceURLs:customHeader:customFooter:themeSettings:)", message: "Use 'init(info:baseURL:symbolGraphURLs:markupURLs:miscResourceURLs:customHeader:customFooter:themeSettings:)' instead. This deprecated API will be removed after 6.1 is released")
    public init(
        info: Info,
        baseURL: URL = URL(string: "/")!,
        attributedCodeListings: [String: AttributedCodeListing] = [:],
        symbolGraphURLs: [URL],
        markupURLs: [URL],
        miscResourceURLs: [URL],
        customHeader: URL? = nil,
        customFooter: URL? = nil,
        themeSettings: URL? = nil
    ) {
        self.init(info: info, baseURL: baseURL, symbolGraphURLs: symbolGraphURLs, markupURLs: markupURLs, miscResourceURLs: miscResourceURLs, customHeader: customHeader, customFooter: customFooter, themeSettings: themeSettings)
        self.attributedCodeListings = attributedCodeListings
    }
    
    public private(set) var rootReference: ResolvedTopicReference

    /// Default path to resolve symbol links.
    public private(set) var documentationRootReference: ResolvedTopicReference

    @available(*, deprecated, renamed: "tutorialTableOfContentsContainer", message: "Use 'tutorialTableOfContentsContainer' instead. This deprecated API will be removed after 6.2 is released")
    public var tutorialsRootReference: ResolvedTopicReference {
        tutorialTableOfContentsContainer
    }

    /// Default path to resolve tutorial table-of-contents links.
    public var tutorialTableOfContentsContainer: ResolvedTopicReference

    @available(*, deprecated, renamed: "tutorialsContainerReference", message: "Use 'tutorialsContainerReference' instead. This deprecated API will be removed after 6.2 is released")
    public var technologyTutorialsRootReference: ResolvedTopicReference {
        tutorialsContainerReference
    }

    /// Default path to resolve tutorial links.
    public var tutorialsContainerReference: ResolvedTopicReference

    /// Default path to resolve articles.
    public var articlesDocumentationRootReference: ResolvedTopicReference
}
