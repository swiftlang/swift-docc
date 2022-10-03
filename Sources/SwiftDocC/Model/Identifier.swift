/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A resolved or unresolved reference to a piece of documentation.
///
/// A reference can exist in one of three states:
///  - It has not yet been resolved.
///  - It has successfully resolved.
///  - It has failed to resolve.
///
/// References that have resolved, either successfully or not, are represented by ``TopicReferenceResolutionResult``.
///
/// ## Topics
/// ### Topic References
///
/// - ``UnresolvedTopicReference``
/// - ``ResolvedTopicReference``
/// - ``TopicReferenceResolutionResult``
/// - ``SourceLanguage``
public enum TopicReference: Hashable, CustomStringConvertible {
    /// A topic reference that hasn't been resolved to known documentation.
    case unresolved(UnresolvedTopicReference)
    
    /// A topic reference that has either been resolved to known documentation or failed to resolve to known documentation.
    case resolved(TopicReferenceResolutionResult)
    
    /// A topic reference that has successfully been resolved to known documentation.
    internal static func successfullyResolved(_ reference: ResolvedTopicReference) -> TopicReference {
        return .resolved(.success(reference))
    }
    
    public var description: String {
        switch self {
        case .unresolved(let unresolved):
            return unresolved.description
        case .resolved(let resolved):
            return resolved.description
        }
    }
}

/// A topic reference that has been resolved, either successfully or not.
public enum TopicReferenceResolutionResult: Hashable, CustomStringConvertible {
    /// A topic reference that has successfully been resolved to known documentation.
    case success(ResolvedTopicReference)
    /// A topic reference that has failed to resolve to known documentation and an error message with information about why the reference failed to resolve.
    case failure(UnresolvedTopicReference, errorMessage: String)
    
    public var description: String {
        switch self {
        case .success(let resolved):
            return resolved.description
        case .failure(let unresolved, _):
            return unresolved.description
        }
    }
}

/// A reference to a piece of documentation which has been verified to exist.
///
/// A `ResolvedTopicReference` refers to some piece of documentation, such as an article or symbol.
/// Once an `UnresolvedTopicReference` has been resolved to this type, it should be guaranteed
/// that the content backing the documentation is available
/// (i.e. there is a file on disk or data in memory ready to be
/// recalled at any time).
///
/// ## Implementation Details
///
/// `ResolvedTopicReference` is effectively a wrapper around Foundation's `URL` and,
/// because of this, it exposes an API very similar to `URL` and does not allow direct modification
/// of its properties. This immutability brings performance benefits and communicates with
/// user's of the API that doing something like adding a path component
/// is a potentially expensive operation, just as it is on `URL`.
///
/// > Important: This type has copy-on-write semantics and wraps an underlying class to store
/// > its data.
public struct ResolvedTopicReference: Hashable, Codable, Equatable, CustomStringConvertible {
    typealias ReferenceBundleIdentifier = String
    typealias ReferenceKey = String
    
    /// A synchronized reference cache to store resolved references.
    static var sharedPool = Synchronized([ReferenceBundleIdentifier: [ReferenceKey: ResolvedTopicReference]]())
    
    /// Clears cached references belonging to the bundle with the given identifier.
    /// - Parameter bundleIdentifier: The identifier of the bundle to which the method should clear belonging references.
    static func purgePool(for bundleIdentifier: String) {
        sharedPool.sync { $0.removeValue(forKey: bundleIdentifier) }
    }
    
    /// Enables reference caching for any identifiers created with the given bundle identifier.
    static func enableReferenceCaching(for bundleIdentifier: ReferenceBundleIdentifier) {
        sharedPool.sync { sharedPool in
            if !sharedPool.keys.contains(bundleIdentifier) {
                sharedPool[bundleIdentifier] = [:]
            }
        }
    }

    /// The URL scheme for `doc://` links.
    public static let urlScheme = "doc"
    
    /// Returns `true` if the passed `URL` has a "doc" URL scheme.
    public static func urlHasResolvedTopicScheme(_ url: URL?) -> Bool {
        return url?.scheme?.lowercased() == ResolvedTopicReference.urlScheme
    }
    
    /// The storage for the resolved topic reference's state.
    let _storage: Storage
    
    /// The identifier of the bundle that owns this documentation topic.
    public var bundleIdentifier: String {
        return _storage.bundleIdentifier
    }
    
    /// The absolute path from the bundle to this topic, delimited by `/`.
    public var path: String {
        return _storage.path
    }
    
    /// A URL fragment referring to a resource in the topic.
    public var fragment: String? {
        return _storage.fragment
    }
    
    /// The source language for which this topic is relevant.
    public var sourceLanguage: SourceLanguage {
        // Return Swift by default to maintain backwards-compatibility.
        return sourceLanguages.contains(.swift) ? .swift : sourceLanguages.first!
    }
    
    /// The source languages for which this topic is relevant.
    ///
    /// > Important: The source languages associated with the reference may not be the same as the available source languages of its
    /// corresponding ``DocumentationNode``. If you need to query the source languages associated with a documentation node, use
    /// ``DocumentationContext/sourceLanguages(for:)`` instead.
    public var sourceLanguages: Set<SourceLanguage> {
        return _storage.sourceLanguages
    }
    
    /// - Note: The `path` parameter is escaped to a path readable string.
    public init(bundleIdentifier: String, path: String, fragment: String? = nil, sourceLanguage: SourceLanguage) {
        self.init(bundleIdentifier: bundleIdentifier, path: path, fragment: fragment, sourceLanguages: [sourceLanguage])
    }
    
    public init(bundleIdentifier: String, path: String, fragment: String? = nil, sourceLanguages: Set<SourceLanguage>) {
        self.init(
            bundleIdentifier: bundleIdentifier,
            urlReadablePath: urlReadablePath(path),
            urlReadableFragment: fragment.map(urlReadableFragment(_:)),
            sourceLanguages: sourceLanguages
        )
    }
    
    private init(bundleIdentifier: String, urlReadablePath: String, urlReadableFragment: String? = nil, sourceLanguages: Set<SourceLanguage>) {
        precondition(!sourceLanguages.isEmpty, "ResolvedTopicReference.sourceLanguages cannot be empty")
        // Check for a cached instance of the reference
        let key = Self.cacheKey(
            urlReadablePath: urlReadablePath,
            urlReadableFragment: urlReadableFragment,
            sourceLanguages: sourceLanguages
        )
        let cached = Self.sharedPool.sync { $0[bundleIdentifier]?[key] }
        if let resolved = cached {
            self = resolved
            return
        }
        
        _storage = Storage(
            bundleIdentifier: bundleIdentifier,
            path: urlReadablePath,
            fragment: urlReadableFragment,
            sourceLanguages: sourceLanguages
        )

        // Cache the reference
        Self.sharedPool.sync { sharedPool in
            // If we have a shared pool for this bundle identifier, cache the reference
            sharedPool[bundleIdentifier]?[key] = self
        }
    }
    
    private static func cacheKey(
        urlReadablePath path: String,
        urlReadableFragment fragment: String?,
        sourceLanguages: Set<SourceLanguage>
    ) -> String {
        let sourceLanguagesString = sourceLanguages.map(\.id).sorted().joined(separator: "-")
        
        if let fragment = fragment {
            return "\(path):\(fragment):\(sourceLanguagesString)"
        } else {
            return "\(path):\(sourceLanguagesString)"
        }
    }
    
    /// The topic URL as you would write in a link.
    public var url: URL {
        return _storage.url
    }
    
    /// A list of the reference path components.
    var pathComponents: [String] {
        return _storage.pathComponents
    }
    
    /// A string representation of `url`.
    var absoluteString: String {
        return _storage.absoluteString
    }
    
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
        let newReference = ResolvedTopicReference(
            bundleIdentifier: bundleIdentifier,
            path: path,
            fragment: fragment.map(urlReadableFragment),
            sourceLanguages: sourceLanguages
        )
        
        return newReference
    }
    
    /// Creates a new topic reference by appending a path to this reference.
    ///
    /// Before appending the path, it is encoded in a human readable format that avoids percent escape encoding in the URL.
    ///
    /// - Parameter path: The path to append.
    /// - Returns: The resulting topic reference.
    public func appendingPath(_ path: String) -> ResolvedTopicReference {
        let newReference = ResolvedTopicReference(
            bundleIdentifier: bundleIdentifier,
            urlReadablePath: url.appendingPathComponent(urlReadablePath(path), isDirectory: false).path,
            sourceLanguages: sourceLanguages
        )
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
        let newReference = ResolvedTopicReference(
            bundleIdentifier: bundleIdentifier,
            urlReadablePath: newPath,
            urlReadableFragment: reference.fragment.map(urlReadableFragment),
            sourceLanguages: sourceLanguages
        )
        return newReference
    }
    
    /// Creates a new topic reference by removing the last path component from this topic reference.
    public func removingLastPathComponent() -> ResolvedTopicReference {
        let newPath = String(pathComponents.dropLast().joined(separator: "/").dropFirst())
        let newReference = ResolvedTopicReference(
            bundleIdentifier: bundleIdentifier,
            urlReadablePath: newPath,
            urlReadableFragment: fragment,
            sourceLanguages: sourceLanguages
        )
        return newReference
    }
    
    /// Returns a topic reference based on the current one that includes the given source languages.
    ///
    /// If the current topic reference already includes the given source languages, this returns
    /// the original topic reference.
    public func addingSourceLanguages(_ sourceLanguages: Set<SourceLanguage>) -> ResolvedTopicReference {
        let combinedSourceLanguages = self.sourceLanguages.union(sourceLanguages)
        
        guard combinedSourceLanguages != self.sourceLanguages else {
            return self
        }
        
        return ResolvedTopicReference(
            bundleIdentifier: bundleIdentifier,
            urlReadablePath: path,
            urlReadableFragment: fragment,
            sourceLanguages: combinedSourceLanguages
        )
    }
    
    /// Returns a topic reference based on the current one but with the given source languages.
    ///
    /// If the current topic reference's source languages equal the given source languages,
    /// this returns the original topic reference.
    public func withSourceLanguages(_ sourceLanguages: Set<SourceLanguage>) -> ResolvedTopicReference {
        guard sourceLanguages != self.sourceLanguages else {
            return self
        }
        
        return ResolvedTopicReference(
            bundleIdentifier: bundleIdentifier,
            urlReadablePath: path,
            urlReadableFragment: fragment,
            sourceLanguages: sourceLanguages
        )
    }
    
    /// The last path component of this topic reference.
    public var lastPathComponent: String {
        // There is always at least one component, so we can unwrap `last`.
        return url.lastPathComponent
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url.absoluteString, forKey: .url)
        
        let sourceLanguageIDVariants = DocumentationDataVariants<String>(
            values: Dictionary<DocumentationDataVariantsTrait, String>(
                uniqueKeysWithValues: sourceLanguages.map { language in
                    (DocumentationDataVariantsTrait(interfaceLanguage: language.id), language.id)
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
    
    // Note: The source language of a `ResolvedTopicReference` is not considered when
    // hashing and checking for equality. This is intentional as DocC uses a single
    // ResolvedTopicReference to refer to all source language variants of a topic.
    //
    // This allows clients to look up topic references without knowing ahead of time
    // which languages they are available in.
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_storage.identifierPathAndFragment)
    }
    
    public static func == (lhs: ResolvedTopicReference, rhs: ResolvedTopicReference) -> Bool {
        return lhs._storage.identifierPathAndFragment == rhs._storage.identifierPathAndFragment
    }
    
    /// Storage for a resolved topic reference's state.
    ///
    /// This is a reference type which allows ``ResolvedTopicReference`` to have copy-on-write behavior.
    class Storage {
        let bundleIdentifier: String
        let path: String
        let fragment: String?
        let sourceLanguages: Set<SourceLanguage>
        let identifierPathAndFragment: String
        
        let url: URL
        
        let pathComponents: [String]
        
        let absoluteString: String
        
        init(
            bundleIdentifier: String,
            path: String,
            fragment: String? = nil,
            sourceLanguages: Set<SourceLanguage>
        ) {
            self.bundleIdentifier = bundleIdentifier
            self.path = path
            self.fragment = fragment
            self.sourceLanguages = sourceLanguages
            self.identifierPathAndFragment = "\(bundleIdentifier)\(path)\(fragment ?? "")"
            
            var components = URLComponents()
            components.scheme = ResolvedTopicReference.urlScheme
            components.host = bundleIdentifier
            components.path = path
            components.fragment = fragment
            self.url = components.url!
            self.pathComponents = self.url.pathComponents
            self.absoluteString = self.url.absoluteString
        }
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
        var components = URLComponents(
            url: parent.url.appendingPathComponent(unresolvedChild.path, isDirectory: false),
            resolvingAgainstBaseURL: false
        )!
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
        var result = topicURL.components.string!
        // Replace that path and fragment parts of the description with the unescaped path and fragment values.
        if let rangeOfFragment = topicURL.components.rangeOfFragment, let fragment = topicURL.components.fragment {
            result.replaceSubrange(rangeOfFragment, with: fragment)
        }
        if let rangeOfPath = topicURL.components.rangeOfPath {
            result.replaceSubrange(rangeOfPath, with: topicURL.components.path)
        }
        return result
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
    return path.components(separatedBy: .urlPathNotAllowed).joined(separator: "-")
}

private extension CharacterSet {
    static let fragmentCharactersToRemove = CharacterSet.punctuationCharacters // Remove punctuation from fragments
        .union(CharacterSet(charactersIn: "`"))       // Also consider back-ticks as punctuation. They are used as quotes around symbols or other code.
        .subtracting(CharacterSet(charactersIn: "-")) // Don't remove hyphens. They are used as a whitespace replacement.
    static let whitespaceAndDashes = CharacterSet.whitespaces
        .union(CharacterSet(charactersIn: "-–—")) // hyphen, en dash, em dash
}

/// Creates a more readable version of a fragment by replacing characters that are not allowed in the fragment of a URL with hyphens.
///
/// If this step is not performed, the disallowed characters are instead percent escape encoded, which is less readable.
/// For example, a fragment like `"#hello world"` is converted to `"#hello-world"` instead of `"#hello%20world"`.
func urlReadableFragment(_ fragment: String) -> String {
    var fragment = fragment
        // Trim leading/trailing whitespace
        .trimmingCharacters(in: .whitespaces)
    
        // Replace continuous whitespace and dashes
        .components(separatedBy: .whitespaceAndDashes)
        .filter({ !$0.isEmpty })
        .joined(separator: "-")
    
    // Remove invalid characters
    fragment.unicodeScalars.removeAll(where: CharacterSet.fragmentCharactersToRemove.contains)
    
    return fragment
}
