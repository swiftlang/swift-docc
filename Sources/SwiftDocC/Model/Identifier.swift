/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/**
 A resolved or unresolved reference to a piece of documentation.

 ## Topics
 ### Topic References

  - ``ResolvedTopicReference``
  - ``UnresolvedTopicReference``
  - ``SourceLanguage``
 */
public enum TopicReference: Hashable, CustomStringConvertible {
    /// A topic reference that hasn't been resolved to known documentation.
    case unresolved(UnresolvedTopicReference)
    
    /// A topic reference that has been resolved to known documentation.
    case resolved(ResolvedTopicReference)
    
    public var description: String {
        switch self {
        case .unresolved(let unresolved):
            return unresolved.description
        case .resolved(let resolved):
            return resolved.description
        }
    }
}

/**
 A reference to a piece of documentation which has been verified to exist.
 
 A `ResolvedTopicReference` refers to some piece of documentation, such as an article or symbol. Once an `UnresolvedTopicReference` has been resolved to this type, it should be guaranteed that the content backing the documentation is available (i.e. there is a file on disk or data in memory ready to be recalled at any time).
 */
public struct ResolvedTopicReference: Hashable, Codable, Equatable, CustomStringConvertible {
    typealias ReferenceBundleIdentifier = String
    typealias ReferenceKey = String
    
    /// A synchronized reference cache to store resolved references.
    static var sharedPool = Synchronized([ReferenceBundleIdentifier: [ReferenceKey: ResolvedTopicReference]]())
    
    /// Adds a reference to the reference pool.
    /// - Note: This method is synchronized over ``sharedPool``.
    static func addToPool(_ reference: ResolvedTopicReference) {
        sharedPool.sync {
            $0[reference.bundleIdentifier, default: [:]][reference.cacheKey] = reference
        }
    }
    /// Clears cached references belonging to the bundle with the given identifier.
    /// - Parameter bundleIdentifier: The identifier of the bundle to which the method should clear belonging references.
    static func purgePool(for bundleIdentifier: String) {
        sharedPool.sync { $0.removeValue(forKey: bundleIdentifier) }
    }

    /// The URL scheme for `doc://` links.
    public static let urlScheme = "doc"
    
    /// Returns `true` if the passed `URL` has a "doc" URL scheme.
    public static func urlHasResolvedTopicScheme(_ url: URL?) -> Bool {
        return url?.scheme?.lowercased() == ResolvedTopicReference.urlScheme
    }
    
    /// The identifier of the bundle that owns this documentation topic.
    public var bundleIdentifier: String {
        didSet { updateURL() }
    }
    
    /// The absolute path from the bundle to this topic, delimited by `/`.
    public var path: String {
        didSet { updateURL() }
    }
    
    /// A URL fragment referring to a resource in the topic.
    public var fragment: String? {
        didSet { updateURL() }
    }
    
    /// The source language for which this topic is relevant.
    public var sourceLanguage: SourceLanguage {
        // Return Swift by default to maintain backwards-compatibility.
        get { sourceLanguages.contains(.swift) ? .swift : sourceLanguages.first! }
        set { sourceLanguages.insert(newValue) }
    }
    
    /// The source languages for which this topic is relevant.
    public var sourceLanguages: Set<SourceLanguage>
    
    /// The reference cache key
    var cacheKey: String {
        return "\(path):\(fragment ?? ""):\(sourceLanguage.id)"
    }
    
    /// - Note: The `path` parameter is escaped to a path readable string.
    public init(bundleIdentifier: String, path: String, fragment: String? = nil, sourceLanguage: SourceLanguage) {
        // Check for a cached instance of the reference
        let key = "\(path):\(fragment ?? ""):\(sourceLanguage.id)"
        let cached = Self.sharedPool.sync { $0[bundleIdentifier]?[key] }
        if let resolved = cached {
            self = resolved
            return
        }
        
        // Create a new reference
        self.bundleIdentifier = bundleIdentifier
        self.path = urlReadablePath(path)
        self.fragment = fragment.map { urlReadableFragment($0) }
        self.sourceLanguages = [sourceLanguage]
        updateURL()

        // Cache the reference
        Self.sharedPool.sync { $0[bundleIdentifier, default: [:]][cacheKey] = self }
    }
    
    /// The topic URL as you would write in a link.
    private (set) public var url: URL! = nil
    
    private mutating func updateURL() {
        var components = URLComponents()
        components.scheme = ResolvedTopicReference.urlScheme
        components.host = bundleIdentifier
        components.path = path
        components.fragment = fragment
        url = components.url!
        pathComponents = url.pathComponents
        absoluteString = url.absoluteString
    }
    
    /// A list of the reference path components.
    /// > Note: This value is updated inside `updateURL()` to avoid
    /// accessing the property on `URL`.
    private(set) var pathComponents = [String]()
    
    /// A string representation of `url`.
    /// > Note: This value is updated inside `updateURL()` to avoid
    /// accessing the property on `URL`.
    private(set) var absoluteString = ""
    
    enum CodingKeys: CodingKey {
        case url, interfaceLanguage
    }
    
    public init(from decoder: Decoder) throws {
        enum TopicReferenceDeserializationError: Error {
            case unexpectedURLScheme(url: URL, scheme: String)
            case missingBundleIdentifier(url: URL)
        }
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let url = try container.decode(URL.self, forKey: .url)
        guard ResolvedTopicReference.urlHasResolvedTopicScheme(url) else {
            throw TopicReferenceDeserializationError.unexpectedURLScheme(url: url, scheme: url.scheme ?? "")
        }
        
        guard let bundleIdentifier = url.host else {
            throw TopicReferenceDeserializationError.missingBundleIdentifier(url: url)
        }

        let language = try container.decode(String.self, forKey: .interfaceLanguage)
        let interfaceLanguage = SourceLanguage(id: language)

        decoder.registerReferences([url.absoluteString])
        
        self.init(bundleIdentifier: bundleIdentifier, path: url.path, fragment: url.fragment, sourceLanguage: interfaceLanguage)
    }
    
    /// Creates a new topic reference with the given fragment.
    ///
    /// Before adding the fragment to the reference, the fragment is encoded in a human readable format that avoids percent escape encoding in the URL.
    ///
    /// You use a fragment to reference an element within a page:
    /// ```
    /// doc://your.bundle.identifier/path/to/page#element-in-page
    ///                                           ╰──────┬──────╯
    ///                                               fragment
    /// ```
    /// On-page elements can then be linked to using a fragment need to conform to the ``Landmark`` protocol.
    ///
    /// - Parameter fragment: The new fragment.
    /// - Returns: The resulting topic reference.
    public func withFragment(_ fragment: String?) -> ResolvedTopicReference {
        let newReference = ResolvedTopicReference(bundleIdentifier: bundleIdentifier, path: path, fragment: fragment.map(urlReadableFragment), sourceLanguage: sourceLanguage)
        Self.addToPool(newReference)
        return newReference
    }
    
    /// Creates a new topic reference by appending a path to this reference.
    ///
    /// Before appending the path, it is encoded in a human readable format that avoids percent escape encoding in the URL.
    ///
    /// - Parameter path: The path to append.
    /// - Returns: The resulting topic reference.
    public func appendingPath(_ path: String) -> ResolvedTopicReference {
        let newReference = ResolvedTopicReference(bundleIdentifier: bundleIdentifier, path: url.appendingPathComponent(urlReadablePath(path), isDirectory: false).path, sourceLanguage: sourceLanguage)
        Self.addToPool(newReference)
        return newReference
    }
    
    /// Creates a new topic reference by appending the path of another topic reference to this reference.
    ///
    /// Before appending the path of the other reference, that path is encoded in a human readable format that avoids percent escape encoding in the URL.
    ///
    /// - Parameter reference: The other reference from which the path is appended to this reference.
    /// - Returns: The resulting topic reference.
    public func appendingPathOfReference(_ reference: UnresolvedTopicReference) -> ResolvedTopicReference {
        // Only append the path component if it's not empty (rdar://66580574).
        let referencePath = urlReadablePath(reference.path)
        guard !referencePath.isEmpty else {
            return self
        }
        let newPath = url.appendingPathComponent(referencePath, isDirectory: false).path
        let newReference = ResolvedTopicReference(bundleIdentifier: bundleIdentifier, path: newPath, fragment: reference.fragment, sourceLanguage: sourceLanguage)
        Self.addToPool(newReference)
        return newReference
    }
    
    /// Creates a new topic reference by removing the last path component from this topic reference.
    public func removingLastPathComponent() -> ResolvedTopicReference {
        let newPath = String(pathComponents.dropLast().joined(separator: "/").dropFirst())
        let newReference = ResolvedTopicReference(bundleIdentifier: bundleIdentifier, path: newPath, fragment: fragment, sourceLanguage: sourceLanguage)
        Self.addToPool(newReference)
        return newReference
    }
    
    /// The last path component of this topic reference.
    public var lastPathComponent: String {
        // There is always at least one component, so we can unwrap `last`.
        return url.lastPathComponent
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url.absoluteString, forKey: .url)
        
        let sourceLanguageIDVariants = SymbolDataVariants<String>(
            values: Dictionary<SymbolDataVariantsTrait, String>(
                uniqueKeysWithValues: sourceLanguages.map { language in
                    (SymbolDataVariantsTrait(interfaceLanguage: language.id), language.id)
                }
            )
        )
        
        try container.encodeVariantCollection(
            // Force-unwrapping because resolved topic references should have at least one source language.
            VariantCollection<String>(from: sourceLanguageIDVariants)!,
            forKey: .interfaceLanguage,
            encoder: encoder
        )
    }
    
    public var description: String {
        return url.absoluteString
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
        hasher.combine(path)
        hasher.combine(fragment)
        hasher.combine(sourceLanguage.id)
    }
}

typealias ResolvedTopicReferenceCacheKey = String

extension ResolvedTopicReference {
    /// Returns a unique cache ID for a pair of unresolved and parent references.
    static func cacheIdentifier(_ reference: UnresolvedTopicReference, fromSymbolLink: Bool, in parent: ResolvedTopicReference?) -> ResolvedTopicReferenceCacheKey {
        let isSymbolLink = fromSymbolLink ? ":symbol" : ""
        if let parent = parent {
            // Create a cache id in the parent context
            return "\(reference.topicURL.absoluteString):\(parent.bundleIdentifier):\(parent.path):\(parent.sourceLanguage.id)\(isSymbolLink)"
        } else {
            // A cache ID for an external reference
            assert(reference.topicURL.components.host != nil)
            return reference.topicURL.absoluteString.appending(isSymbolLink)
        }
    }
}

/// An unresolved reference to a documentation node.
///
/// You can create unresolved references from partial information if that information can be derived from the enclosing context when the
/// reference is resolved. For example:
///
///  - The bundle identifier can be inferred from the documentation bundle that owns the document from which the unresolved reference came.
///  - The URL scheme of topic references is always "doc".
///  - The symbol precise identifier suffix can be left out when there are no known overloads or name collisions for the symbol.
public struct UnresolvedTopicReference: Hashable, CustomStringConvertible {
    /// The URL as originally spelled.
    public let topicURL: ValidatedURL
    
    /// The bundle identifier, if one was provided in the host name component of the original URL.
    public var bundleIdentifier: String? {
        return topicURL.components.host
    }
    
    /// The path of the unresolved reference.
    public var path: String {
        return topicURL.components.path
    }
    
    /// The fragment of the unresolved reference, if the original URL contained a fragment component.
    public var fragment: String? {
        return topicURL.components.fragment
    }
    
    /// An optional title.
    public var title: String? = nil
    
    /// Creates a new unresolved reference from another unresolved reference with a resolved parent reference.
    /// - Parameters:
    ///   - parent: The resolved parent reference of the unresolved reference.
    ///   - unresolvedChild: The other unresolved reference.
    public init(parent: ResolvedTopicReference, unresolvedChild: UnresolvedTopicReference) {
        var components = URLComponents(url: parent.url.appendingPathComponent(unresolvedChild.path), resolvingAgainstBaseURL: false)!
        components.fragment = unresolvedChild.fragment
        self.init(topicURL: ValidatedURL(components: components))
    }
    
    /// Creates a new untitled, unresolved reference with the given validated URL.
    /// - Parameter topicURL: The URL of this unresolved reference.
    public init(topicURL: ValidatedURL) {
        self.topicURL = topicURL
    }
    
    /// Creates a new unresolved reference with the given validated URL and title.
    /// - Parameters:
    ///   - topicURL: The URL of this unresolved reference.
    ///   - title: The title of this unresolved reference.
    public init(topicURL: ValidatedURL, title: String) {
        self.topicURL = topicURL
        self.title = title
    }
    
    public var description: String {
        return topicURL.components.string!
    }
}

/**
 A reference to an auxiliary resource such as an image.
 */
public struct ResourceReference: Hashable {
    /**
     The documentation bundle identifier for the bundle in which this resource resides.
     */
    public let bundleIdentifier: String

    /**
     The path of the resource local to its bundle.
     */
    public let path: String

    /// Creates a new resource reference.
    /// - Parameters:
    ///   - bundleIdentifier: The documentation bundle identifier for the bundle in which this resource resides.
    ///   - path: The path of the resource local to its bundle.
    init(bundleIdentifier: String, path: String) {
        self.bundleIdentifier = bundleIdentifier
        self.path = path.removingPercentEncoding ?? path
    }

    /// The topic reference URL of this reference.
    var url: URL {
        var components = URLComponents()
        components.scheme = ResolvedTopicReference.urlScheme
        components.host = bundleIdentifier
        components.path = "/" + path
        return components.url!
    }
}

/// Creates a more readable version of a path by replacing characters that are not allowed in the path of a URL with hyphens.
///
/// If this step is not performed, the disallowed characters are instead percent escape encoded instead which is less readable.
/// For example, a path like `"hello world/example project"` is converted to `"hello-world/example-project"`
/// instead of `"hello%20world/example%20project"`.
func urlReadablePath(_ path: String) -> String {
    return path.components(separatedBy: CharacterSet.urlPathAllowed.inverted)
        .joined(separator: "-")
}

/// Creates a more readable version of a fragment by replacing characters that are not allowed in the fragment of a URL with hyphens.
///
/// If this step is not performed, the disallowed characters are instead percent escape encoded, which is less readable.
/// For example, a fragment like `"#hello world"` is converted to `"#hello-world"` instead of `"#hello%20world"`.
func urlReadableFragment(_ fragment: String) -> String {
    // Trim leading/trailing invalid characters
    var fragment = fragment
        .trimmingCharacters(in: CharacterSet.urlFragmentAllowed.inverted)
    
    // Replace continuous whitespace
    fragment = fragment.components(separatedBy: .whitespaces)
        .filter({ !$0.isEmpty })
        .joined(separator: "-")

    let invalidCharacterSet = CharacterSet.urlFragmentAllowed.inverted.union(CharacterSet(charactersIn: "'\"`").subtracting(.whitespaces))
    fragment = fragment.components(separatedBy: invalidCharacterSet)
        .joined()

    // Replace continuous dashes
    fragment = fragment.components(separatedBy: CharacterSet(charactersIn: "-"))
        .filter({ !$0.isEmpty })
        .joined(separator: "-")

    return fragment
}
