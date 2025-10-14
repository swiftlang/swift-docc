/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
import Common

extension PathHierarchyBasedLinkResolver {
    
    /// Finds the canonical path, also called "breadcrumbs", to the given symbol in the path hierarchy.
    /// The path is a list of references that describe a walk through the path hierarchy descending from the module down to, but not including, the given `reference`.
    ///
    /// - Parameters:
    ///   - reference: The symbol reference to find the canonical path to.
    ///   - sourceLanguage: The source language representation of the symbol to fin the canonical path for.
    /// - Returns: The canonical path to the given symbol reference, or `nil` if the reference isn't a symbol or if the symbol doesn't have a representation in the given source language.
    func breadcrumbs(of reference: ResolvedTopicReference, in sourceLanguage: SourceLanguage) -> [ResolvedTopicReference]? {
        guard let nodeID = resolvedReferenceMap[reference] else { return nil }
        var node = pathHierarchy.lookup[nodeID]! // Only the path hierarchy can create its IDs and a created ID always matches a node
        
        func matchesRequestedLanguage(_ node: PathHierarchy.Node) -> Bool {
             node.languages.contains(sourceLanguage)
        }
        
        if !matchesRequestedLanguage(node) {
            guard let counterpart = node.counterpart, matchesRequestedLanguage(counterpart) else {
                // Neither this symbol, nor its counterpart matched the requested language
                return nil
            }
            // Traverse from the counterpart instead because it matches the requested language
            node = counterpart
        }
        
        // Traverse up the hierarchy and gather each reference
        return sequence(first: node, next: \.parent)
            // The hierarchy traversal happened from the starting point up, but the callers of `breadcrumbs(of:in:)`
            // expect paths going from the root page, excluding the starting point itself (already dropped above).
            // To match the caller's expectations we remove the starting point and then flip the paths.
            .dropFirst().reversed()
            .compactMap {
                // Ignore any "unfindable" or "sparse" nodes resulting from a "partial" symbol graph.
                //
                // When the `ConvertService` builds documentation for a single symbol with multiple path components,
                // the path hierarchy fills in unfindable nodes for the other path components to construct a connected hierarchy.
                //
                // These unfindable nodes can be traversed up and down, but are themselves considered to be "not found".
                $0.identifier.flatMap { resolvedReferenceMap[$0] }
            }
    }

    /// Returns the nearest canonical containers for the different language representations of a given symbol.
    /// - Parameter reference: The symbol reference to find the canonical containers for.
    /// - Returns: The  canonical containers for the different language representations of a given symbol, or `nil` if the reference is a module or a non-symbol.
    func nearestContainers(ofSymbol reference: ResolvedTopicReference) -> (main: ResolvedTopicReference, counterpart: ResolvedTopicReference?)? {
        guard let nodeID = resolvedReferenceMap[reference] else { return nil }
        
        let node = pathHierarchy.lookup[nodeID]! // Only the path hierarchy can create its IDs and a created ID always matches a node
        guard node.symbol != nil else { return nil }
        
        func containerReference(_ node: PathHierarchy.Node) -> ResolvedTopicReference? {
            guard let containerID = node.parent?.identifier else { return nil }
            return resolvedReferenceMap[containerID]
        }
        
        guard let main = containerReference(node) else { return nil }
        
        return (main, node.counterpart.flatMap(containerReference))
    }
}
