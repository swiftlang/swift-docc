/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/**
 A documentation bundle.

 A documentation bundle stores all of the authored content and metadata for a collection of topics and/or frameworks.

 No content data is immediately loaded when creating a `DocumentationBundle` except for its `Info.plist`. Its purpose is to provide paths on disk for documentation resources.

 ## Topics
 ### Bundle Metadata

 - ``displayName``
 - ``identifier``
 - ``version``
 - ``defaultCodeListingLanguage``
 - ``defaultAvailability``
 */
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
    
    /// Information about this documentation bundle that's unrelated to its documentation content.
    public let info: Info
    
    /**
     The bundle's human-readable display name.
     */
    public var displayName: String {
        info.displayName
    }
    
    /**
     The documentation bundle identifier.

     An identifier string that specifies the app type of the bundle. The string should be in reverse DNS format using only the Roman alphabet in upper and lower case (A–Z, a–z), the dot (“.”), and the hyphen (“-”).
     */
    public var identifier: String {
        info.identifier
    }

    /**
     The documentation bundle's version.

     It's not safe to make computations based on assumptions about the format of bundle's version. The version can be in any format.
     */
    public var version: String? {
        info.version
    }
    
    /// Code listings extracted from the documented modules' source, indexed by their identifier.
    public var attributedCodeListings: [String: AttributedCodeListing]
    
    /// Symbol Graph JSON files for the modules documented by this bundle.
    public let symbolGraphURLs: [URL]
    
    /// DocC Markup files of the bundle.
    public let markupURLs: [URL]
    
    /// Miscellaneous resources of the bundle.
    public let miscResourceURLs: [URL]

    /// Custom HTML file to use as the header for rendered output.
    public let customHeader: URL?

    /// Custom HTML file to use as the footer for rendered output.
    public let customFooter: URL?

    /// JSON settings file used to theme renderer output.
    public let themeSettings: URL?

    /// Default syntax highlighting to use for code samples in this bundle.
    @available(*, deprecated, message: "Use 'info.defaultCodeListingLanguage' instead.")
    public var defaultCodeListingLanguage: String? {
        return info.defaultCodeListingLanguage
    }
    
    @available(*, deprecated, message: "Use 'info.defaultAvailability' instead.")
    public var defaultAvailability: DefaultAvailability? {
        return info.defaultAvailability
    }
    
    /**
    A URL prefix to be appended to the relative presentation URL.
    
    This is used when a bundle's documentation is hosted in a known location.
    */
    public let baseURL: URL
    
    /**
     Creates a documentation bundle.
     
     - Parameters:
       - displayName: The display name of the documentation bundle.
       - identifier: A reverse-DNS style identifier indicating the documentation bundle.
       - version: The version of the documentation bundle.
       - attributedCodeListings: Code listings extracted from the documented modules' source, indexed by their identifier.
       - symbolGraphURLs: Symbol Graph JSON files for the modules documented by the bundle.
       - markupURLs: DocC Markup files of the bundle.
       - miscResourceURLs: Miscellaneous resources of the bundle.
       - defaultCodeListingLanguage: The default language for code blocks.
       - defaultAvailability: Default availability information for modules in this bundle.
     */
    @available(*, deprecated, message: "Use 'init(info:baseURL:...)' instead.")
    public init(displayName: String, identifier: String, version: Version, baseURL: URL = URL(string: "/")!, attributedCodeListings: [String: AttributedCodeListing] = [:], symbolGraphURLs: [URL], markupURLs: [URL], miscResourceURLs: [URL], customHeader: URL? = nil, customFooter: URL? = nil, defaultCodeListingLanguage: String? = nil, defaultAvailability: DefaultAvailability? = nil) {
        self.init(
            info: Info(
                displayName: displayName,
                identifier: identifier,
                version: version.description,
                defaultCodeListingLanguage: defaultCodeListingLanguage,
                defaultAvailability: defaultAvailability
            ),
            symbolGraphURLs: symbolGraphURLs,
            markupURLs: markupURLs,
            miscResourceURLs: miscResourceURLs,
            customHeader: customHeader,
            customFooter: customFooter
        )
    }
    
    /// Creates a documentation bundle.
    ///
    /// - Parameters:
    ///   - info: Information about the bundle.
    ///   - baseURL: A URL prefix to be appended to the relative presentation URL.
    ///   - attributedCodeListings: Code listings extracted from the documented modules' source, indexed by their identifier.
    ///   - symbolGraphURLs: Symbol Graph JSON files for the modules documented by the bundle.
    ///   - markupURLs: DocC Markup files of the bundle.
    ///   - miscResourceURLs: Miscellaneous resources of the bundle.
    ///   - customHeader: Custom HTML file to use as the header for rendered output.
    ///   - customFooter: Custom HTML file to use as the footer for rendered output.
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
        self.info = info
        self.baseURL = baseURL
        self.attributedCodeListings = attributedCodeListings
        self.symbolGraphURLs = symbolGraphURLs
        self.markupURLs = markupURLs
        self.miscResourceURLs = miscResourceURLs
        self.customHeader = customHeader
        self.customFooter = customFooter
        self.themeSettings = themeSettings
        self.rootReference = ResolvedTopicReference(bundleIdentifier: info.identifier, path: "/", sourceLanguage: .swift)
        self.documentationRootReference = ResolvedTopicReference(bundleIdentifier: info.identifier, path: NodeURLGenerator.Path.documentationFolder, sourceLanguage: .swift)
        self.tutorialsRootReference = ResolvedTopicReference(bundleIdentifier: info.identifier, path: NodeURLGenerator.Path.tutorialsFolder, sourceLanguage: .swift)
        self.technologyTutorialsRootReference = tutorialsRootReference.appendingPath(urlReadablePath(info.displayName))
        self.articlesDocumentationRootReference = documentationRootReference.appendingPath(urlReadablePath(info.displayName))
    }
    
    public private(set) var rootReference: ResolvedTopicReference

    /// Default path to resolve symbol links.
    public private(set) var documentationRootReference: ResolvedTopicReference

    /// Default path to resolve technology links.
    public var tutorialsRootReference: ResolvedTopicReference

    /// Default path to resolve tutorials.
    public var technologyTutorialsRootReference: ResolvedTopicReference
    
    /// Default path to resolve articles.
    public var articlesDocumentationRootReference: ResolvedTopicReference
}
