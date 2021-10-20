/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Arbitrary metadata for a render node.
public struct RenderMetadata {
    // MARK: Tutorials metadata
    
    /// The name of technology associated with a tutorial.
    public var category: String?
    public var categoryPathComponent: String?
    /// A description of the estimated time to complete the tutorials of a technology.
    public var estimatedTime: String?
    
    // MARK: Symbol metadata
    
    /// The modules that the symbol is apart of.
    public var modules: [Module]?
    
    /// The name of the module extension in which the symbol is defined, if applicable.
    public var extendedModule: String?
    
    /// The platform availability information about a symbol.
    public var platforms: [AvailabilityRenderItem]?
    
    /// Whether protocol method is required to be implemented by conforming types.
    public var required: Bool = false
    
    /// A heading describing the type of the document.
    public var roleHeading: String?
    
    /// The role of the document.
    ///
    /// Examples of document roles include "symbol" or "sampleCode".
    public var role: String?
    
    /// The title of the page.
    public var title: String?
    
    /// An identifier for a symbol generated externally.
    public var externalID: String?
    
    /// The kind of a symbol, e.g., "class" or "func".
    public var symbolKind: String?
    
    /// The access level of a symbol, e.g., "public" or "private".
    public var symbolAccessLevel: String?
    
    /// Abbreviated declaration to display in links.
    public var fragments: [DeclarationRenderSection.Token]?
    
    /// Abbreviated declaration to display in navigators.
    public var navigatorTitle: [DeclarationRenderSection.Token]?
    
    /// Additional metadata associated with the render node.
    public var extraMetadata: [CodingKeys: Any] = [:]
    
    /// Information the availability of generic APIs.
    public var conformance: ConformanceSection?
    
    /// The URI of the source file in which the symbol was originally declared, suitable for display in a user interface.
    ///
    /// This information may not (and should not) always be available for many reasons,
    /// such as compiler infrastructure limitations, or filesystem privacy and security concerns.
    public var sourceFileURI: String?
    
    /// Any tags assigned to the node.
    public var tags: [RenderNode.Tag]?
}

extension RenderMetadata: Codable {
    /// A list of pre-defined roles to assign to nodes.
    public enum Role: String {
        case symbol, containerSymbol, restRequestSymbol, dictionarySymbol, pseudoSymbol, pseudoCollection, collection, collectionGroup, article, sampleCode, unknown
        case table, codeListing, link, subsection, task, overview
        case tutorial = "project"
    }
    
    /// Metadata about a module dependency.
    public struct Module: Codable {
        public let name: String
        /// Possible dependencies to the module, we allow for those in the render JSON model
        /// but have no authoring support at the moment.
        public let relatedModules: [String]?
    }

    public struct CodingKeys: CodingKey, Hashable {
        public var stringValue: String
        
        public init(stringValue: String) {
            self.stringValue = stringValue
        }
        
        public var intValue: Int? {
            return nil
        }
        
        public init?(intValue: Int) {
            return nil
        }
        
        public static let category = CodingKeys(stringValue: "category")
        public static let categoryPathComponent = CodingKeys(stringValue: "categoryPathComponent")
        public static let estimatedTime = CodingKeys(stringValue: "estimatedTime")
        public static let modules = CodingKeys(stringValue: "modules")
        public static let extendedModule = CodingKeys(stringValue: "extendedModule")
        public static let platforms = CodingKeys(stringValue: "platforms")
        public static let required = CodingKeys(stringValue: "required")
        public static let roleHeading = CodingKeys(stringValue: "roleHeading")
        public static let role = CodingKeys(stringValue: "role")
        public static let title = CodingKeys(stringValue: "title")
        public static let externalID = CodingKeys(stringValue: "externalID")
        public static let symbolKind = CodingKeys(stringValue: "symbolKind")
        public static let symbolAccessLevel = CodingKeys(stringValue: "symbolAccessLevel")
        public static let conformance = CodingKeys(stringValue: "conformance")
        public static let fragments = CodingKeys(stringValue: "fragments")
        public static let navigatorTitle = CodingKeys(stringValue: "navigatorTitle")
        public static let sourceFileURI = CodingKeys(stringValue: "sourceFileURI")
        public static let tags = CodingKeys(stringValue: "tags")
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        category = try container.decodeIfPresent(String.self, forKey: .category)
        categoryPathComponent = try container.decodeIfPresent(String.self, forKey: .categoryPathComponent)

        platforms = try container.decodeIfPresent([AvailabilityRenderItem].self, forKey: .platforms)
        modules = try container.decodeIfPresent([Module].self, forKey: .modules)
        extendedModule = try container.decodeIfPresent(String.self, forKey: .extendedModule)
        estimatedTime = try container.decodeIfPresent(String.self, forKey: .estimatedTime)
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        roleHeading = try container.decodeIfPresent(String.self, forKey: .roleHeading)
        let rawRole = try container.decodeIfPresent(String.self, forKey: .role)
        role = rawRole == "tutorial" ? Role.tutorial.rawValue : rawRole
        title = try container.decodeIfPresent(String.self, forKey: .title)
        externalID = try container.decodeIfPresent(String.self, forKey: .externalID)
        symbolKind = try container.decodeIfPresent(String.self, forKey: .symbolKind)
        symbolAccessLevel = try container.decodeIfPresent(String.self, forKey: .symbolAccessLevel)
        conformance = try container.decodeIfPresent(ConformanceSection.self, forKey: .conformance)
        fragments = try container.decodeIfPresent([DeclarationRenderSection.Token].self, forKey: .fragments)
        navigatorTitle = try container.decodeIfPresent([DeclarationRenderSection.Token].self, forKey: .navigatorTitle)
        sourceFileURI = try container.decodeIfPresent(String.self, forKey: .sourceFileURI)
        tags = try container.decodeIfPresent([RenderNode.Tag].self, forKey: .tags)
        
        let extraKeys = Set(container.allKeys).subtracting(
            [
                .category,
                .categoryPathComponent,
                .estimatedTime,
                .modules,
                .extendedModule,
                .platforms,
                .required,
                .roleHeading,
                .role,
                .title,
                .externalID,
                .symbolKind,
                .symbolAccessLevel,
                .conformance,
                .fragments,
                .navigatorTitle,
                .sourceFileURI,
                .tags
            ]
        )
        for extraKey in extraKeys {
            extraMetadata[extraKey] = try container.decode(AnyMetadata.self, forKey: extraKey).value
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(categoryPathComponent, forKey: .categoryPathComponent)
        
        try container.encodeIfPresent(modules, forKey: .modules)
        try container.encodeIfPresent(extendedModule, forKey: .extendedModule)
        try container.encodeIfPresent(estimatedTime, forKey: .estimatedTime)
        try container.encodeIfPresent(platforms, forKey: .platforms)
        if required {
            try container.encodeIfPresent(required, forKey: .required)
        }
        try container.encodeIfPresent(roleHeading, forKey: .roleHeading)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(externalID, forKey: .externalID)
        try container.encodeIfPresent(symbolKind, forKey: .symbolKind)
        try container.encodeIfPresent(symbolAccessLevel, forKey: .symbolAccessLevel)
        try container.encodeIfPresent(conformance, forKey: .conformance)
        try container.encodeIfPresent(fragments, forKey: .fragments)
        try container.encodeIfPresent(navigatorTitle, forKey: .navigatorTitle)
        try container.encodeIfPresent(sourceFileURI, forKey: .sourceFileURI)
        if let tags = self.tags, !tags.isEmpty {
            try container.encodeIfPresent(tags, forKey: .tags)
        }
        
        for (key, value) in extraMetadata {
            try container.encode(AnyMetadata(value), forKey: key)
        }
    }
}
