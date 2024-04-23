/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension DirectedGraph {
    /// Returns the first cycle in the graph encountered through breadth first traversal from a given starting point
    ///
    /// The cycle starts at the earliest repeated node and ends with the node that links back to the starting point.
    ///
    /// - Note: A cycle, if found, is guaranteed to contain at least one node.
    func firstCycle(from startingPoint: Node) -> Path? {
        for case let (path, _, cycleStartIndex?) in accumulatingPaths(from: startingPoint) {
            return Array(path[cycleStartIndex...])
        }
        return nil
    }
    
    /// Returns a list of all the unique cycles in the graph encountered through breadth first traversal from a given starting point.
    ///
    /// Each cycle starts at the earliest repeated node and ends with the node that links back to the starting point.
    ///
    /// Two cycles are considered the same if they have either:
    /// - The same start and end points, for example: `1,2,3` and `1,3`.
    /// - A rotation of the same cycle, for example: `1,2,3`, `2,3,1`, and `3,1,2`.
    func cycles(from startingPoint: Node) -> [Path] {
        var cycles = [Path]()
        
        for case let (path, _, cycleStartIndex?) in accumulatingPaths(from: startingPoint) {
            let cycle = path[cycleStartIndex...]
            guard !cycles.contains(where: { areSameCycle(cycle, $0) }) else {
                continue
            }
            cycles.append(Array(cycle))
        }
        
        return cycles
    }
    
    private func areSameCycle(_ lhs: Path.SubSequence, _ rhs: Path) -> Bool {
        // Check if the cycles have the same start and end points.
        // A cycle has to contain at least one node, so it's always safe to unwrap 'first' and 'last'.
        if lhs.first! == rhs.first!, lhs.last! == rhs.last! {
            return true
        }
        
        // Check if the cycles are rotations of each other
        if lhs.count == rhs.count {
            let rhsStart = rhs.first!
            
            return (lhs + lhs)                   // Repeat one of the cycles once
                .drop(while: { $0 != rhsStart }) // Align it with the other cycle by removing its leading nodes
                .starts(with: rhs)               // See if the cycles match
        }
        // The two cycles are different.
        return false
    }
}
