/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
import Markdown

/// A collection of APIs to generate documentation topics.
enum GeneratedDocumentationTopics {
    
    /// An index of types and symbols they inherit.
    struct InheritedSymbols {
        var implementingTypes = [ResolvedTopicReference: Collections]()
        
        /// An index of the default implementation providers for a single type.
        struct Collections {
            var inheritedFromTypeName = [String: APICollection]()
            
            /// A collection of symbols a single type inherits from a single provider.
            struct APICollection {
                /// The title of the collection.
                var title: String
                /// A reference to the parent of the collection.
                let parentReference: ResolvedTopicReference
                /// A list of topic references for the collection.
                var identifiers = [ResolvedTopicReference]()
            }
        }
        
        /// Adds a given inherited symbol to the index.
        /// - Parameters:
        ///   - childReference: The inherited symbol reference.
        ///   - reference: The parent type reference.
        ///   - originDisplayName: The origin display name as provided by the symbol graph.
        ///   - extendedModuleName: Extended module name.
        mutating func add(_ childReference: ResolvedTopicReference, to reference: ResolvedTopicReference, childSymbol: SymbolGraph.Symbol, originDisplayName: String, originSymbol: SymbolGraph.Symbol?, extendedModuleName: String) throws {
            let fromType: String
            let typeSimpleName: String
            if let originSymbol = originSymbol, originSymbol.pathComponents.count > 1 {
                // If we have a resolved symbol for the source origin, use its path components to
                // find the name of the parent by dropping the last path component.
                let parentSymbolPathComponents = originSymbol.pathComponents.dropLast()
                fromType = parentSymbolPathComponents.joined(separator: ".")
                typeSimpleName = parentSymbolPathComponents.last!
            } else if let childSymbolName = childSymbol.pathComponents.last,
                originDisplayName.count > (childSymbolName.count + 1)
            {
                // In the case where we don't have a resolved symbol for the source origin,
                // this allows us to still accurately handle cases like this:
                //
                //     "displayName": "SuperFancyProtocol..<..(_:_:)"
                //
                // Where there's no way for us to determine which of the periods is the one
                // splitting the name of the parent type and the symbol name. Using the count
                // of the symbol name (+1 for the period splitting the names)
                // from the source is a reliable way to support this.
                
                let parentSymbolName = originDisplayName.dropLast(childSymbolName.count + 1)
                fromType = String(parentSymbolName)
                typeSimpleName = String(parentSymbolName.split(separator: ".").last ?? parentSymbolName)
            } else {
                // This should never happen but is a last safeguard for the case where
                // the child symbol is unexpectedly short. In this case, we can attempt to just parse
                // the parent symbol name out of the origin display name.

                // Detect the path components of the providing the default implementation.
                let typeComponents = originDisplayName.split(separator: ".")

                // Verify that the fully qualified name contains at least a type name and default implementation name.
                guard typeComponents.count >= 2 else { return }

                // Get the fully qualified type.
                fromType = typeComponents.dropLast().joined(separator: ".")
                // The name of the type is second to last.
                typeSimpleName = String(typeComponents[typeComponents.count-2])
            }

            // Create a type with inherited symbols, if needed.
            if !implementingTypes.keys.contains(reference) {
                implementingTypes[reference] = Collections()
            }
            
            // Create a new default implementations provider, if needed.
            if !implementingTypes[reference]!.inheritedFromTypeName.keys.contains(fromType) {
                implementingTypes[reference]!.inheritedFromTypeName[fromType] = Collections.APICollection(title: "\(typeSimpleName) Implementations", parentReference: reference)
            }
            
            // Add the default implementation.
            implementingTypes[reference]!.inheritedFromTypeName[fromType]!.identifiers.append(childReference)
        }
    }
    
    private static let defaultImplementationGroupTitle = "Default Implementations"
    
    private static func createCollectionNode(parent: ResolvedTopicReference, title: String, identifiers: [ResolvedTopicReference], context: DocumentationContext, bundle: DocumentationBundle) throws {
        let automaticCurationSourceLanguage: SourceLanguage
        let automaticCurationSourceLanguages: Set<SourceLanguage>
        automaticCurationSourceLanguage = identifiers.first?.sourceLanguage ?? .swift
        automaticCurationSourceLanguages = Set(identifiers.flatMap { identifier in context.sourceLanguages(for: identifier) })
        
        // Create the collection topic reference
        let collectionReference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: NodeURLGenerator.Path.documentationCuration(
                parentPath: parent.path,
                articleName: title
            ).stringValue,
            sourceLanguages: automaticCurationSourceLanguages
        )
        
        // Add the topic graph node
        let collectionTopicGraphNode = TopicGraph.Node(reference: collectionReference, kind: .collection, source: .external, title: title, isResolvable: false)
        context.topicGraph.addNode(collectionTopicGraphNode)

        // Curate the collection task group under the collection parent type
        
        let node = try context.entity(with: parent)
        if let symbol = node.semantic as? Symbol {
            for trait in node.availableVariantTraits {
                guard let language = trait.interfaceLanguage,
                      automaticCurationSourceLanguages.lazy.map(\.id).contains(language)
                else {
                    // If the collection is not available in this trait, don't curate it in this symbol's variant.
                    continue
                }
                if let matchIndex = symbol.automaticTaskGroupsVariants[trait]?.firstIndex(where: { $0.title == defaultImplementationGroupTitle }) {
                    // Update the existing group
                    var inheritedSection = symbol.automaticTaskGroupsVariants[trait]![matchIndex]
                    inheritedSection.references.append(collectionReference)
                    inheritedSection.references.sort(by: \.lastPathComponent)
                    symbol.automaticTaskGroupsVariants[trait]?[matchIndex] = inheritedSection
                } else {
                    // Add a new group
                    let inheritedSection = AutomaticTaskGroupSection(title: defaultImplementationGroupTitle, references: [collectionReference], renderPositionPreference: .bottom)
                    symbol.automaticTaskGroupsVariants[trait]?.append(inheritedSection)
                }
                if let hierarchyBasedLinkResolver = context.hierarchyBasedLinkResolver {
                    hierarchyBasedLinkResolver.addTaskGroup(named: title, reference: collectionReference, to: parent)
                }
            }
        } else {
            fatalError("createCollectionNode() should be used only to add nodes under symbols.")
        }
        
        // Curate all inherited symbols under the collection node
        for childReference in identifiers {
            if let childTopicGraphNode = context.topicGraph.nodeWithReference(childReference) {
                context.topicGraph.addEdge(from: collectionTopicGraphNode, to: childTopicGraphNode)
            }
        }

        // Create an article to provide content for the node
        var collectionArticle: Article
        
        // Find matching doc extension or create an empty article.
        if let docExtensionMatch = context.uncuratedDocumentationExtensions[collectionReference]?.first?.value {
            collectionArticle = docExtensionMatch
            collectionArticle.title = Heading(level: 1, Text(title))
            context.uncuratedDocumentationExtensions.removeValue(forKey: collectionReference)
        } else {
            collectionArticle = Article(
                title: Heading(level: 1, Text(title)),
                abstractSection: nil,
                discussion: nil,
                topics: nil,
                seeAlso: nil,
                deprecationSummary: nil,
                metadata: nil,
                redirects: nil
            )
        }

        // Create a temp node in order to generate the automatic curation
        let temporaryCollectionNode = DocumentationNode(
            reference: collectionReference,
            kind: .collectionGroup,
            sourceLanguage: automaticCurationSourceLanguage,
            availableSourceLanguages: automaticCurationSourceLanguages,
            name: DocumentationNode.Name.conceptual(title: title),
            markup: Document(parsing: ""),
            semantic: Article(markup: nil, metadata: nil, redirects: nil, options: [:])
        )
        
        let collectionTaskGroups = try AutomaticCuration.topics(for: temporaryCollectionNode, withTrait: nil, context: context)
            .map { taskGroup in
                AutomaticTaskGroupSection(
                    // Force-unwrapping the title since automatically-generated task groups always have a title.
                    title: taskGroup.title!,
                    references: taskGroup.references,
                    renderPositionPreference: .bottom
                )
            }

        // Add the curation task groups to the article
        collectionArticle.automaticTaskGroups = collectionTaskGroups
        
        // Create the documentation node
        let collectionNode = DocumentationNode(
            reference: collectionReference,
            kind: .collectionGroup,
            sourceLanguage: automaticCurationSourceLanguage,
            availableSourceLanguages: automaticCurationSourceLanguages,
            name: DocumentationNode.Name.conceptual(title: title),
            markup: Document(parsing: ""),
            semantic: collectionArticle
        )

        // Curate the collection node
        context.topicGraph.addEdge(from: context.topicGraph.nodeWithReference(parent)!, to: collectionTopicGraphNode)
        context.documentationCache[collectionReference] = collectionNode

        // Add the node anchors to the context
        for anchor in collectionNode.anchorSections {
            context.nodeAnchorSections[anchor.reference] = anchor
        }
    }
    
    /// Creates a API collection in the given documentation context for all inherited symbols according to the symbol graph.
    ///
    /// Inspects the given symbol relationships and extracts all inherited symbols into a separate level in the documentation hierarchy -
    /// an API collection called "Inherited APIs" where all inherited symbols are listed unless they are manually curated in
    /// a documentation extension.
    ///
    /// ```
    /// MyKit
    /// ╰ MyView
    ///   ╰ View Implementations
    ///     ╰ accessibilityValue()
    /// ```
    ///
    /// > Warning: This method tracks internal state via an ``InheritedSymbols`` inheritance index.
    /// It must be called **once** per symbol by passing in _all_ of the relationships that apply
    /// to a symbol.
    ///
    /// - Parameters:
    ///   - relationships: A set of relationships to inspect.
    ///   - symbolsURLHierarchy: A symbol graph hierarchy as created during symbol registration.
    ///   - context: A documentation context to update.
    ///   - bundle: The current documentation bundle.
    static func createInheritedSymbolsAPICollections(relationships: [SymbolGraph.Relationship], context: DocumentationContext, bundle: DocumentationBundle) throws {
        var inheritanceIndex = InheritedSymbols()
        
        // Walk the symbol graph relationships and look for parent <-> child links that stem in a different module.
        for relationship in relationships {
            
            // Check the relationship type
            if relationship.kind == .memberOf,
               // Check that there is origin information (i.e. the symbol is inherited)
               let origin = relationship.mixins[SymbolGraph.Relationship.SourceOrigin.mixinKey] as? SymbolGraph.Relationship.SourceOrigin,
               // Resolve the containing type
               let parent = context.symbolIndex[relationship.target],
               // Resolve the child
               let child = context.symbolIndex[relationship.source],
               // Get the child symbol
               let childSymbol = child.symbol,
               // Get the swift extension data
               let extends = childSymbol.mixins[SymbolGraph.Symbol.Swift.Extension.mixinKey] as? SymbolGraph.Symbol.Swift.Extension {
                let originSymbol = context.symbolIndex[origin.identifier]?.symbol
                
                // Add the inherited symbol to the index.
                try inheritanceIndex.add(child.reference, to: parent.reference, childSymbol: childSymbol, originDisplayName: origin.displayName, originSymbol: originSymbol, extendedModuleName: extends.extendedModule)
            }
        }
        
        // Create the API Collection nodes and the necessary topic graph curation.
        for (typeReference, collections) in inheritanceIndex.implementingTypes where !collections.inheritedFromTypeName.isEmpty {
            for (_, collection) in collections.inheritedFromTypeName where !collection.identifiers.isEmpty {
                // Create a collection for the given provider type's inherited symbols
                try createCollectionNode(parent: typeReference, title: collection.title, identifiers: collection.identifiers, context: context, bundle: bundle)
            }
        }
    }
    
}
