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
    
    /**
     The bundle's human-readable display name.
     */
    public let displayName: String

    /**
     The documentation bundle identifier.

     An identifier string that specifies the app type of the bundle. The string should be in reverse DNS format using only the Roman alphabet in upper and lower case (A–Z, a–z), the dot (“.”), and the hyphen (“-”).
     */
    public let identifier: String

    /**
     The documentation bundle's version.

     The build version number should be a string comprised of three non-negative, period-separated integers with the first integer being greater than zero—for example, `3.1.2`. The string should only contain numeric (0-9) and period (.) characters. Leading zeros are truncated from each integer and will be ignored (that is, `1.02.3` is equivalent to `1.2.3`).

     The meaning of each element is as follows:

     - The first number represents the most recent major release and is limited to a maximum length of four digits.
     - The second number represents the most recent significant revision and is limited to a maximum length of two digits.
     - The third number represents the most recent minor bug fix and is limited to a maximum length of two digits.

     If the value of the third number is 0, you can omit it and the second period.
     */
    public let version: Version
    
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

    /// Default syntax highlighting to use for code samples in this bundle.
    public let defaultCodeListingLanguage: String?

    /// Default availability information for modules in this bundle.
    public let defaultAvailability: DefaultAvailability?
    
    /*
    A URL prefix to be appended to the relative presentation
    
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
    public init(displayName: String, identifier: String, version: Version, baseURL: URL = URL(string: "/")!, attributedCodeListings: [String: AttributedCodeListing] = [:], symbolGraphURLs: [URL], markupURLs: [URL], miscResourceURLs: [URL], customHeader: URL? = nil, customFooter: URL? = nil, defaultCodeListingLanguage: String? = nil, defaultAvailability: DefaultAvailability? = nil) {
        self.displayName = displayName
        self.identifier = identifier
        self.version = version
        self.baseURL = baseURL
        self.attributedCodeListings = attributedCodeListings
        self.symbolGraphURLs = symbolGraphURLs
        self.markupURLs = markupURLs
        self.miscResourceURLs = miscResourceURLs
        self.customHeader = customHeader
        self.customFooter = customFooter
        self.defaultCodeListingLanguage = defaultCodeListingLanguage
        self.defaultAvailability = defaultAvailability
        
        self.rootReference = ResolvedTopicReference(bundleIdentifier: identifier, path: "/", sourceLanguage: .swift)
        self.documentationRootReference = ResolvedTopicReference(bundleIdentifier: identifier, path: NodeURLGenerator.Path.documentationFolder, sourceLanguage: .swift)
        self.tutorialsRootReference = ResolvedTopicReference(bundleIdentifier: identifier, path: NodeURLGenerator.Path.tutorialsFolder, sourceLanguage: .swift)
        self.technologyTutorialsRootReference = tutorialsRootReference.appendingPath(urlReadablePath(displayName))
        self.articlesDocumentationRootReference = documentationRootReference.appendingPath(urlReadablePath(displayName))
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
