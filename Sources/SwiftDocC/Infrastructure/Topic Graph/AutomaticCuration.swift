/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import SymbolKit

/// A set of functions that add automatic symbol curation to a topic graph.
public struct AutomaticCuration {
    /// A value type to store an automatically curated task group and its sorting index.
    struct ReferenceGroup {
        let title: String
        let sortOrder: Int
        var references = [ResolvedTopicReference]()
        
        init(title: String, sortOrder: Int = 0, references: [ResolvedTopicReference] = []) {
            self.title = title
            self.sortOrder = sortOrder
            self.references = references
        }
    }
    
    /// A mapping between a symbol kind and its matching group.
    typealias ReferenceGroupIndex = [SymbolGraph.Symbol.Kind.Swift: ReferenceGroup]
    
    /// A static list of predefined groups for each supported kind of symbol.
    static var groups: ReferenceGroupIndex {
        return groupKindOrder.enumerated().reduce(into: ReferenceGroupIndex()) { (result, next) in
            result[next.element] = ReferenceGroup(title: AutomaticCuration.groupTitle(for: next.element), sortOrder: next.offset)
        }
    }
    
    /// Automatic curation task group.
    typealias TaskGroup = (title: String, references: [ResolvedTopicReference])
    
    /// Returns a list of automatically curated Topics task groups for the given documentation node.
    /// - Parameters:
    ///   - node: A node for which to generate topics groups.
    ///   - context: A documentation context.
    /// - Returns: An array of title and references list tuples.
    static func topics(for node: DocumentationNode, context: DocumentationContext) throws -> [TaskGroup] {
        // Get any default implementation relationships for this symbol
        let defaultImplementationReferences = Set<String>(
            (node.semantic as? Symbol)?.defaultImplementations.implementations.compactMap { $0.reference.url?.absoluteString } ?? []
        )
        
        return try context.children(of: node.reference)
            // Remove any default implementations
            .filter({ (reference, kind) -> Bool in
                return !defaultImplementationReferences.contains(reference.absoluteString)
            })
            // Force unwrapping as all nodes need to be valid in the rendering phase of the pipeline.
            .reduce(into: AutomaticCuration.groups) { groupsIndex, child in
                
                guard context.parents(of: child.reference).count == 1 else {
                    // There are other parents than `node` - the child is curated via markdown.
                    return
                }
                
                let childNode = try context.entity(with: child.reference)
                guard let childSymbol = childNode.semantic as? Symbol,
                    let swiftKind = SymbolGraph.Symbol.Kind.Swift(rawValue: childSymbol.kind.identifier) else {
                    return
                }
                
                groupsIndex[swiftKind]?.references.append(child.reference)
            }
            .lazy
            // Sort the groups in the order intended for rendering
            .sorted(by: { (lhs, rhs) -> Bool in
                return lhs.value.sortOrder < rhs.value.sortOrder
            })
            // Map to sorted tuples
            .compactMap { groupIndex in
                let group = groupIndex.value
                guard !group.references.isEmpty else { return nil }
                return (title: group.title, references: group.references.sorted { $0.path < $1.path })
            }
    }
    
    /// Returns a list of automatically curated See Also task groups for the given documentation node.
    /// - Parameters:
    ///   - node: A node for which to generate a See Also group.
    ///   - context: A documentation context.
    ///   - bundle: A documentation bundle.
    /// - Returns: A group title and the group's references or links.
    ///   `nil` if the method can't find any relevant links to automatically generate a See Also content.
    static func seeAlso(for node: DocumentationNode, context: DocumentationContext, bundle: DocumentationBundle, renderContext: RenderContext?, renderer: DocumentationContentRenderer) throws -> TaskGroup? {
        // First try getting the canonical path from a render context, default to the documentation context
        guard let canonicalPath = renderContext?.store.content(for: node.reference)?.canonicalPath ?? context.pathsTo(node.reference).first,
            !canonicalPath.isEmpty else {
            // If the symbol is not curated or is a root symbol, no See Also please.
            return nil
        }
        
        let parentReference = canonicalPath.last!
        
        // Look up the render context first
        if let taskGroups = renderContext?.store.content(for: parentReference)?.taskGroups,
            let linkingGroup = taskGroups
                .mapFirst(where: { group -> DocumentationContentRenderer.ReferenceGroup? in
                    group.references.contains(node.reference) ? group : nil
                })
        {
            // Group match in render context, verify if there are any other references besides the current one.
            guard linkingGroup.references.count > 1 else { return nil }
            return (title: linkingGroup.title, references: linkingGroup.references.filter { $0 != node.reference })
        }
        
        // Get the parent's task groups
        guard let taskGroups = renderer.taskGroups(for: parentReference) else {
            return nil
        }
        
        // Find the group where the current symbol is curated
        let linkingGroup = taskGroups.first { group -> Bool in
            group.references.contains(node.reference)
        }
        
        // Verify there is a matching linking group and more references than just the current one.
        guard let group = linkingGroup, group.references.count > 1 else {
            return nil
        }
        
        return (title: group.title, references: group.references.filter { $0 != node.reference })
    }
}

extension AutomaticCuration {
    /// Returns a topics group title for the given symbol kind.
    /// - Parameter symbolKind: A symbol kind, such as a protocol or a variable.
    /// - Returns: A group title for symbols of the given kind.
    static func groupTitle(`for` symbolKind: SymbolGraph.Symbol.Kind.Swift) -> String {
        switch symbolKind {
            case .`associatedtype`: return "Associated Types"
            case .`class`: return "Classes"
            case .`deinit`: return "Deinitializers"
            case .`enum`: return "Enumerations"
            case .`case`: return "Enumeration Cases"
            case .`func`: return "Functions"
            case .`operator`: return "Operators"
            case .`init`: return "Initializers"
            case .`method`: return "Instance Methods"
            case .`property`: return "Instance Properties"
            case .`protocol`: return "Protocols"
            case .`struct`: return "Structures"
            case .`subscript`: return "Subscripts"
            case .`typeMethod`: return "Type Methods"
            case .`typeProperty`: return "Type Properties"
            case .`typeSubscript`: return "Type Subscripts"
            case .`typealias`: return "Type Aliases"
            case .`var`: return "Variables"
            case .module: return "Modules"
        }
    }

    /// The order of symbol kinds when grouped automatically.
    static let groupKindOrder: [SymbolGraph.Symbol.Kind.Swift] = [
        .module,

        .`class`,
        .`protocol`,
        .`struct`,
        .`var`,
        .`func`,
        .`operator`,

        .`associatedtype`,
        .`case`,
        .`init`,
        .`deinit`,
        .`property`,
        .`method`,
        .`subscript`,

        .`typealias`,
        .`typeProperty`,
        .`typeMethod`,
        .`enum`
    ]
}
