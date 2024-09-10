/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

/// A set of functions that add relationship information to a topic graph.
struct SymbolGraphRelationshipsBuilder {
    /// A namespace for debug assert messages for data-correctness issues in the symbol graph data.
    private enum AssertionMessages {
        static func sourceNotFound(_ relationship: SymbolGraph.Relationship) -> String {
            """
            Source symbol \(relationship.source.singleQuoted) not found locally, from \(relationship.kind.rawValue.singleQuoted) relationship to \(relationship.target.singleQuoted).
            
            The "source" of a symbol graph relationship should always refer to a symbol in the same symbol graph file.
            If it doesn't, then the tool that created the symbol graph file should move the relationship to the symbol graph file that defines the "source" symbol \
            or remove the relationship if none of the created symbol graph file defines the "source" symbol.
            
            The "target" may refer to a symbol in another module.
            For example, if local symbol conforms to a protocol from another module, \
            there will be a "{ source: local-symbol-ID, kind: conformsTo, target: protocol-in-other-module-ID }" relationship.
            
            A symbol graph relationship with a non-local "source" symbol is a bug in the tool that created the symbol graph file.
            """
        }
        
        static func overloadGroupNotFound(_ relationship: SymbolGraph.Relationship) -> String {
            """
            Overload group \(relationship.source.singleQuoted) not found locally, from \(relationship.kind.rawValue.singleQuoted) relationship of \(relationship.source.singleQuoted).
            
            Both the "source" and "target" of an \(relationship.kind.rawValue.singleQuoted) symbol graph relationships with should always refer to symbols in the same symbol graph file.
            A \(relationship.kind.rawValue.singleQuoted) symbol graph relationship with a non-local "target" symbol is a bug in the tool that created the symbol graph file.
            """
        }
        
        static func invalidSymbolReference(_ reference: SymbolReference) -> String {
            return """
            Failed to create an unresolved reference for \(reference.path.singleQuoted). It contains characters that are not allowed in the "path" of a RFC 3986 URL.
            """
        }
    }
    
    /// Adds a two-way relationship from a default implementation to a protocol requirement.
    ///
    /// The target is optional, because the protocol might be from a different symbol graph.
    /// - Parameters:
    ///   - edge: A symbol graph relationship with a source and a target.
    ///   - selector: The symbol graph selector in which the relationship is relevant.
    ///   - bundle: A documentation bundle.
    ///   - context: A documentation context.
    ///   - localCache: A cache of local documentation content.
    ///   - engine: A diagnostic collecting engine.
    static func addImplementationRelationship(
        edge: SymbolGraph.Relationship,
        selector: UnifiedSymbolGraph.Selector,
        in bundle: DocumentationBundle,
        context: DocumentationContext,
        localCache: DocumentationContext.LocalCache,
        engine: DiagnosticEngine
    ) {
        // Resolve source symbol
        guard let implementorNode = localCache[edge.source],
              let implementorSymbol = implementorNode.semantic as? Symbol
        else {
            // The source node for implementation relationship not found.
            assertionFailure(AssertionMessages.sourceNotFound(edge))
            return
        }
        
        // Resolve target symbol if possible
        let optionalInterfaceNode = localCache[edge.target]

        if optionalInterfaceNode == nil {
            // Take the interface language of the target symbol
            // or if external - default to the language of the current symbol.
            let language = localCache[edge.target]?.sourceLanguage
                ?? implementorNode.reference.sourceLanguage
            
            let symbolReference = SymbolReference(edge.target, interfaceLanguage: language, symbol: localCache[edge.target]?.symbol)
            guard let unresolved = UnresolvedTopicReference(symbolReference: symbolReference, bundle: bundle) else {
                // The symbol reference format is invalid.
                assertionFailure(AssertionMessages.invalidSymbolReference(symbolReference))
                return
            }
            
            if let targetFallback = edge.targetFallback {
                implementorSymbol.defaultImplementations.targetFallbacks[.unresolved(unresolved)] = targetFallback
            }
        }
        
        // Find out the parent's title
        let parentName: String?

        if let reference = localCache.reference(symbolID: edge.source),
           let parentNode = try? context.entity(with: reference.removingLastPathComponent()),
           let title = (parentNode.semantic as? Symbol)?.title
        {
            parentName = title
        } else {
            parentName = nil
        }

        // Add default implementations to the requirement symbol.
        if let interfaceSymbol = optionalInterfaceNode?.semantic as? Symbol {
            // Add a default implementation
            interfaceSymbol.defaultImplementationsVariants[
                DocumentationDataVariantsTrait(for: selector),
                default: DefaultImplementationsSection()
            ].addImplementation(
                Implementation(reference: .successfullyResolved(implementorNode.reference), parent: parentName, fallbackName: edge.targetFallback)
            )
            
            // Make the implementation a child of the requirement
            guard let childReference = localCache.reference(symbolID: edge.source) else {
                // The child wasn't found, invalid reference in relationship.
                assertionFailure(SymbolGraphRelationshipsBuilder.AssertionMessages.sourceNotFound(edge))
                return
            }
            
            if let child = context.topicGraph.nodeWithReference(childReference),
               let targetReference = localCache.reference(symbolID: edge.target),
                let parent = context.topicGraph.nodeWithReference(targetReference) {
                context.topicGraph.addEdge(from: parent, to: child)
            }
        }
    }
    
    /// Adds a two-way relationship from a conforming type to a protocol.
    ///
    /// The target is optional, because the protocol might be from a different module.
    /// - Parameters:
    ///   - edge: A symbol-graph relationship with a source and a target.
    ///   - selector: The symbol graph selector in which the relationship is relevant.
    ///   - bundle: A documentation bundle.
    ///   - localCache: A cache of local documentation content.
    ///   - externalCache: A cache of external documentation content.
    ///   - engine: A diagnostic collecting engine.
    static func addConformanceRelationship(
        edge: SymbolGraph.Relationship,
        selector: UnifiedSymbolGraph.Selector,
        in bundle: DocumentationBundle,
        localCache: DocumentationContext.LocalCache,
        externalCache: DocumentationContext.ExternalCache,
        engine: DiagnosticEngine
    ) {
        // Resolve source symbol
        guard let conformingNode = localCache[edge.source],
              let conformingSymbol = conformingNode.semantic as? Symbol
        else {
            // The source node for conformance relationship not found.
            assertionFailure(AssertionMessages.sourceNotFound(edge))
            return
        }
        
        // Resolve target symbol if possible
        let optionalConformanceNode = localCache[edge.target]
        let conformanceNodeReference: TopicReference
        
        if let conformanceNode = optionalConformanceNode {
            conformanceNodeReference = .successfullyResolved(conformanceNode.reference)
        } else if let resolved = externalCache.reference(symbolID: edge.target) {
            conformanceNodeReference = .successfullyResolved(resolved)
        } else {
            // Take the interface language of the target symbol
            // or if external - default to the language of the current symbol.
            let language = localCache[edge.target]?.sourceLanguage
                ?? conformingNode.reference.sourceLanguage

            let symbolReference = SymbolReference(edge.target, interfaceLanguage: language, symbol: localCache[edge.target]?.symbol)
            guard let unresolved = UnresolvedTopicReference(symbolReference: symbolReference, bundle: bundle) else {
                // The symbol reference format is invalid.
                assertionFailure(AssertionMessages.invalidSymbolReference(symbolReference))
                return
            }
            conformanceNodeReference = .unresolved(unresolved)
            
            if let targetFallback = edge.targetFallback {
                conformingSymbol.relationshipsVariants[
                    DocumentationDataVariantsTrait(for: selector),
                    default: RelationshipsSection()
                ].targetFallbacks[.unresolved(unresolved)] = targetFallback
            }
        }
        
        // Conditional conformance constraints, if any
        let relationshipConstraints = edge[mixin: SymbolGraph.Relationship.Swift.GenericConstraints.self]

        // Add relationships depending whether it's class inheritance or protocol conformance
        if conformingSymbol.kind.identifier == .protocol {
            conformingSymbol.relationshipsVariants[
                DocumentationDataVariantsTrait(for: selector),
                default: RelationshipsSection()
            ].addRelationship(.inheritsFrom(conformanceNodeReference))
        } else {
            conformingSymbol.relationshipsVariants[
                DocumentationDataVariantsTrait(for: selector),
                default: RelationshipsSection()
            ].addRelationship(.conformsTo(conformanceNodeReference, relationshipConstraints?.constraints))
        }
        
        if let conformanceNode = optionalConformanceNode, let conformanceSymbol = conformanceNode.semantic as? Symbol {
            if let rawSymbol = conformingNode.symbol, rawSymbol.kind.identifier == .protocol {
                conformanceSymbol.relationshipsVariants[
                    DocumentationDataVariantsTrait(for: selector),
                    default: RelationshipsSection()
                ].addRelationship(.inheritedBy(.successfullyResolved(conformingNode.reference)))
            } else {
                conformanceSymbol.relationshipsVariants[
                    DocumentationDataVariantsTrait(for: selector),
                    default: RelationshipsSection()
                ].addRelationship(.conformingType(.successfullyResolved(conformingNode.reference), relationshipConstraints?.constraints))
            }
        }
    }
    
    /// Adds a two-way relationship from a child class to a parent class *or*
    /// a conforming protocol to a parent protocol.
    ///
    /// The target is optional, because the protocol or class might be from a different module.
    /// - Parameters:
    ///   - edge: A symbol graph relationship with a source and a target.
    ///   - selector: The symbol graph selector in which the relationship is relevant.
    ///   - bundle: A documentation bundle.
    ///   - localCache: A cache of local documentation content.
    ///   - externalCache: A cache of external documentation content.
    ///   - engine: A diagnostic collecting engine.
    static func addInheritanceRelationship(
        edge: SymbolGraph.Relationship,
        selector: UnifiedSymbolGraph.Selector,
        in bundle: DocumentationBundle,
        localCache: DocumentationContext.LocalCache,
        externalCache: DocumentationContext.ExternalCache,
        engine: DiagnosticEngine
    ) {
        // Resolve source symbol
        guard let childNode = localCache[edge.source],
              let childSymbol = childNode.semantic as? Symbol
        else {
            // The source node for inheritance relationship not found.
            assertionFailure(AssertionMessages.sourceNotFound(edge))
            return
        }
        
        // Resolve target symbol if possible
        let optionalParentNode = localCache[edge.target]
        let parentNodeReference: TopicReference
        
        if let parentNode = optionalParentNode {
            parentNodeReference = .successfullyResolved(parentNode.reference)
        } else if let resolved = externalCache.reference(symbolID: edge.target) {
            parentNodeReference = .successfullyResolved(resolved)
        } else {
            // Fallback on child symbol's language
            let language = childNode.reference.sourceLanguage
            
            let symbolReference = SymbolReference(edge.target, interfaceLanguage: language, symbol: nil)
            guard let unresolved = UnresolvedTopicReference(symbolReference: symbolReference, bundle: bundle) else {
                // The symbol reference format is invalid.
                assertionFailure(AssertionMessages.invalidSymbolReference(symbolReference))
                return
            }
            parentNodeReference = .unresolved(unresolved)
            
            // At this point the parent node we are inheriting from is unresolved, so let's add a fallback in case we can not resolve it later.
            if let targetFallback = edge.targetFallback {
                childSymbol.relationshipsVariants[
                    DocumentationDataVariantsTrait(for: selector),
                    default: RelationshipsSection()
                ].targetFallbacks[.unresolved(unresolved)] = targetFallback
            }
        }
        
        // Add relationships
        childSymbol.relationshipsVariants[
            DocumentationDataVariantsTrait(for: selector),
            default: RelationshipsSection()
        ].addRelationship(.inheritsFrom(parentNodeReference))
        
        if let parentNode = optionalParentNode, let parentSymbol = parentNode.semantic as? Symbol {
            parentSymbol.relationshipsVariants[
                DocumentationDataVariantsTrait(for: selector),
                default: RelationshipsSection()
            ].addRelationship(.inheritedBy(.successfullyResolved(childNode.reference)))
        }
    }
    
    /// Adds a required relationship from a type member to a protocol requirement.
    /// - Parameters:
    ///   - edge: A symbol graph relationship with a source and a target.
    ///   - localCache: A cache of local documentation content.
    ///   - engine: A diagnostic collecting engine.
    static func addRequirementRelationship(
        edge: SymbolGraph.Relationship,
        localCache: DocumentationContext.LocalCache,
        engine: DiagnosticEngine
    ) {
        addProtocolRelationship(
            edge: edge,
            localCache: localCache,
            engine: engine,
            required: true
        )
    }
    
    /// Adds an optional relationship from a type member to a protocol requirement.
    /// - Parameters:
    ///   - edge: A symbol graph relationship with a source and a target.
    ///   - localCache: A cache of local documentation content.
    ///   - engine: A diagnostic collecting engine.
    static func addOptionalRequirementRelationship(
        edge: SymbolGraph.Relationship,
        localCache: DocumentationContext.LocalCache,
        engine: DiagnosticEngine
    ) {
        addProtocolRelationship(
            edge: edge,
            localCache: localCache,
            engine: engine,
            required: false
        )
    }
    
    /// Adds a relationship from a type member to a protocol requirement.
    /// - Parameters:
    ///   - edge: A symbol graph relationship with a source and a target.
    ///   - localCache: A cache of local documentation content.
    ///   - engine: A diagnostic collecting engine.
    ///   - required: A bool value indicating whether the protocol requirement is required or optional
    private static func addProtocolRelationship(
        edge: SymbolGraph.Relationship,
        localCache: DocumentationContext.LocalCache,
        engine: DiagnosticEngine,
        required: Bool
    ) {
        // Resolve source symbol
        guard let requiredNode = localCache[edge.source],
              let requiredSymbol = requiredNode.semantic as? Symbol
        else {
            // The source node for requirement relationship not found.
            assertionFailure(AssertionMessages.sourceNotFound(edge))
            return
        }
        requiredSymbol.isRequired = required
    }
    
    /// Sets a node in the context as an inherited symbol.
    ///
    /// - Parameters:
    ///   - sourceOrigin: The symbol's source origin.
    ///   - inheritedSymbolID: The precise identifier of the inherited symbol.
    ///   - context: A documentation context.
    ///   - localCache: A cache of local documentation content.
    ///   - moduleName: The symbol name of the current module.
    static func addInheritedDefaultImplementation(
        sourceOrigin: SymbolGraph.Relationship.SourceOrigin,
        inheritedSymbolID: String,
        context: DocumentationContext,
        localCache: DocumentationContext.LocalCache,
        moduleName: String
    ) {
        guard let inherited = localCache[inheritedSymbolID], let inheritedSymbolSemantic = inherited.semantic as? Symbol else {
            return
        }
        
        // If this a local inherited symbol, update the origin data of that symbol.
        inheritedSymbolSemantic.origin = sourceOrigin
        
        // Check if the origin symbol is also local. Always inherit the documentation from other local symbols.
        if let parentSymbolSemantic = localCache[sourceOrigin.identifier]?.semantic as? Symbol,
           inheritedSymbolSemantic.moduleReference == parentSymbolSemantic.moduleReference
        {
            return
        }
        
        // Remove any inherited docs from the original symbol if the feature is disabled.
        // However, when the docs are inherited from within the same module, its content can be resolved in
        // the local context, so keeping those inherited docs provide a better user experience.
        if !context.externalMetadata.inheritDocs, let unifiedSymbol = inherited.unifiedSymbol, unifiedSymbol.documentedSymbol?.isDocCommentFromSameModule(symbolModuleName: moduleName) == false {
            unifiedSymbol.docComment.removeAll()
        }
    }

    /// Add a new generic constraint: "Self is SomeProtocol" to members of
    /// protocol extensions of protocols from external modules. When a protocol
    /// is defined in a different module it's not clear which protocol the
    /// extension is for since we don't otherwise display that, unless implied
    /// by curation.
    ///
    /// - Parameters:
    ///   - edge: A symbol graph relationship with a source and a target.
    ///   - extendedModuleRelationships: Source->target dictionary for external module relationships.
    ///   - localCache: A cache of local documentation content.
    static func addProtocolExtensionMemberConstraint(
        edge: SymbolGraph.Relationship,
        extendedModuleRelationships: [String : String],
        localCache: DocumentationContext.LocalCache
    ) {
        // Utility function to look up a symbol identifier in the
        // symbol index, returning its documentation node and semantic symbol
        func nodeAndSymbolFor(identifier: String) -> (DocumentationNode, Symbol)? {
            if let node = localCache[identifier], let symbol = node.semantic as? Symbol {
                return (node, symbol)
            }
            return nil
        }

        // Is this symbol a member of some type from an extended module?
        guard let extendedModuleRelationship = extendedModuleRelationships[edge.target] else {
            return
        }

        // Return unless the target symbol is a protocol. The "Self is ..."
        // constraint only makes sense for protocol extensions.
        guard let (targetNode, targetSymbol) = nodeAndSymbolFor(identifier: edge.target) else {
            return
        }
        guard targetNode.kind == .extendedProtocol else {
            return
        }

        // Obtain the source symbol
        guard let (_, sourceSymbol) = nodeAndSymbolFor(identifier: edge.source) else {
            return
        }

        // Obtain the extended module documentation node.
        guard let (_, extendedModuleSymbol) = nodeAndSymbolFor(identifier: extendedModuleRelationship) else {
            return
        }

        // Create a new generic constraint: "Self is SomeProtocol" to show which
        // protocol this function's extension is extending.  When the protocol is
        // defined in a different module it's not clear at all which protocol it
        // is, especially if the curation doesn't indicate that.
        let newConstraint = SymbolGraph.Symbol.Swift.GenericConstraint(
            kind: SymbolGraph.Symbol.Swift.GenericConstraint.Kind.sameType,
            leftTypeName: "Self",
            rightTypeName: targetSymbol.title
        )

        // Add the constraint to the source symbol, the member of the protocol
        // extension.
        sourceSymbol.addSwiftExtensionConstraint(
            extendedModule: extendedModuleSymbol.title,
            extendedSymbolKind: .protocol,
            constraint: newConstraint
        )
    }

    static func addOverloadRelationship(
        edge: SymbolGraph.Relationship,
        context: DocumentationContext,
        localCache: DocumentationContext.LocalCache,
        engine: DiagnosticEngine
    ) {
        guard let overloadNode = localCache[edge.source] else {
            assertionFailure(AssertionMessages.sourceNotFound(edge))
            return
        }
        guard let overloadGroupNode = localCache[edge.target] else {
            assertionFailure(AssertionMessages.overloadGroupNotFound(edge))
            return
        }

        guard let overloadTopicGraphNode = context.topicGraph.nodes[overloadNode.reference],
              let overloadGroupTopicGraphNode = context.topicGraph.nodes[overloadGroupNode.reference]
        else {
            return
        }
        overloadGroupTopicGraphNode.isOverloadGroup = true
        context.topicGraph.addEdge(from: overloadGroupTopicGraphNode, to: overloadTopicGraphNode)
    }
}
