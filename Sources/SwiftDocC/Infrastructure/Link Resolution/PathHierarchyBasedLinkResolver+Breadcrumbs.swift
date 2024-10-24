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
