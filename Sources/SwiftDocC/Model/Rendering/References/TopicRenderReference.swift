/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A reference to another page of documentation in the current context.
public struct TopicRenderReference: RenderReference, VariantContainer, Equatable {
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
    
    /// The names and style for a reference to a property list key or entitlement key.
    public var propertyListKeyNames: PropertyListKeyNames?
    
    /// The display name and raw key name for a property list key or entitlement key and configuration about which "name" to use for links to this page.
    public struct PropertyListKeyNames: Equatable {
        /// A style for how to render links to a property list key or an entitlement key.
        public var titleStyle: PropertyListTitleStyle?
        /// The raw key name of a property list key or entitlement key, for example "com.apple.enableDataAccess".
        public var rawKey: String?
        /// The human friendly display name for a property list key or entitlement key, for example, "Enables Data Access".
        public var displayName: String?
    }
    
    /// An optional list of text-based tags.
    public var tags: [RenderNode.Tag]?
    
    /// Author provided images that represent this page.
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
    ///   - propertyListKeyNames: The names and style configuration for a property list key or entitlement key,  or `nil` if the referenced page is not a property list key or entitlement key.
    ///   - tags: An optional list of string tags.
    ///   - images: Author provided images that represent this page.
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
        estimatedTime: String? = nil,
        conformance: ConformanceSection? = nil,
        isBeta: Bool = false,
        isDeprecated: Bool = false,
        defaultImplementationCount: Int? = nil,
        propertyListKeyNames: PropertyListKeyNames? = nil,
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
            propertyListKeyNames: propertyListKeyNames,
            tags: tags,
            images: images
        )
    }
    
    /// Creates a new topic reference with all its initial values.
    ///
    /// - Parameters:
    ///   - identifier: The identifier of this reference.
    ///   - titleVariants: The variants for the title of the destination page.
    ///   - abstractVariants: The abstract of the destination page.
    ///   - url: The topic url of the destination page.
    ///   - kind: The kind of page that's referenced.
    ///   - required: Whether the reference is required in its parent context.
    ///   - role: The additional "role" assigned to the symbol, if any.
    ///   - fragmentsVariants: The abbreviated declaration of the symbol to display in links, or `nil` if the referenced page is not a symbol.
    ///   - navigatorTitleVariants: The abbreviated declaration of the symbol to display in navigation, or `nil` if the referenced page is not a symbol.
    ///   - estimatedTime: The estimated time to complete the topic.
    ///   - conformance: Information about conditional conformance for the symbol, or `nil` if the referenced page is not a symbol.
    ///   - isBeta: Whether this symbol is built for a beta platform, or `false` if the referenced page is not a symbol.
    ///   - isDeprecated: Whether this symbol is deprecated, or `false` if the referenced page is not a symbol.
    ///   - defaultImplementationCount: Number of default implementations for this symbol, or `nil` if the referenced page is not a symbol.
    ///   - propertyListKeyNames: The names and style configuration for a property list key or entitlement key,  or `nil` if the referenced page is not a property list key or entitlement key.
    ///   - tags: An optional list of string tags.
    ///   - images: Author provided images that represent this page.
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
        estimatedTime: String? = nil,
        conformance: ConformanceSection? = nil,
        isBeta: Bool = false,
        isDeprecated: Bool = false,
        defaultImplementationCount: Int? = nil,
        propertyListKeyNames: PropertyListKeyNames? = nil,
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
        self.propertyListKeyNames = propertyListKeyNames
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
        case propertyListTitleStyle = "titleStyle"
        case propertyListRawKey = "name"
        case propertyListDisplayName = "ideTitle"
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
        let propertyListTitleStyle = try values.decodeIfPresent(PropertyListTitleStyle.self, forKey: .propertyListTitleStyle)
        let propertyListRawKey = try values.decodeIfPresent(String.self, forKey: .propertyListRawKey)
        let propertyListDisplayName = try values.decodeIfPresent(String.self, forKey: .propertyListDisplayName)
        if propertyListRawKey != nil || propertyListRawKey != nil || propertyListDisplayName != nil {
            propertyListKeyNames = PropertyListKeyNames(
                titleStyle: propertyListTitleStyle,
                rawKey: propertyListRawKey,
                displayName: propertyListDisplayName
            )
        }
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
        try container.encodeVariantCollectionIfNotEmpty(navigatorTitleVariants, forKey: .navigatorTitle, encoder: encoder)
        try container.encodeIfPresent(conformance, forKey: .conformance)
        try container.encodeIfPresent(estimatedTime, forKey: .estimatedTime)
        try container.encodeIfPresent(defaultImplementationCount, forKey: .defaultImplementations)
        
        if isBeta {
            try container.encode(isBeta, forKey: .beta)
        }
        if isDeprecated {
            try container.encode(isDeprecated, forKey: .deprecated)
        }
        try container.encodeIfPresent(propertyListKeyNames?.titleStyle, forKey: .propertyListTitleStyle)
        try container.encodeIfPresent(propertyListKeyNames?.rawKey, forKey: .propertyListRawKey)
        try container.encodeIfPresent(propertyListKeyNames?.displayName, forKey: .propertyListDisplayName)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfNotEmpty(images, forKey: .images)
    }
}

// Diffable conformance
extension TopicRenderReference: RenderJSONDiffable {
    /// Returns the difference between two TopicRenderReferences.
    func difference(from other: TopicRenderReference, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.type, forKey: CodingKeys.type)
        diffBuilder.addDifferences(atKeyPath: \.identifier, forKey: CodingKeys.identifier)
        diffBuilder.addDifferences(atKeyPath: \.title, forKey: CodingKeys.title)
        diffBuilder.addDifferences(atKeyPath: \.url, forKey: CodingKeys.url)
        diffBuilder.addDifferences(atKeyPath: \.abstract, forKey: CodingKeys.abstract)
        diffBuilder.addDifferences(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.required, forKey: CodingKeys.required)
        diffBuilder.addDifferences(atKeyPath: \.role, forKey: CodingKeys.role)
        diffBuilder.addDifferences(atKeyPath: \.fragments, forKey: CodingKeys.fragments)
        diffBuilder.addDifferences(atKeyPath: \.navigatorTitle, forKey: CodingKeys.navigatorTitle)
        diffBuilder.addDifferences(atKeyPath: \.conformance, forKey: CodingKeys.conformance)
        diffBuilder.addDifferences(atKeyPath: \.estimatedTime, forKey: CodingKeys.estimatedTime)
        diffBuilder.addDifferences(atKeyPath: \.defaultImplementationCount, forKey: CodingKeys.defaultImplementations)
        diffBuilder.addDifferences(atKeyPath: \.isBeta, forKey: CodingKeys.beta)
        diffBuilder.addDifferences(atKeyPath: \.isDeprecated, forKey: CodingKeys.deprecated)
        diffBuilder.addDifferences(atKeyPath: \.propertyListKeyNames?.titleStyle, forKey: CodingKeys.propertyListTitleStyle)
        diffBuilder.addDifferences(atKeyPath: \.propertyListKeyNames?.rawKey, forKey: CodingKeys.propertyListRawKey)
        diffBuilder.addDifferences(atKeyPath: \.propertyListKeyNames?.displayName, forKey: CodingKeys.propertyListDisplayName)
        diffBuilder.addDifferences(atKeyPath: \.tags, forKey: CodingKeys.tags)
        diffBuilder.addDifferences(atKeyPath: \.images, forKey: CodingKeys.images)
        
        return diffBuilder.differences
    }
}

// MARK: Deprecated

extension TopicRenderReference {
    @available(*, deprecated, renamed: "propertyListTitleStyle", message: "Use 'propertyListTitleStyle' instead. This deprecated API will be removed after 6.1 is released")
    public var titleStyle: TitleStyle? {
        get {
            propertyListKeyNames?.titleStyle.map { $0.titleStyle }
        }
        set {
            if propertyListKeyNames == nil {
                propertyListKeyNames = PropertyListKeyNames()
            }
            propertyListKeyNames!.titleStyle = newValue.map { .init(titleStyle: $0) }
        }
    }
    
    @available(*, deprecated, renamed: "propertyListRawKey", message: "Use 'propertyListRawKey' instead. This deprecated API will be removed after 6.1 is released")
    public var name: String? {
        get { 
            propertyListKeyNames?.rawKey
        }
        set {
            if propertyListKeyNames == nil {
                propertyListKeyNames = PropertyListKeyNames()
            }
            propertyListKeyNames!.rawKey = newValue
        }
    }
    
    @available(*, deprecated, renamed: "propertyListDisplayName", message: "Use 'propertyListDisplayName' instead. This deprecated API will be removed after 6.1 is released")
    public var ideTitle: String? {
        get { 
            propertyListKeyNames?.displayName
        }
        set {
            if propertyListKeyNames == nil {
                propertyListKeyNames = PropertyListKeyNames()
            }
            propertyListKeyNames!.displayName = newValue
        }
    }
    
    @_disfavoredOverload
    @available(*, deprecated, renamed: "init(identifier:title:abstract:url:kind:required:role:fragments:navigatorTitle:estimatedTime:conformance:isBeta:isDeprecated:defaultImplementationCount:propertyListKeyNames:tags:images:)", message: "Use 'init(identifier:title:abstract:url:kind:required:role:fragments:navigatorTitle:estimatedTime:conformance:isBeta:isDeprecated:defaultImplementationCount:propertyListKeyNames:tags:images:)' instead. This deprecated API will be removed after 6.1 is released")
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
        estimatedTime: String? = nil,
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
            propertyListKeyNames: PropertyListKeyNames(
                titleStyle: titleStyle.map { .init(titleStyle: $0) },
                rawKey: name,
                displayName: ideTitle
            ),
            tags: tags,
            images: images
        )
    }
    
    @_disfavoredOverload
    @available(*, deprecated, renamed: "init(identifier:titleVariants:abstractVariants:url:kind:required:role:fragmentsVariants:navigatorTitleVariants:estimatedTime:conformance:isBeta:isDeprecated:defaultImplementationCount:propertyListKeyNames:tags:images:)", message: "Use 'init(identifier:titleVariants:abstractVariants:url:kind:required:role:fragmentsVariants:navigatorTitleVariants:estimatedTime:conformance:isBeta:isDeprecated:defaultImplementationCount:propertyListKeyNames:tags:images:)' instead. This deprecated API will be removed after 6.1 is released")
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
        estimatedTime: String? = nil,
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
        if titleStyle != nil || name != nil || ideTitle != nil {
            self.propertyListKeyNames = PropertyListKeyNames(
                titleStyle: titleStyle.map { .init(titleStyle: $0) },
                rawKey: name,
                displayName: ideTitle
            )
        }
        self.tags = tags
        self.images = images
    }
}

@available(*, deprecated, message: "This deprecated API will be removed after 6.1 is released")
private extension PropertyListTitleStyle {
    var titleStyle: TitleStyle {
        switch self {
        case .useDisplayName: return .title
        case .useRawKey:      return .symbol
        }
    }
    
    init(titleStyle: TitleStyle) {
        switch titleStyle {
        case .title:  self = .useDisplayName
        case .symbol: self = .useRawKey
        }
    }
}
