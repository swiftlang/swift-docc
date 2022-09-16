/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Each path component can be a maximum of 255 characters on HFS+ and ext* file systems,
/// but we set the limit to 240 to leave a convenient buffer for adding
/// a collision suffix in the remainder up to 255.
fileprivate let pathComponentLengthLimit = 240

/// While theoretically path could be unlimited on some file systems, there is a POSIX
/// limit of 1024 characters. We set the length to 880 to leave a buffer for a temporary
/// directory path before hitting the 1024 characters limit.
fileprivate let pathLengthLimit = 880

public struct NodeURLGenerator {
    /// The URL to use as base for all URLs in the bundle.
    ///
    /// Leaves to the model to determine a base URL for the presentation, e.g.
    /// there might be a path prefix coming from Info.plist or elsewhere.
    /// Here are some examples:
    ///
    ///  - baseURL("/") ~> /tutorials/SwiftUI/TutorialName
    ///  - baseURL("/prefix") ~> /prefix/tutorials/SwiftUI/TutorialName
    ///  - baseURL("doc://org.swift.example-bundle") ~> doc://org.swift.example-bundle/Example/TutorialName
    ///  - baseURL("http://domain.com/prefix") ~> http://domain.com/prefix/tutorials/Example/TutorialName
    public var baseURL: URL
    
    public init(baseURL: URL? = nil) {
        self.baseURL = baseURL ?? URL(string: "/")!
    }
    
    // Path builder for documentation nodes
    public enum Path {
        public static let tutorialsFolderName = "tutorials"
        public static let documentationFolderName = "documentation"
        public static let dataFolderName = "data"
        public static let indexFolderName = "index"
        
        public static let tutorialsFolder = "/\(tutorialsFolderName)"
        public static let documentationFolder = "/\(documentationFolderName)"

        private static let rootURL = URL(fileURLWithPath: "/", isDirectory: true)
        private static let tutorialsFolderURL = URL(fileURLWithPath: tutorialsFolder, isDirectory: true)
        private static let documentationFolderURL = URL(fileURLWithPath: documentationFolder, isDirectory: true)

        case documentation(path: String)
        case documentationCuration(parentPath: String, articleName: String)
        case article(bundleName: String, articleName: String)
        case technology(technologyName: String)
        case tutorial(bundleName: String, tutorialName: String)
        
        /// A URL safe path under the given root path.
        public var stringValue: String {
            switch self {
            case .documentation(let path):
                // Format: "/documentation/MyKit/MyClass/myFunction(_:)"
                return Self.documentationFolderURL
                    .appendingPathComponent(
                        urlReadablePath(path.removingLeadingSlash),
                        isDirectory: false
                    )
                    .path
            case .documentationCuration(let parentPath, let name):
                // Format: "/documentation/MyKit/MyClass/MyCollection"
                return Self.rootURL
                    .appendingPathComponent(
                        urlReadablePath(parentPath.removingLeadingSlash),
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        urlReadablePath(name),
                        isDirectory: false
                    )
                    .path
            case .article(let bundleName, let articleName):
                // Format: "/documentation/MyBundle/MyArticle"
                return Self.documentationFolderURL
                    .appendingPathComponent(
                        urlReadablePath(bundleName),
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        urlReadablePath(articleName),
                        isDirectory: false
                    )
                    .path
            case .technology(let technologyName):
                // Format: "/tutorials/MyTechnology"
                return Self.tutorialsFolderURL
                    .appendingPathComponent(
                        urlReadablePath(technologyName),
                        isDirectory: false
                    )
                    .path
            case .tutorial(let bundleName, let tutorialName):
                // Format: "/tutorials/MyBundle/MyTutorial"
                return Self.tutorialsFolderURL
                    .appendingPathComponent(
                        urlReadablePath(bundleName),
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        urlReadablePath(tutorialName),
                        isDirectory: false
                    )
                    .path
            }
        }
    }
    
    /// Returns a string path appropriate for the given semantic node.
    public static func pathForSemantic(_ semantic: Semantic, source: URL, bundle: DocumentationBundle) -> String {
        let fileName = source.deletingPathExtension().lastPathComponent
        
        switch semantic {
        case is Technology:
            return Path.technology(technologyName: fileName).stringValue
        case is Tutorial, is TutorialArticle:
            return Path.tutorial(bundleName: bundle.displayName, tutorialName: fileName).stringValue
        case let article as Article:
            if article.metadata?.technologyRoot != nil {
                return Path.documentation(path: fileName).stringValue
            } else {
                return Path.article(bundleName: bundle.displayName, articleName: fileName).stringValue
            }
        default:
            return fileName
        }
    }
    
    /// Returns the reference's path in a format that is safe for writing to disk.
    public static func fileSafeReferencePath(
        _ reference: ResolvedTopicReference,
        lowercased: Bool = false
    ) -> String {
        guard !reference.path.removingLeadingSlash.isEmpty else {
            return ""
        }
        
        let safeURL = fileSafeURL(reference.url)
        let pathRemovingLeadingSlash = safeURL.path.removingLeadingSlash
        
        if lowercased {
            return pathRemovingLeadingSlash.lowercased()
        } else {
            return pathRemovingLeadingSlash
        }
    }
    
    /// Returns a URL appropriate for the given reference.
    public func urlForReference(_ reference: ResolvedTopicReference, lowercased: Bool = false) -> URL {
        let safePath = Self.fileSafeReferencePath(reference, lowercased: lowercased)
        return urlForReference(reference, fileSafePath: safePath)
    }
    
    /// Returns a URL appropriate for the given reference and file safe path.
    public func urlForReference(_ reference: ResolvedTopicReference, fileSafePath safePath: String) -> URL {
        if safePath.isEmpty {
            // Return the root path for the conversion: /documentation.json
            return baseURL.appendingPathComponent(
                NodeURLGenerator.Path.documentationFolderName,
                isDirectory: false
            )
        } else {
            let url = baseURL.appendingPathComponent(safePath, isDirectory: false)
            return url.withFragment(reference.url.fragment)
        }
    }
    
    /// Patch path components for writing to the file system.
    ///
    /// We replace path unsafe characters when generating DocC references.
    /// When writing files on disk, however, and or hosting those files in a web environment
    /// there might be more complex rules for "safe" paths beyond simply replacing a set of
    /// characters. For example a period is a safe character but when a file path component
    /// starts with a period that might be problematic when hosted on a generic web server.
    public static func fileSafeURL(_ url: URL) -> URL {
        // Prepend leading period with a "'" to avoid file names looking like hidden files on web servers
        var isURLModified = false
        let pathComponents = url.pathComponents
            .filter({ $0 != "/" })
            .map({ name -> String in
                var name = name
                // Prepend leading period with a "'" to avoid file names looking like hidden files on web servers
                if name.unicodeScalars.first == "." {
                    isURLModified = true
                    name = "'\(name)"
                }
                
                // Shorten path components that are too long.
                // Take the first 240 chars and append a checksum on the *complete* string.
                if name.count >= pathComponentLengthLimit {
                    isURLModified = true
                    name = String(name.prefix(pathComponentLengthLimit)).appendingHashedIdentifier(name)
                }
                
                return name
            })
        
        // Skip re-constructing the URL if no changes were made to the path
        var newPath = "/" + pathComponents.joined(separator: "/")
        
        // Verify the path's total length and trim it if necessary.
        if newPath.count >= pathLengthLimit {
            isURLModified = true
            newPath = String(newPath.prefix(pathLengthLimit))
                .appendingHashedIdentifier(newPath)
        }
        
        guard isURLModified else { return url }
        
        // The URL coming from DocC is valid so we force unwrap here.
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.path = newPath
        return components.url!
    }
    
    @available(*, deprecated, message: "Use the static version of 'NodeURLGenerator.fileSafeURL(_:)' instead")
    public func fileSafeURL(_ url: URL) -> URL {
        return Self.fileSafeURL(url)
    }
}
