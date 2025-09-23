/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import SymbolKit

extension OutOfProcessReferenceResolver {
    
    // MARK: Request & Response
    
    /// An outdated version of a request message to send to the external link resolver.
    ///
    /// This can either be a request to resolve a topic URL or to resolve a symbol based on its precise identifier.
    ///
    /// @DeprecationSummary {
    ///   This version of the communication protocol is no longer recommended. Update to ``RequestV2`` and ``ResponseV2`` instead.
    ///
    ///   The new version of the communication protocol both has a mechanism for expanding functionality in the future (through common ``Capabilities`` between DocC and the external resolver) and supports richer responses for both successful and and failed requests.
    /// }
    @available(*, deprecated, message: "This version of the communication protocol is no longer recommended. Update to `RequestV2` and `ResponseV2` instead.")
    public typealias Request = _DeprecatedRequestV1
    
    // Note this type isn't formally deprecated to avoid warnings in the ConvertService, which still _implicitly_ require this version of requests and responses.
    public enum _DeprecatedRequestV1: Codable, CustomStringConvertible {
        /// A request to resolve a topic URL
        case topic(URL)
        /// A request to resolve a symbol based on its precise identifier.
        case symbol(String)
        /// A request to resolve an asset.
        case asset(AssetReference)
        
        private enum CodingKeys: CodingKey {
            case topic
            case symbol
            case asset
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .topic(let url):
                try container.encode(url, forKey: .topic)
            case .symbol(let identifier):
                try container.encode(identifier, forKey: .symbol)
            case .asset(let assetReference):
                try container.encode(assetReference, forKey: .asset)
            }
        }
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch container.allKeys.first {
            case .topic?:
                self = .topic(try container.decode(URL.self, forKey: .topic))
            case .symbol?:
                self = .symbol(try container.decode(String.self, forKey: .symbol))
            case .asset?:
                self = .asset(try container.decode(AssetReference.self, forKey: .asset))
            case nil:
                throw OutOfProcessReferenceResolver.Error.unknownTypeOfRequest
            }
        }
        
        /// A plain text representation of the request message.
        public var description: String {
            switch self {
            case .topic(let url):
                return "topic: \(url.absoluteString.singleQuoted)"
            case .symbol(let identifier):
                return "symbol: \(identifier.singleQuoted)"
            case .asset(let asset):
                return "asset with name: \(asset.assetName), bundle identifier: \(asset.bundleID)"
            }
        }
    }

    /// An outdated version of a response message from the external link resolver.
    ///
    /// @DeprecationSummary {
    ///   This version of the communication protocol is no longer recommended. Update to ``RequestV2`` and ``ResponseV2`` instead.
    ///
    ///   The new version of the communication protocol both has a mechanism for expanding functionality in the future (through common ``Capabilities`` between DocC and the external resolver) and supports richer responses for both successful and and failed requests.
    /// }
    @available(*, deprecated, message: "This version of the communication protocol is no longer recommended. Update to `RequestV2` and `ResponseV2` instead.")
    public typealias Response = _DeprecatedResponseV1
    
    @available(*, deprecated, message: "This version of the communication protocol is no longer recommended. Update to `RequestV2` and `ResponseV2` instead.")
    public enum _DeprecatedResponseV1: Codable {
        /// A bundle identifier response.
        ///
        /// This message should only be sent once, after the external link resolver has launched.
        case bundleIdentifier(String)
        /// The error message of the problem that the external link resolver encountered while resolving the requested topic or symbol.
        case errorMessage(String)
        /// A response with the resolved information about the requested topic or symbol.
        case resolvedInformation(ResolvedInformation)
        /// A response with information about the resolved asset.
        case asset(DataAsset)
        
        enum CodingKeys: String, CodingKey {
            case bundleIdentifier
            case errorMessage
            case resolvedInformation
            case asset
        }
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch container.allKeys.first {
            case .bundleIdentifier?:
                self = .bundleIdentifier(try container.decode(String.self, forKey: .bundleIdentifier))
            case .errorMessage?:
                self = .errorMessage(try container.decode(String.self, forKey: .errorMessage))
            case .resolvedInformation?:
                self = .resolvedInformation(try container.decode(ResolvedInformation.self, forKey: .resolvedInformation))
            case .asset?:
                self = .asset(try container.decode(DataAsset.self, forKey: .asset))
            case nil:
                throw OutOfProcessReferenceResolver.Error.invalidResponseKindFromClient
            }
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .bundleIdentifier(let bundleIdentifier):
                try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
            case .errorMessage(let errorMessage):
                try container.encode(errorMessage, forKey: .errorMessage)
            case .resolvedInformation(let resolvedInformation):
                try container.encode(resolvedInformation, forKey: .resolvedInformation)
            case .asset(let assetReference):
                try container.encode(assetReference, forKey: .asset)
            }
        }
    }
    
    // MARK: Resolved Information
    
    /// A type used to transfer information about a resolved reference in the outdated and no longer recommended version of the external resolver communication protocol.
    @available(*, deprecated, message: "This type is only used in the outdated, and no longer recommended, version of the out-of-process external resolver communication protocol.")
    public struct ResolvedInformation: Codable {
        /// Information about the resolved kind.
        public let kind: DocumentationNode.Kind
        /// Information about the resolved URL.
        public let url: URL
        /// Information about the resolved title.
        public let title: String // DocumentationNode.Name
        /// Information about the resolved abstract.
        public let abstract: String // Markup
        /// Information about the resolved language.
        public let language: SourceLanguage
        /// Information about the languages where the resolved node is available.
        public let availableLanguages: Set<SourceLanguage>
        /// Information about the platforms and their versions where the resolved node is available, if any.
        public let platforms: [PlatformAvailability]?
        /// Information about the resolved declaration fragments, if any.
        public let declarationFragments: DeclarationFragments?
        
        // We use the real types here because they're Codable and don't have public member-wise initializers.
        
        /// Platform availability for a resolved symbol reference.
        public typealias PlatformAvailability = AvailabilityRenderItem
        
        /// The declaration fragments for a resolved symbol reference.
        public typealias DeclarationFragments = SymbolGraph.Symbol.DeclarationFragments
        
        /// The platform names, derived from the platform availability.
        public var platformNames: Set<String>? {
            return platforms.map { platforms in Set(platforms.compactMap { $0.name }) }
        }
        
        /// Images that are used to represent the summarized element.
        public var topicImages: [TopicImage]?
                
        /// References used in the content of the summarized element.
        public var references: [any RenderReference]?
        
        /// The variants of content (kind, url, title, abstract, language, declaration) for this resolver information.
        public var variants: [Variant]?
       
        /// A value that indicates whether this symbol is under development and likely to change.
        var isBeta: Bool {
            guard let platforms, !platforms.isEmpty else {
                return false
            }
            
            return platforms.allSatisfy { $0.isBeta == true }
        }
        
        /// Creates a new resolved information value with all its values.
        ///
        /// - Parameters:
        ///   - kind: The resolved kind.
        ///   - url: The resolved URL.
        ///   - title: The resolved title
        ///   - abstract: The resolved (plain text) abstract.
        ///   - language: The resolved language.
        ///   - availableLanguages: The languages where the resolved node is available.
        ///   - platforms: The platforms and their versions where the resolved node is available, if any.
        ///   - declarationFragments: The resolved declaration fragments, if any.
        ///   - topicImages: Images that are used to represent the summarized element.
        ///   - references: References used in the content of the summarized element.
        ///   - variants: The variants of content for this resolver information.
        public init(
            kind: DocumentationNode.Kind,
            url: URL,
            title: String,
            abstract: String,
            language: SourceLanguage,
            availableLanguages: Set<SourceLanguage>,
            platforms: [PlatformAvailability]? = nil,
            declarationFragments: DeclarationFragments? = nil,
            topicImages: [TopicImage]? = nil,
            references: [any RenderReference]? = nil,
            variants: [Variant]? = nil
        ) {
            self.kind = kind
            self.url = url
            self.title = title
            self.abstract = abstract
            self.language = language
            self.availableLanguages = availableLanguages
            self.platforms = platforms
            self.declarationFragments = declarationFragments
            self.topicImages = topicImages
            self.references = references
            self.variants = variants
        }
        
        /// A variant of content for the resolved information.
        ///
        /// - Note: All properties except for ``traits`` are optional. If a property is `nil` it means that the value is the same as the resolved information's value.
        public struct Variant: Codable {
            /// The traits of the variant.
            public let traits: [RenderNode.Variant.Trait]
            
            /// A wrapper for variant values that can either be specified, meaning the variant has a custom value, or not, meaning the variant has the same value as the resolved information.
            ///
            /// This alias is used to make the property declarations more explicit while at the same time offering the convenient syntax of optionals.
            public typealias VariantValue = Optional
            
            /// The kind of the variant or `nil` if the kind is the same as the resolved information.
            public let kind: VariantValue<DocumentationNode.Kind>
            /// The url of the variant or `nil` if the url is the same as the resolved information.
            public let url: VariantValue<URL>
            /// The title of the variant or `nil` if the title is the same as the resolved information.
            public let title: VariantValue<String>
            /// The abstract of the variant or `nil` if the abstract is the same as the resolved information.
            public let abstract: VariantValue<String>
            /// The language of the variant or `nil` if the language is the same as the resolved information.
            public let language: VariantValue<SourceLanguage>
            /// The declaration fragments of the variant or `nil` if the declaration is the same as the resolved information.
            ///
            /// If the resolver information has a declaration but the variant doesn't, this property will be `Optional.some(nil)`.
            public let declarationFragments: VariantValue<DeclarationFragments?>
            
            /// Creates a new resolved information variant with the values that are different from the resolved information values.
            ///
            /// - Parameters:
            ///   - traits: The traits of the variant.
            ///   - kind: The resolved kind.
            ///   - url: The resolved URL.
            ///   - title: The resolved title
            ///   - abstract: The resolved (plain text) abstract.
            ///   - language: The resolved language.
            ///   - declarationFragments: The resolved declaration fragments, if any.
            public init(
                traits: [RenderNode.Variant.Trait],
                kind: VariantValue<DocumentationNode.Kind> = nil,
                url: VariantValue<URL> = nil,
                title: VariantValue<String> = nil,
                abstract: VariantValue<String> = nil,
                language: VariantValue<SourceLanguage> = nil,
                declarationFragments: VariantValue<DeclarationFragments?> = nil
            ) {
                self.traits = traits
                self.kind = kind
                self.url = url
                self.title = title
                self.abstract = abstract
                self.language = language
                self.declarationFragments = declarationFragments
            }
        }
    }
}

@available(*, deprecated, message: "This type is only used in the outdates, and no longer recommended, version of the out-of-process external resolver communication protocol.")
extension OutOfProcessReferenceResolver.ResolvedInformation {
    enum CodingKeys: CodingKey {
        case kind
        case url
        case title
        case abstract
        case language
        case availableLanguages
        case platforms
        case declarationFragments
        case topicImages
        case references
        case variants
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        kind = try container.decode(DocumentationNode.Kind.self, forKey: .kind)
        url = try container.decode(URL.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        abstract = try container.decode(String.self, forKey: .abstract)
        language = try container.decode(SourceLanguage.self, forKey: .language)
        availableLanguages = try container.decode(Set<SourceLanguage>.self, forKey: .availableLanguages)
        platforms = try container.decodeIfPresent([OutOfProcessReferenceResolver.ResolvedInformation.PlatformAvailability].self, forKey: .platforms)
        declarationFragments = try container.decodeIfPresent(OutOfProcessReferenceResolver.ResolvedInformation.DeclarationFragments.self, forKey: .declarationFragments)
        topicImages = try container.decodeIfPresent([TopicImage].self, forKey: .topicImages)
        references = try container.decodeIfPresent([CodableRenderReference].self, forKey: .references).map { decodedReferences in
            decodedReferences.map(\.reference)
        }
        variants = try container.decodeIfPresent([OutOfProcessReferenceResolver.ResolvedInformation.Variant].self, forKey: .variants)
        
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.kind, forKey: .kind)
        try container.encode(self.url, forKey: .url)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.abstract, forKey: .abstract)
        try container.encode(self.language, forKey: .language)
        try container.encode(self.availableLanguages, forKey: .availableLanguages)
        try container.encodeIfPresent(self.platforms, forKey: .platforms)
        try container.encodeIfPresent(self.declarationFragments, forKey: .declarationFragments)
        try container.encodeIfPresent(self.topicImages, forKey: .topicImages)
        try container.encodeIfPresent(references?.map { CodableRenderReference($0) }, forKey: .references)
        try container.encodeIfPresent(self.variants, forKey: .variants)
    }
}
