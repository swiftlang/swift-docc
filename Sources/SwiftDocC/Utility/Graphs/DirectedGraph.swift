/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A directed, unweighted graph of nodes.
///
/// Use a `DirectedGraph` to operate on data that describe the edges between nodes in a directed graph.
///
/// ## Topics
///
/// ### Search
///
/// - ``breadthFirstSearch(from:)``
/// - ``depthFirstSearch(from:)``
///
/// ### Paths
///
/// - ``shortestFinitePaths(from:)``
/// - ``allFinitePaths(from:)``
/// - ``reachableLeafNodes(from:)``
///
/// ### Cycle detection
///
/// - ``firstCycle(from:)``
/// - ``cycles(from:)``
///
/// ### Low-level path traversal
///
/// - ``accumulatingPaths(from:)``
struct DirectedGraph<Node: Hashable> {
    // There are more generic ways to describe a graph that doesn't require that the elements are Hashable,
    // but all our current usages of graph structures use dictionaries to track the neighboring nodes.
    //
    // This type is internal so we can change it's implementation later when there's new data that's structured differently.
    private let edges: [Node: [Node]]
    init(edges: [Node: [Node]]) {
        self.edges = edges
    }
    
    /// Returns the nodes that are reachable from the given node
    func neighbors(of node: Node) -> [Node] {
        edges[node] ?? []
    }
}
