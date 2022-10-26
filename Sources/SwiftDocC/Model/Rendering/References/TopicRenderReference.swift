/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A reference to another page of documentation in the current context.
public struct TopicRenderReference: RenderReference, VariantContainer {
    /// The type of this reference.
    ///
    /// This value is always `.topic`.
    public var type: RenderReferenceType = .topic
    
    /// The identifier of the reference.
    public var identifier: RenderReferenceIdentifier
    
    /// The title of the destination page.
    public var title: String {
        get { getVariantDefaultValue(keyPath: \.titleVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.titleVariants) }
    }
    
    /// The variants of the title.
    public var titleVariants: VariantCollection<String>
    
    /// The topic url for the destination page.
    public var url: String
    
    /// The abstract of the destination page.
    public var abstract: [RenderInlineContent] {
        get { getVariantDefaultValue(keyPath: \.abstractVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.abstractVariants) }
    }
    
    public var abstractVariants: VariantCollection<[RenderInlineContent]> = .init(defaultValue: [])
    
    /// The kind of page that's referenced.
    public var kind: RenderNode.Kind
    /// Whether the reference is required in its parent context.
    public var required: Bool
    /// The additional "role" assigned to the symbol, if any
    ///
    /// This value is `nil` if the referenced page is not a symbol.
    public var role: String?
    
    /// The abbreviated declaration of the symbol to display in links
    ///
    /// This value is `nil` if the referenced page is not a symbol.
    public var fragments: [DeclarationRenderSection.Token]? {
        get { getVariantDefaultValue(keyPath: \.fragmentsVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.fragmentsVariants) }
    }
    
    public var fragmentsVariants: VariantCollection<[DeclarationRenderSection.Token]?> = .init(defaultValue: nil)
    
    /// The abbreviated declaration of the symbol to display in navigation
    ///
    /// This value is `nil` if the referenced page is not a symbol.
    public var navigatorTitle: [DeclarationRenderSection.Token]? {
        get { getVariantDefaultValue(keyPath: \.navigatorTitleVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.navigatorTitleVariants) }
    }
    
    public var navigatorTitleVariants: VariantCollection<[DeclarationRenderSection.Token]?> = .init(defaultValue: nil)
    
    /// Information about conditional conformance for the symbol
    ///
    /// This value is `nil` if the referenced page is not a symbol.
    public var conformance: ConformanceSection?
    /// The estimated time to complete the topic.
    public var estimatedTime: String?
    
    /// Number of default implementations for the symbol
    ///
    /// This value is `nil` if the referenced page is not a symbol.
    public var defaultImplementationCount: Int?
    
    /// A value that indicates whether this symbol is built for a beta platform
    ///
    /// This value is `false` if the referenced page is not a symbol.
    public var isBeta: Bool
    /// A value that indicates whether this symbol is deprecated
    ///
    /// This value is `false` if the referenced page is not a symbol.
    public var isDeprecated: Bool
    
    /// Information about which title to use in links to this page.
    ///
    /// For symbols that have multiple possible titles (for example property list keys and entitlements) the title style decides which title to use in links.
    public var titleStyle: TitleStyle?
    /// Raw name of a symbol, e.g. "com.apple.enableDataAccess"
    ///
    /// This value is `nil` if the referenced page is not a symbol.
    public var name: String?
    /// The human friendly symbol name
    ///
    /// This value is `nil` if the referenced page is not a symbol.
    public var ideTitle: String?
    
    /// An optional list of text-based tags.
    public var tags: [RenderNode.Tag]?
    
    /// Author provided images that should be used to represent this page.
    public var images: [TopicImage]
    
    /// Creates a new topic reference with all its initial values.
    ///
    /// - Parameters:
    ///   - identifier: The identifier of this reference.
    ///   - title: The title of the destination page.
    ///   - abstract: The abstract of the destination page.
    ///   - url: The topic url of the destination page.
    ///   - kind: The kind of page that's referenced.
    ///   - required: Whether the reference is required in its parent context.
    ///   - role: The additional "role" assigned to the symbol, if any.
    ///   - fragments: The abbreviated declaration of the symbol to display in links, or `nil` if the referenced page is not a symbol.
    ///   - navigatorTitle: The abbreviated declaration of the symbol to display in navigation, or `nil` if the referenced page is not a symbol.
    ///   - estimatedTime: The estimated time to complete the topic.
    ///   - conformance: Information about conditional conformance for the symbol, or `nil` if the referenced page is not a symbol.
    ///   - isBeta: Whether this symbol is built for a beta platform, or `false` if the referenced page is not a symbol.
    ///   - isDeprecated: Whether this symbol is deprecated, or `false` if the referenced page is not a symbol.
    ///   - defaultImplementationCount: Number of default implementations for this symbol, or `nil` if the referenced page is not a symbol.
    ///   - titleStyle: Information about which title to use in links to this page.
    ///   - name: Raw name of a symbol, e.g. "com.apple.enableDataAccess", or `nil` if the referenced page is not a symbol.
    ///   - ideTitle: The human friendly symbol name, or `nil` if the referenced page is not a symbol.
    ///   - tags: An optional list of string tags.
    public init(
        identifier: RenderReferenceIdentifier,
        title: String,
        abstract: [RenderInlineContent],
        url: String,
        kind: RenderNode.Kind,
        required: Bool = false,
        role: String? = nil,
        fragments: [DeclarationRenderSection.Token]? = nil,
        navigatorTitle: [DeclarationRenderSection.Token]? = nil,
        estimatedTime: String?,
        conformance: ConformanceSection? = nil,
        isBeta: Bool = false,
        isDeprecated: Bool = false,
        defaultImplementationCount: Int? = nil,
        titleStyle: TitleStyle? = nil,
        name: String? = nil,
        ideTitle: String? = nil,
        tags: [RenderNode.Tag]? = nil,
        images: [TopicImage] = []
    ) {
        self.init(
            identifier: identifier,
            titleVariants: .init(defaultValue: title),
            abstractVariants: .init(defaultValue: abstract),
            url: url,
            kind: kind,
            required: required,
            role: role,
            fragmentsVariants: .init(defaultValue: fragments),
            navigatorTitleVariants: .init(defaultValue: navigatorTitle),
            estimatedTime: estimatedTime,
            conformance: conformance,
            isBeta: isBeta,
            isDeprecated: isDeprecated,
            defaultImplementationCount: defaultImplementationCount,
            titleStyle: titleStyle,
            name: name,
            ideTitle: ideTitle,
            tags: tags,
            images: images
        )
    }
    
    /// Creates a new topic reference with all its initial values.
    ///
    /// - Parameters:
    ///   - identifier: The identifier of this reference.
    ///   - titleVariants: The variants for the title of the destination page.
    ///   - abstract: The abstract of the destination page.
    ///   - url: The topic url of the destination page.
    ///   - kind: The kind of page that's referenced.
    ///   - required: Whether the reference is required in its parent context.
    ///   - role: The additional "role" assigned to the symbol, if any.
    ///   - fragments: The abbreviated declaration of the symbol to display in links, or `nil` if the referenced page is not a symbol.
    ///   - navigatorTitle: The abbreviated declaration of the symbol to display in navigation, or `nil` if the referenced page is not a symbol.
    ///   - estimatedTime: The estimated time to complete the topic.
    ///   - conformance: Information about conditional conformance for the symbol, or `nil` if the referenced page is not a symbol.
    ///   - isBeta: Whether this symbol is built for a beta platform, or `false` if the referenced page is not a symbol.
    ///   - isDeprecated: Whether this symbol is deprecated, or `false` if the referenced page is not a symbol.
    ///   - defaultImplementationCount: Number of default implementations for this symbol, or `nil` if the referenced page is not a symbol.
    ///   - titleStyle: Information about which title to use in links to this page.
    ///   - name: Raw name of a symbol, e.g. "com.apple.enableDataAccess", or `nil` if the referenced page is not a symbol.
    ///   - ideTitle: The human friendly symbol name, or `nil` if the referenced page is not a symbol.
    ///   - tags: An optional list of string tags.
    public init(
        identifier: RenderReferenceIdentifier,
        titleVariants: VariantCollection<String>,
        abstractVariants: VariantCollection<[RenderInlineContent]>,
        url: String,
        kind: RenderNode.Kind,
        required: Bool = false,
        role: String? = nil,
        fragmentsVariants: VariantCollection<[DeclarationRenderSection.Token]?> = .init(defaultValue: nil),
        navigatorTitleVariants: VariantCollection<[DeclarationRenderSection.Token]?> = .init(defaultValue: nil),
        estimatedTime: String?,
        conformance: ConformanceSection? = nil,
        isBeta: Bool = false,
        isDeprecated: Bool = false,
        defaultImplementationCount: Int? = nil,
        titleStyle: TitleStyle? = nil,
        name: String? = nil,
        ideTitle: String? = nil,
        tags: [RenderNode.Tag]? = nil,
        images: [TopicImage] = []
    ) {
        self.identifier = identifier
        self.titleVariants = titleVariants
        self.abstractVariants = abstractVariants
        self.url = url
        self.kind = kind
        self.required = required
        self.role = role
        self.fragmentsVariants = fragmentsVariants
        self.navigatorTitleVariants = navigatorTitleVariants
        self.estimatedTime = estimatedTime
        self.conformance = conformance
        self.isBeta = isBeta
        self.isDeprecated = isDeprecated
        self.defaultImplementationCount = defaultImplementationCount
        self.titleStyle = titleStyle
        self.name = name
        self.ideTitle = ideTitle
        self.tags = tags
        self.images = images
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case identifier
        case title
        case url
        case abstract
        case kind
        case required
        case role
        case fragments
        case navigatorTitle
        case estimatedTime
        case conformance
        case beta
        case deprecated
        case defaultImplementations
        case titleStyle
        case name
        case ideTitle
        case tags
        case images
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(RenderReferenceType.self, forKey: .type)
        identifier = try values.decode(RenderReferenceIdentifier.self, forKey: .identifier)
        titleVariants = try values.decode(VariantCollection<String>.self, forKey: .title)
        url = try values.decode(String.self, forKey: .url)
        abstractVariants = try values.decodeIfPresent(VariantCollection<[RenderInlineContent]>.self, forKey: .abstract) ?? .init(defaultValue: [])
        kind = try values.decodeIfPresent(RenderNode.Kind.self, forKey: .kind)
            // Provide backwards-compatibility for TopicRenderReferences that don't have a `kind` key.
            ?? .tutorial
        required = try values.decodeIfPresent(Bool.self, forKey: .required) ?? false
        role = try values.decodeIfPresent(String.self, forKey: .role)
        fragmentsVariants = try values.decodeVariantCollectionIfPresent(ofValueType: [DeclarationRenderSection.Token]?.self, forKey: .fragments) ?? .init(defaultValue: nil)
        navigatorTitleVariants = try values.decodeVariantCollectionIfPresent(ofValueType: [DeclarationRenderSection.Token]?.self, forKey: .navigatorTitle)
        conformance = try values.decodeIfPresent(ConformanceSection.self, forKey: .conformance)
        estimatedTime = try values.decodeIfPresent(String.self, forKey: .estimatedTime)
        isBeta = try values.decodeIfPresent(Bool.self, forKey: .beta) ?? false
        isDeprecated = try values.decodeIfPresent(Bool.self, forKey: .deprecated) ?? false
        defaultImplementationCount = try values.decodeIfPresent(Int.self, forKey: .defaultImplementations)
        titleStyle = try values.decodeIfPresent(TitleStyle.self, forKey: .titleStyle)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        ideTitle = try values.decodeIfPresent(String.self, forKey: .ideTitle)
        tags = try values.decodeIfPresent([RenderNode.Tag].self, forKey: .tags)
        images = try values.decodeIfPresent([TopicImage].self, forKey: .images) ?? []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(type, forKey: .type)
        try container.encode(identifier, forKey: .identifier)
        try container.encodeVariantCollection(titleVariants, forKey: .title, encoder: encoder)
        try container.encode(url, forKey: .url)
        try container.encodeVariantCollection(abstractVariants, forKey: .abstract, encoder: encoder)
        try container.encode(kind, forKey: .kind)
        
        if required {
            try container.encode(required, forKey: .required)
        }
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeVariantCollectionIfNotEmpty(fragmentsVariants, forKey: .fragments, encoder: encoder)
        try container.encodeIfPresent(navigatorTitle, forKey: .navigatorTitle)
        try container.encodeIfPresent(conformance, forKey: .conformance)
        try container.encodeIfPresent(estimatedTime, forKey: .estimatedTime)
        try container.encodeIfPresent(defaultImplementationCount, forKey: .defaultImplementations)
        
        if isBeta {
            try container.encode(isBeta, forKey: .beta)
        }
        if isDeprecated {
            try container.encode(isDeprecated, forKey: .deprecated)
        }
        try container.encodeIfPresent(titleStyle, forKey: .titleStyle)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(ideTitle, forKey: .ideTitle)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfNotEmpty(images, forKey: .images)
    }
}
