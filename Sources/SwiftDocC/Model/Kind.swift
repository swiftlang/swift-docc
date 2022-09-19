/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension DocumentationNode {
    /// The kind of a documentation node.
    public struct Kind: Hashable, Codable {
        /// The name of the kind, suitable for display.
        public var name: String
        /// A globally unique identifier for the kind, typically a reverse-dns name.
        public var id: String
        /// `true` if the documentation node is about a symbol, `false` otherwise.
        public var isSymbol: Bool
        
        /// `true` if the documentation has its own "page", `false` if it only exists in another node.
        public var isPage: Bool {
            switch self {
            case .unknown,
                 .volume,
                 .chapter,
                 .onPageLandmark,
                 .snippet:
                return false
            default:
                return true
            }
        }
    }
}

extension DocumentationNode.Kind {
    /// An unknown kind of documentation node.
    public static let unknown = DocumentationNode.Kind(name: "Unknown", id: "org.swift.docc.kind.unknown", isSymbol: false)
    
    /// An unknown kind of symbol documentation node.
    public static let unknownSymbol = DocumentationNode.Kind(name: "Unknown Symbol", id: "org.swift.docc.kind.unknownSymbol", isSymbol: true)
    
    // Grouping
    
    /// A documentation landing page.
    public static let landingPage = DocumentationNode.Kind(name: "Landing Page", id: "org.swift.docc.kind.landingPage", isSymbol: false)
    /// A documentation collection.
    public static let collection = DocumentationNode.Kind(name: "Collection", id: "org.swift.docc.kind.collection", isSymbol: false)
    /// A group of documentation collections.
    public static let collectionGroup = DocumentationNode.Kind(name: "CollectionGroup", id: "org.swift.docc.kind.collectionGroup", isSymbol: false)
    
    // Conceptual
    
    /// Root-level documentation.
    public static let root = DocumentationNode.Kind(name: "Documentation", id: "org.swift.docc.kind.root", isSymbol: false)
    /// Documentation about a module (also known as a framework, a library, or a package in some programming languages).
    public static let module = DocumentationNode.Kind(name: "Module", id: "org.swift.docc.kind.module", isSymbol: true)
    /// A documentation article.
    public static let article = DocumentationNode.Kind(name: "Article", id: "org.swift.docc.kind.article", isSymbol: false)
    /// A sample code project.
    public static let sampleCode = DocumentationNode.Kind(name: "Sample Code", id: "org.swift.docc.kind.sampleCode", isSymbol: false)
    /// A technology overview.
    public static let technologyOverview = DocumentationNode.Kind(name: "Technology (Overview)", id: "org.swift.docc.kind.technology.overview", isSymbol: false)
    /// A volume of documentation within a technology.
    public static let volume = DocumentationNode.Kind(name: "Volume", id: "org.swift.docc.kind.technology.volume", isSymbol: false)
    /// A chapter of documentation within a volume.
    public static let chapter = DocumentationNode.Kind(name: "Chapter", id: "org.swift.docc.kind.chapter", isSymbol: false)
    /// A tutorial.
    public static let tutorial = DocumentationNode.Kind(name: "Tutorial", id: "org.swift.docc.kind.tutorial", isSymbol: false)
    /// A tutorial article.
    public static let tutorialArticle = DocumentationNode.Kind(name: "Article", id: "org.swift.docc.kind.tutorialarticle", isSymbol: false)
    /// An on-page landmark.
    public static let onPageLandmark = DocumentationNode.Kind(name: "Landmark", id: "org.swift.docc.kind.landmark", isSymbol: false)
    
    // Containers
    
    /// Documentation about a class.
    public static let `class` = DocumentationNode.Kind(name: "Class", id: "org.swift.docc.kind.class", isSymbol: true)
    /// Documentation about a structure.
    public static let structure = DocumentationNode.Kind(name: "Structure", id: "org.swift.docc.kind.structure", isSymbol: true)
    /// Documentation about an enumeration.
    public static let enumeration = DocumentationNode.Kind(name: "Enumeration", id: "org.swift.docc.kind.enumeration", isSymbol: true)
    /// Documentation about a protocol.
    public static let `protocol` = DocumentationNode.Kind(name: "Protocol", id: "org.swift.docc.kind.protocol", isSymbol: true)
    /// Documentation about a technology.
    public static let technology = DocumentationNode.Kind(name: "Technology", id: "org.swift.docc.kind.technology", isSymbol: false)
    /// Documentation about an extension.
    public static let `extension` = DocumentationNode.Kind(name: "Extension", id: "org.swift.docc.kind.extension", isSymbol: true)
    
    // Leaves
    
    /// Documentation about a local variable.
    public static let localVariable = DocumentationNode.Kind(name: "Local Variable", id: "org.swift.docc.kind.localVariable", isSymbol: true)
    /// Documentation about a global variable.
    public static let globalVariable = DocumentationNode.Kind(name: "Global Variable", id: "org.swift.docc.kind.globalVariable", isSymbol: true)
    /// Documentation about a type alias.
    public static let typeAlias = DocumentationNode.Kind(name: "Type Alias", id: "org.swift.docc.kind.typeAlias", isSymbol: true)
    /// Documentation about a type definition.
    public static let typeDef = DocumentationNode.Kind(name: "Type Definition", id: "org.swift.docc.kind.typeDef", isSymbol: true)
    /// Documentation about an associated type.
    public static let associatedType = DocumentationNode.Kind(name: "Associated Type", id: "org.swift.docc.kind.associatedType", isSymbol: true)
    /// Documentation about a function.
    public static let function = DocumentationNode.Kind(name: "Function", id: "org.swift.docc.kind.function", isSymbol: true)
    /// Documentation about an operator.
    public static let `operator` = DocumentationNode.Kind(name: "Operator", id: "org.swift.docc.kind.operator", isSymbol: true)
    /// Documentation about a macro.
    public static let macro = DocumentationNode.Kind(name: "Macro", id: "org.swift.docc.kind.macro", isSymbol: true)
    /// Documentation about a union.
    public static let union = DocumentationNode.Kind(name: "Union", id: "org.swift.docc.kind.union", isSymbol: true)
    
    // Member-only leaves
    
    /// Documentation about an enumeration case.
    public static let enumerationCase = DocumentationNode.Kind(name: "Enumeration Case", id: "org.swift.docc.kind.enumerationCase", isSymbol: true)
    /// Documentation about an initializer.
    public static let initializer = DocumentationNode.Kind(name: "Initializer", id: "org.swift.docc.kind.initializer", isSymbol: true)
    /// Documentation about a deinitializer.
    public static let deinitializer = DocumentationNode.Kind(name: "Deinitializer", id: "org.swift.docc.kind.deinitializer", isSymbol: true)
    /// Documentation about an instance method.
    public static let instanceMethod = DocumentationNode.Kind(name: "Instance Method", id: "org.swift.docc.kind.instanceMethod", isSymbol: true)
    /// Documentation about an instance property.
    public static let instanceProperty = DocumentationNode.Kind(name: "Instance Property", id: "org.swift.docc.kind.instanceProperty", isSymbol: true)
    /// Documentation about an instance subscript.
    public static let instanceSubscript = DocumentationNode.Kind(name: "Subscript", id: "org.swift.docc.kind.instanceSubscript", isSymbol: true)
    /// Documentation about a type subscript.
    public static let instanceVariable = DocumentationNode.Kind(name: "Instance Variable", id: "org.swift.docc.kind.instanceVariable", isSymbol: true)
    /// Documentation about a type method.
    public static let typeMethod = DocumentationNode.Kind(name: "Type Method", id: "org.swift.docc.kind.typeMethod", isSymbol: true)
    /// Documentation about a type property.
    public static let typeProperty = DocumentationNode.Kind(name: "Type Property", id: "org.swift.docc.kind.typeProperty", isSymbol: true)
    /// Documentation about a type subscript.
    public static let typeSubscript = DocumentationNode.Kind(name: "Type Subscript", id: "org.swift.docc.kind.typeSubscript", isSymbol: true)
    /// Documentation about a type constant.
    public static let typeConstant = DocumentationNode.Kind(name: "Type Constant", id: "org.swift.docc.kind.typeConstant", isSymbol: true)
    
    // Data
    
    /// Documentation about a build setting.
    public static let buildSetting = DocumentationNode.Kind(name: "Build Setting", id: "org.swift.docc.kind.buildSetting", isSymbol: false)
    /// Documentation about a property list key.
    public static let propertyListKey = DocumentationNode.Kind(name: "Property List Key", id: "org.swift.docc.kind.propertyListKey", isSymbol: false)

    // Other
    
    /// Documentation about a keyword.
    public static let keyword = DocumentationNode.Kind(name: "Keyword", id: "org.swift.docc.kind.keyword", isSymbol: true)
    /// Documentation about a REST API.
    public static let restAPI = DocumentationNode.Kind(name: "Web Service Endpoint", id: "org.swift.docc.kind.restAPIRequest", isSymbol: false)
    /// Documentation about a tag.
    public static let tag = DocumentationNode.Kind(name: "Tag", id: "org.swift.docc.kind.tag", isSymbol: true)
    /// Documentation about a property list.
    public static let propertyList = DocumentationNode.Kind(name: "Property List", id: "org.swift.docc.kind.propertyList", isSymbol: false)
    /// Documentation about an object.
    public static let object = DocumentationNode.Kind(name: "Object", id: "org.swift.docc.kind.dictionary", isSymbol: true)
    /// A snippet.
    public static let snippet = DocumentationNode.Kind(name: "Snippet", id: "org.swift.docc.kind.snippet", isSymbol: true)
    
    public static let extendedModule = DocumentationNode.Kind(name: "Extended Module", id: "org.swift.docc.kind.extendedModule", isSymbol: true)

    public static let extendedStructure = DocumentationNode.Kind(name: "Extended Structure", id: "org.swift.docc.kind.extendedStructure", isSymbol: true)
    
    public static let extendedClass = DocumentationNode.Kind(name: "Extended Class", id: "org.swift.docc.kind.extendedClass", isSymbol: true)
    
    public static let extendedEnumeration = DocumentationNode.Kind(name: "Extended Enumeration", id: "org.swift.docc.kind.extendedEnumeration", isSymbol: true)
    
    public static let extendedProtocol = DocumentationNode.Kind(name: "Extended Protocol", id: "org.swift.docc.kind.extendedProtocol", isSymbol: true)
    
    public static let unknownExtendedType = DocumentationNode.Kind(name: "Extended Type", id: "org.swift.docc.kind.unknownExtendedType", isSymbol: true)

    /// The list of all known kinds of documentation nodes.
    /// - Note: The `unknown` value is not included.
    public static let allKnownValues: [DocumentationNode.Kind] = [
        // Grouping
        .landingPage, .collection, .collectionGroup,
        // Conceptual
        .root, .module, .article, .sampleCode, .technologyOverview, .volume, .chapter, .tutorial, .tutorialArticle, .onPageLandmark,
        // Containers
        .class, .structure, .enumeration, .protocol, .technology, .extension,
        // Leaves
        .localVariable, .globalVariable, .typeAlias, .typeDef, .typeConstant, .associatedType, .function, .operator, .macro, .union,
        // Member-only leaves
        .enumerationCase, .initializer, .deinitializer, .instanceMethod, .instanceProperty, .instanceSubscript, .instanceVariable, .typeMethod, .typeProperty, .typeSubscript,
        // Data
        .buildSetting, .propertyListKey,
        // Extended Symbols
        .extendedModule, .extendedStructure, .extendedClass, .extendedEnumeration, .extendedProtocol, .unknownExtendedType,
        // Other
        .keyword, .restAPI, .tag, .propertyList, .object
    ]
}
