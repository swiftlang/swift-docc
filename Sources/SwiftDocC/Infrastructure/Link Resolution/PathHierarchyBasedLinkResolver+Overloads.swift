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
    
    /// Returns the references for the overloaded symbols that belong to the given overload group.
    /// - Parameter reference: The reference of an overload group.
    /// - Returns: The references for overloaded symbols in the given group, or `nil` if the `reference` is not an overload group reference.
    func overloads(ofGroup reference: ResolvedTopicReference) -> [ResolvedTopicReference]? {
        guard let groupNodeID = resolvedReferenceMap[reference] else { return nil }
        let groupNode = pathHierarchy.lookup[groupNodeID]! // Only the path hierarchy can create its IDs and a created ID always matches a node
        
        guard let groupSymbol = groupNode.symbol, groupSymbol.isOverloadGroup else {
            return nil
        }
        assert(groupNode.languages == [.swift], "Only Swift supports overload groups. The implementation makes assumptions based on this.")
        
        let elementsWithSameName = groupNode.parent?.children[groupNode.name]?.storage ?? []
        
        let groupSymbolKindID = groupSymbol.kind.identifier
        return elementsWithSameName.compactMap {
            let id = $0.node.identifier
            guard id != groupNodeID, // Skip the overload group itself
                  $0.node.symbol?.kind.identifier == groupSymbolKindID // Only symbols of the same kind as the group are overloads
            else {
                return nil
            }
            
            assert(
                // The PathHierarchy doesn't track overloads (and I don't think it should) but we can check that the filtered elements
                // have the behaviors that's expected of overloaded symbols as a proxy to verify that no unexpected values are returned.
                $0.node.specialBehaviors == [.disfavorInLinkCollision, .excludeFromAutomaticCuration],
                """
                Node behaviors \($0.node.specialBehaviors) for \($0.node.symbol?.identifier.precise ?? "<non-symbol>") doesn't match an \
                overloaded symbol's behaviors (\(PathHierarchy.Node.SpecialBehaviors(arrayLiteral: [.disfavorInLinkCollision, .excludeFromAutomaticCuration])))
                """
            )
            
            return resolvedReferenceMap[$0.node.identifier]
        }
    }
}
