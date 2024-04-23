/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension DirectedGraph {
    /// Returns a list of all finite paths through the graph from a given starting point.
    ///
    /// The paths are found in breadth first order, so shorter paths are earlier in the returned list.
    ///
    /// - Note: Nodes that are reachable through multiple paths will be visited more than once.
    ///
    /// - Important: If all paths through the graph result in cycles, the returned list will be empty.
    func allFinitePaths(from startingPoint: Node) -> [Path] {
        var foundPaths = [Path]()
        
        for (path, isLeaf, _) in accumulatingPaths(from: startingPoint) where isLeaf {
            foundPaths.append(path)
        }

        return foundPaths
    }
    
    /// Returns a list of the finite paths through the graph with the shortest length from a given starting point.
    ///
    /// The paths are found in breadth first order, so shorter paths are earlier in the returned list.
    ///
    /// - Note: Nodes that are reachable through multiple paths will be visited more than once.
    ///
    /// - Important: If all paths through the graph result in cycles, the returned list will be empty.
    func shortestFinitePaths(from startingPoint: Node) -> [Path] {
        var foundPaths = [Path]()
        
        for (path, isLeaf, _) in accumulatingPaths(from: startingPoint) where isLeaf {
            if let lengthOfFoundPath = foundPaths.first?.count, lengthOfFoundPath < path.count {
                // This path is longer than an already found path.
                // All paths found from here on will be longer than what's already found.
                break
            }
            
            foundPaths.append(path)
        }

        return foundPaths
    }
    
    /// Returns a set of all the reachable leaf nodes by traversing the graph from a given starting point.
    ///
    /// - Important: If all paths through the graph result in cycles, the returned set will be empty.
    func reachableLeafNodes(from startingPoint: Node) -> Set<Node> {
        var foundLeafNodes: Set<Node> = []
        
        for (path, isLeaf, _) in accumulatingPaths(from: startingPoint) where isLeaf {
            foundLeafNodes.insert(path.last!)
        }

        return foundLeafNodes
    }
}
