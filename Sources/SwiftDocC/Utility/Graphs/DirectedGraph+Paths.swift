/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension DirectedGraph {
    /// Returns a list of all finite (acyclic) paths through the graph from a given starting point.
    ///
    /// The paths are found in breadth first order, so shorter paths are earlier in the returned list.
    ///
    /// - Note: Nodes that are reachable through multiple paths will be visited more than once.
    ///
    /// - Important: If all paths through the graph are infinite (cyclic), this function return an empty list.
    func allFinitePaths(from startingPoint: Node) -> [Path] {
        var foundPaths = [Path]()
        
        for (path, isLeaf, _) in accumulatingPaths(from: startingPoint) where isLeaf {
            foundPaths.append(path)
        }

        return foundPaths
    }
    
    /// Returns a list of the finite (acyclic) paths through the graph with the shortest length from a given starting point.
    ///
    /// The paths are found in breadth first order, so shorter paths are earlier in the returned list.
    ///
    /// - Note: Nodes that are reachable through multiple paths will be visited more than once.
    ///
    /// - Important: If all paths through the graph are infinite (cyclic), this function return an empty list.
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
    /// - Important: If all paths through the graph are infinite (cyclic), this function return an empty set.
    func reachableLeafNodes(from startingPoint: Node) -> Set<Node> {
        var foundLeafNodes: Set<Node> = []
        
        for (path, isLeaf, _) in accumulatingPaths(from: startingPoint) where isLeaf {
            foundLeafNodes.insert(path.last!)
        }

        return foundLeafNodes
    }
}

// MARK: Path sequence

extension DirectedGraph {
    /// A path through the graph, including the start and end nodes.
    typealias Path = [Node]
    /// Information about the current accumulated path during iteration.
    typealias PathIterationElement = (path: Path, isLeaf: Bool, cycleStartIndex: Int?)
    
    /// Returns a sequence of accumulated path information from traversing the graph in breadth first order.
    func accumulatingPaths(from startingPoint: Node) -> some Sequence<PathIterationElement> {
        IteratorSequence(GraphPathIterator(from: startingPoint, in: self))
    }
}

// MARK: Iterator

/// An iterator that traverses a graph in breadth first order and returns information about the accumulated path through the graph, up to the current node.
private struct GraphPathIterator<Node: Hashable>: IteratorProtocol {
    var pathsToTraverse: [(Node, [Node])]
    var graph: DirectedGraph<Node>
    
    init(from startingPoint: Node, in graph: DirectedGraph<Node>) {
        self.pathsToTraverse = [(startingPoint, [])]
        self.graph = graph
    }
    
    mutating func next() -> DirectedGraph<Node>.PathIterationElement? {
        guard !pathsToTraverse.isEmpty else { return nil }
        // This is a breadth first search through the graph.
        let (node, path) = pathsToTraverse.removeFirst()
        
        // Note: unlike `GraphNodeIterator`, the same node may be visited more than once.
        
        if let cycleStartIndex = path.firstIndex(of: node) {
            return (path, false, cycleStartIndex)
        }
        
        let newPath = path + [node]
        let neighbors = graph.neighbors(of: node)
        pathsToTraverse.append(contentsOf: neighbors.map { ($0, newPath) })
        
        return (newPath, neighbors.isEmpty, nil)
    }
}
