/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

/// A set of functions that add relationship information to a topic graph.
struct SymbolGraphRelationshipsBuilder {
    /// A namespace for creation of topic-graph related problems.
    enum NodeProblem {
        /// Returns a problem about a node with the given precise identifier not being found.
        static func notFound(_ identifier: String) -> Problem {
            return Problem(diagnostic: Diagnostic(source: nil, severity: .error, range: nil, identifier: "org.swift.docc.SymbolNodeNotFound", summary: "Symbol with identifier \(identifier.singleQuoted) couldn't be found"), possibleSolutions: [])
        }
        /// Returns a problem about a node with the given reference not being found.
        static func invalidReference(_ reference: String) -> Problem {
            return Problem(diagnostic: Diagnostic(source: nil, severity: .error, range: nil, identifier: "org.swift.docc.InvalidSymbolIdentifier", summary: "Relationship symbol path \(reference.singleQuoted) isn't valid"), possibleSolutions: [])
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
    ///   - symbolIndex: A symbol lookup map by precise identifier.
    ///   - engine: A diagnostic collecting engine.
    static func addImplementationRelationship(
        edge: SymbolGraph.Relationship,
        selector: UnifiedSymbolGraph.Selector,
        in bundle: DocumentationBundle,
        context: DocumentationContext,
        symbolIndex: inout [String: DocumentationNode],
        engine: DiagnosticEngine
    ) {
        // Resolve source symbol
        guard let implementorNode = symbolIndex[edge.source],
            let implementorSymbol = implementorNode.semantic as? Symbol else {
            // The source node for implementation relationship not found.
            engine.emit(NodeProblem.notFound(edge.source))
            return
        }
        
        // Resolve target symbol if possible
        let optionalInterfaceNode = symbolIndex[edge.target]

        if optionalInterfaceNode == nil {
            // Take the interface language of the target symbol
            // or if external - default to the language of the current symbol.
            let language = symbolIndex[edge.target]?.reference.sourceLanguage
                ?? implementorNode.reference.sourceLanguage
            
            let symbolReference = SymbolReference(edge.target, interfaceLanguage: language, symbol: symbolIndex[edge.target]?.symbol)
            guard let unresolved = UnresolvedTopicReference(symbolReference: symbolReference, bundle: bundle) else {
                // The symbol reference format is invalid.
                engine.emit(NodeProblem.invalidReference(symbolReference.path))
                return
            }
            
            if let targetFallback = edge.targetFallback {
                implementorSymbol.defaultImplementations.targetFallbacks[.unresolved(unresolved)] = targetFallback
            }
        }
        
        // Find out the parent's title
        let parentName: String?

        if let reference = symbolIndex[edge.source]?.reference,
            let parentNode = try? context.entity(with: reference.removingLastPathComponent()),
            let title = (parentNode.semantic as? Symbol)?.title {
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
            guard let childReference = symbolIndex[edge.source]?.reference else {
                // The child wasn't found, invalid reference in relationship.
                engine.emit(SymbolGraphRelationshipsBuilder.NodeProblem.notFound(edge.source))
                return
            }
            
            if let child = context.topicGraph.nodeWithReference(childReference),
                let targetReference = symbolIndex[edge.target]?.reference,
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
    ///   - bundle: A documentation bundle.
    ///   - symbolIndex: A symbol-lookup map by precise identifier.
    ///   - engine: A diagnostic collecting engine.
    static func addConformanceRelationship(
        edge: SymbolGraph.Relationship,
        selector: UnifiedSymbolGraph.Selector,
        in bundle: DocumentationBundle,
        symbolIndex: inout [String: DocumentationNode],
        engine: DiagnosticEngine
    ) {
        // Resolve source symbol
        guard let conformingNode = symbolIndex[edge.source],
            let conformingSymbol = conformingNode.semantic as? Symbol else {
            // The source node for coformance relationship not found.
            engine.emit(NodeProblem.notFound(edge.source))
            return
        }
        
        // Resolve target symbol if possible
        let optionalConformanceNode = symbolIndex[edge.target]
        let conformanceNodeReference: TopicReference
        
        if let conformanceNode = optionalConformanceNode {
            conformanceNodeReference = .successfullyResolved(conformanceNode.reference)
        } else {
            // Take the interface language of the target symbol
            // or if external - default to the language of the current symbol.
            let language = symbolIndex[edge.target]?.reference.sourceLanguage
                ?? conformingNode.reference.sourceLanguage

            let symbolReference = SymbolReference(edge.target, interfaceLanguage: language, symbol: symbolIndex[edge.target]?.symbol)
            guard let unresolved = UnresolvedTopicReference(symbolReference: symbolReference, bundle: bundle) else {
                // The symbol reference format is invalid.
                engine.emit(NodeProblem.invalidReference(symbolReference.path))
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
        let relationshipConstraints = edge.mixins[SymbolGraph.Relationship.Swift.GenericConstraints.mixinKey] as? SymbolGraph.Relationship.Swift.GenericConstraints

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
    ///   - symbolIndex: A symbol lookup map by precise identifier.
    ///   - engine: A diagnostic collecting engine.
    static func addInheritanceRelationship(
        edge: SymbolGraph.Relationship,
        selector: UnifiedSymbolGraph.Selector,
        in bundle: DocumentationBundle,
        symbolIndex: inout [String: DocumentationNode],
        engine: DiagnosticEngine
    ) {
        // Resolve source symbol
        guard let childNode = symbolIndex[edge.source],
            let childSymbol = childNode.semantic as? Symbol else {
            // The source node for inheritance relationship not found.
            engine.emit(NodeProblem.notFound(edge.source))
            return
        }
        
        // Resolve target symbol if possible
        let optionalParentNode = symbolIndex[edge.target]
        let parentNodeReference: TopicReference
        
        if let parentNode = optionalParentNode {
            parentNodeReference = .successfullyResolved(parentNode.reference)
        } else {
            // Use the target symbol language, if external - fallback on child symbol's langauge
            let language = symbolIndex[edge.target]?.symbol.map({ SourceLanguage(id: $0.identifier.interfaceLanguage) })
                ?? childNode.reference.sourceLanguage
            
            let symbolReference = SymbolReference(edge.target, interfaceLanguage: language, symbol: symbolIndex[edge.target]?.symbol)
            guard let unresolved = UnresolvedTopicReference(symbolReference: symbolReference, bundle: bundle) else {
                // The symbol reference format is invalid.
                engine.emit(NodeProblem.invalidReference(symbolReference.path))
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
    ///   - selector: The symbol graph selector in which the relationship is relevant.
    ///   - bundle: A documentation bundle.
    ///   - symbolIndex: A symbol lookup map by precise identifier.
    ///   - engine: A diagnostic collecting engine.
    static func addRequirementRelationship(
        edge: SymbolGraph.Relationship,
        selector: UnifiedSymbolGraph.Selector,
        in bundle: DocumentationBundle,
        symbolIndex: inout [String: DocumentationNode],
        engine: DiagnosticEngine
    ) {
        addProtocolRelationship(
            edge: edge,
            selector: selector,
            in: bundle,
            symbolIndex: &symbolIndex,
            engine: engine,
            required: true
        )
    }
    
    /// Adds an optional relationship from a type member to a protocol requirement.
    /// - Parameters:
    ///   - edge: A symbol graph relationship with a source and a target.
    ///   - selector: The symbol graph selector in which the relationship is relevant.
    ///   - bundle: A documentation bundle.
    ///   - symbolIndex: A symbol lookup map by precise identifier.
    ///   - engine: A diagnostic collecting engine.
    static func addOptionalRequirementRelationship(
        edge: SymbolGraph.Relationship,
        selector: UnifiedSymbolGraph.Selector,
        in bundle: DocumentationBundle,
        symbolIndex: inout [String: DocumentationNode],
        engine: DiagnosticEngine
    ) {
        addProtocolRelationship(
            edge: edge,
            selector: selector,
            in: bundle,
            symbolIndex: &symbolIndex,
            engine: engine,
            required: false
        )
    }
    
    /// Adds a relationship from a type member to a protocol requirement.
    /// - Parameters:
    ///   - edge: A symbol graph relationship with a source and a target.
    ///   - selector: The symbol graph selector in which the relationship is relevant.
    ///   - bundle: A documentation bundle.
    ///   - symbolIndex: A symbol lookup map by precise identifier.
    ///   - engine: A diagnostic collecting engine.
    ///   - required: A bool value indicating whether the protocol requirement is required or optional
    private static func addProtocolRelationship(
        edge: SymbolGraph.Relationship,
        selector: UnifiedSymbolGraph.Selector,
        in bundle: DocumentationBundle,
        symbolIndex: inout [String: DocumentationNode],
        engine: DiagnosticEngine, required: Bool
    ) {
        // Resolve source symbol
        guard let requiredNode = symbolIndex[edge.source],
            let requiredSymbol = requiredNode.semantic as? Symbol else {
            // The source node for requirement relationship not found.
            engine.emit(NodeProblem.notFound(edge.source))
            return
        }
        requiredSymbol.isRequired = required
    }
    
    /// Sets a node in the context as an inherited symbol if the origin symbol is provided in the given relationship.
    ///
    /// - Parameters:
    ///   - edge: A symbol graph relationship with a source and a target.
    ///   - selector: The symbol graph selector in which the relationship is relevant.
    ///   - context: A documentation context.
    ///   - symbolIndex: A symbol lookup map by precise identifier.
    ///   - moduleName: The symbol name of the current module.
    ///   - engine: A diagnostic collecting engine.
    static func addInheritedDefaultImplementation(
        edge: SymbolGraph.Relationship,
        context: DocumentationContext, 
        symbolIndex: inout [String: DocumentationNode], 
        moduleName: String, 
        engine: DiagnosticEngine
    ) {
        func setAsInheritedSymbol(origin: SymbolGraph.Relationship.SourceOrigin, for node: inout DocumentationNode, originNode: DocumentationNode?) {
            (node.semantic as! Symbol).origin = origin
            
            // Check if the origin symbol is present.
            if let parent = originNode,
                let parentModule = (parent.semantic as? Symbol)?.moduleReference,
                let nodeModule = (node.semantic as? Symbol)?.moduleReference,
                parentModule == nodeModule {
                // If the origin is in the same bundle - always inherit the docs.
                return
            }
            
            // Remove any inherited docs from the original symbol if the feature is disabled.
            // However, when the docs are inherited from within the same module, its content can be resolved in
            // the local context, so keeping those inherited docs provide a better user experience.
            if !context.externalMetadata.inheritDocs && node.unifiedSymbol?.documentedSymbol?.isDocCommentFromSameModule(symbolModuleName: moduleName) == false {
                node.unifiedSymbol?.docComment.removeAll()
            }
        }
        
        switch edge.kind {
            case .memberOf, .defaultImplementationOf: break
            default: return // Ignore source origin for other relationships.
        }
        
        // Should this be a relationship for a symbol which is inherited
        // verify we have the matching data in symbolIndex and documentationCache
        // and add the origin data to the symbol.
        if let origin = edge.mixins[SymbolGraph.Relationship.SourceOrigin.mixinKey] as? SymbolGraph.Relationship.SourceOrigin,
           let node = symbolIndex[edge.source],
           node.semantic is Symbol,
           context.documentationCache.keys.contains(node.reference) {

            // OK to unwrap - we've verified the existence of the key above.
            setAsInheritedSymbol(origin: origin, for: &symbolIndex[edge.source]!, originNode: symbolIndex[origin.identifier])
            setAsInheritedSymbol(origin: origin, for: &context.documentationCache[node.reference]!, originNode: symbolIndex[origin.identifier])
        }
    }
}

