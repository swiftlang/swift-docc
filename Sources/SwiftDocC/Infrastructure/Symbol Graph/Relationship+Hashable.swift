/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

// Adds Hashable & Equatable conformance so we can store relationships in a `Set`.
extension SymbolGraph.Relationship: Hashable, Equatable {
    
    /// A custom hashing for the relationship.
    /// > Important: If there are new relationship mixins they need to be added to the hasher in this function.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(source)
        hasher.combine(target)
        hasher.combine(kind.rawValue)
        hasher.combine(targetFallback)
        hasher.combine(mixins[SymbolGraph.Relationship.Swift.GenericConstraints.mixinKey] as? Swift.GenericConstraints)
    }
    
    /// A custom equality implmentation for a relationship.
    /// > Important: If there are new relationship mixins they need to be added to the equality function.
    public static func == (lhs: SymbolGraph.Relationship, rhs: SymbolGraph.Relationship) -> Bool {
        return lhs.source == rhs.source
            && lhs.target == rhs.target
            && lhs.kind == rhs.kind
            && lhs.targetFallback == rhs.targetFallback
            && lhs.mixins[SymbolGraph.Relationship.Swift.GenericConstraints.mixinKey] as? Swift.GenericConstraints
                == rhs.mixins[SymbolGraph.Relationship.Swift.GenericConstraints.mixinKey] as? Swift.GenericConstraints
    }
}
