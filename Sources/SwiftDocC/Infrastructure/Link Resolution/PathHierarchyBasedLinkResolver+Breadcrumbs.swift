/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

extension PathHierarchyBasedLinkResolver {
    func breadcrumbs(of reference: ResolvedTopicReference, in sourceLanguage: SourceLanguage) -> [ResolvedTopicReference]? {
        guard let nodeID = resolvedReferenceMap[reference] else { return nil }
        
        var node = pathHierarchy.lookup[nodeID]! // Only the path hierarchy can create its IDs and a created ID always matches a node
        
        func matchesRequestedLanguage(_ node: PathHierarchy.Node) -> Bool {
            guard let symbol = node.symbol,
                  let language = SourceLanguage(knownLanguageIdentifier: symbol.identifier.interfaceLanguage)
            else {
                return false
            }
            return language == sourceLanguage
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
                $0.identifier.flatMap { resolvedReferenceMap[$0] }
            }
    }
    
    func nearestContainers(ofSymbol reference: ResolvedTopicReference) -> (ResolvedTopicReference, counterpart: ResolvedTopicReference?)? {
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
