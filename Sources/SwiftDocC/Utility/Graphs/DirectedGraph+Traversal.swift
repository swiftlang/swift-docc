/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension DirectedGraph {
    /// Returns a sequence that traverses the graph in breadth first order from a given element, without visiting the same node more than once.
    func breadthFirstSearch(from startingPoint: Node) -> some Sequence<Node> {
        IteratorSequence(GraphNodeIterator(from: startingPoint, traversal: .breadthFirst, in: self))
    }
    
    /// Returns a sequence that traverses the graph in depth first order from a given element, without visiting the same node more than once.
    func depthFirstSearch(from startingPoint: Node) -> some Sequence<Node> {
        IteratorSequence(GraphNodeIterator(from: startingPoint, traversal: .depthFirst, in: self))
    }
}

extension DirectedGraph {
    /// A path through the graph, including the start and end nodes.
    typealias Path = [Node]
    /// Information about the current accumulated path during iteration.
    typealias PathIterationElement = (path: Path, isLeaf: Bool, cycleStartIndex: Int?)
    
    /// Returns a sequence of accumulated path information from traversing the graph in breadth first order.
    func accumulatingPaths(from startingPoint: Node) -> some Sequence<PathIterationElement> {
        IteratorSequence(GraphBreadthFirstPathIterator(from: startingPoint, in: self))
    }
}

// MARK: Node iterator

/// An iterator that traverses a graph in either breadth first or depth first order depending on the buffer it uses to track nodes to traverse next.
private struct GraphNodeIterator<Node: Hashable>: IteratorProtocol {
    enum Traversal {
        case breadthFirst, depthFirst
    }
    var traversal: Traversal
    var graph: DirectedGraph<Node>
    
    private var nodesToTraverse: [Node]
    private var seen: Set<Node>
    
    init(from startingPoint: Node, traversal: Traversal, in graph: DirectedGraph<Node>) {
        self.traversal = traversal
        self.graph = graph
        self.nodesToTraverse = [startingPoint]
        self.seen = []
    }
    
    private mutating func pop() -> Node? {
        guard !nodesToTraverse.isEmpty else { return nil }
        
        switch traversal {
        case .breadthFirst:
            return nodesToTraverse.removeFirst()
        case .depthFirst:
            return nodesToTraverse.removeLast()
        }
    }
    
    mutating func next() -> Node? {
        while let node = pop() {
            guard !seen.contains(node) else { continue }
            seen.insert(node)
            
            nodesToTraverse.append(contentsOf: graph.neighbors(of: node))
            
            return node
        }
        return nil
    }
}

// MARK: Path iterator

/// An iterator that traverses a graph in breadth first order and returns information about the accumulated path through the graph, up to the current node.
private struct GraphBreadthFirstPathIterator<Node: Hashable>: IteratorProtocol {
    var pathsToTraverse: [(Node, [Node])]
    var graph: DirectedGraph<Node>
    
    init(from startingPoint: Node, in graph: DirectedGraph<Node>) {
        self.pathsToTraverse = [(startingPoint, [])]
        self.graph = graph
    }
    
    mutating func next() -> DirectedGraph<Node>.PathIterationElement? {
        guard !pathsToTraverse.isEmpty else { return nil }
        let (node, path) = pathsToTraverse.removeFirst()
        
        if let cycleStartIndex = path.lastIndex(of: node) {
            return (path, false, cycleStartIndex)
        }
        
        let newPath = path + [node]
        let neighbors = graph.neighbors(of: node)
        pathsToTraverse.append(contentsOf: neighbors.map { ($0, newPath) })
        
        return (newPath, neighbors.isEmpty, nil)
    }
}
