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

// MARK: Iterator

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
