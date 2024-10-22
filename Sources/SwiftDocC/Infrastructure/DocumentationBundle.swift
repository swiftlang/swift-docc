/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
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
    
    @available(*, deprecated, renamed: "id", message: "Use 'id' instead. This deprecated API will be removed after 6.2 is released")
    public var identifier: String {
        id.rawValue
    }
    
    /// The documentation bundle's stable and locally unique identifier.
    public var id: DocumentationBundle.Identifier {
        info.id
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
    
    /// Symbol Graph JSON files for the modules documented by this bundle.
    public let symbolGraphURLs: [URL]
    
    /// DocC Markup files of the bundle.
    public let markupURLs: [URL]
    
    /// Miscellaneous resources of the bundle.
    public let miscResourceURLs: [URL]

    /// A custom HTML file to use as the header for rendered output.
    public let customHeader: URL?

    /// A custom HTML file to use as the footer for rendered output.
    public let customFooter: URL?

    /// A custom JSON settings file used to theme renderer output.
    public let themeSettings: URL?
    
    /**
    A URL prefix to be appended to the relative presentation URL.
    
    This is used when a bundle's documentation is hosted in a known location.
    */
    public let baseURL: URL
    
    /// Creates a documentation bundle.
    ///
    /// - Parameters:
    ///   - info: Information about the bundle.
    ///   - baseURL: A URL prefix to be appended to the relative presentation URL.
    ///   - symbolGraphURLs: Symbol Graph JSON files for the modules documented by the bundle.
    ///   - markupURLs: DocC Markup files of the bundle.
    ///   - miscResourceURLs: Miscellaneous resources of the bundle.
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
        self.rootReference = ResolvedTopicReference(bundleIdentifier: info.id.rawValue, path: "/", sourceLanguage: .swift)
        self.documentationRootReference = ResolvedTopicReference(bundleIdentifier: info.id.rawValue, path: NodeURLGenerator.Path.documentationFolder, sourceLanguage: .swift)
        self.tutorialTableOfContentsContainer = ResolvedTopicReference(bundleIdentifier: info.id.rawValue, path: NodeURLGenerator.Path.tutorialsFolder, sourceLanguage: .swift)
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
