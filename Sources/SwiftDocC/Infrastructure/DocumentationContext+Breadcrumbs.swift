/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension DocumentationContext {
    /// Options that configure how the context produces node breadcrumbs.
    struct PathOptions: OptionSet {
        let rawValue: Int
        
        /// Prefer a technology as the canonical path over a shorter path.
        static let preferTechnologyRoot = PathOptions(rawValue: 1 << 0)
    }
    
    /// Finds all finite paths (breadcrumbs) to the given reference.
    ///
    /// Each path is a list of references for the nodes traversed while walking the topic graph from a root node to, but not including, the given `reference`.
    ///
    /// The first path is the canonical path to the node. The other paths are sorted by increasing length (number of components).
    ///
    /// - Parameters:
    ///   - reference: The reference to find paths to.
    ///   - options: Options for how the context produces node breadcrumbs.
    /// - Returns: A list of finite paths to the given reference in the topic graph.
    func finitePaths(to reference: ResolvedTopicReference, options: PathOptions = []) -> [[ResolvedTopicReference]] {
        reverseEdgesGraph
            .allFinitePaths(from: reference)
            .map { $0.dropFirst().reversed() }
            .sorted { (lhs, rhs) -> Bool in
                // Order a path rooted in a technology as the canonical one.
                if options.contains(.preferTechnologyRoot), let first = lhs.first {
                    return try! entity(with: first).semantic is Technology
                }
                
                return breadcrumbsAreInIncreasingOrder(lhs, rhs)
            }
    }
    
    /// Finds the shortest finite path (breadcrumb) to the given reference.
    ///
    /// - Parameter reference: The reference to find the shortest path to.
    /// - Returns: The shortest path to the given reference, or `nil` if all paths to the reference are infinite (contain cycles).
    func shortestFinitePath(to reference: ResolvedTopicReference) -> [ResolvedTopicReference]? {
        reverseEdgesGraph
            .shortestFinitePaths(from: reference)
            .map { $0.dropFirst().reversed() }
            .min(by: breadcrumbsAreInIncreasingOrder)
    }
    
    /// Finds all the reachable root node references from the given reference.
    ///
    /// > Note:
    /// If all paths from the given reference are infinite (contain cycles) then it can't reach any roots and will return an empty set.
    ///
    /// - Parameter reference: The reference to find reachable root node references from.
    /// - Returns: The references of the root nodes that are reachable fro the given reference, or `[]` if all paths from the reference are infinite (contain cycles).
    func reachableRoots(from reference: ResolvedTopicReference) -> Set<ResolvedTopicReference> {
        reverseEdgesGraph.reachableLeafNodes(from: reference)
    }
    
    /// The directed graph of reverse edges in the topic graph.
    private var reverseEdgesGraph: DirectedGraph<ResolvedTopicReference> {
        DirectedGraph(neighbors: topicGraph.reverseEdges)
    }
}

/// Compares two breadcrumbs for sorting so that the breadcrumb with fewer components come first and breadcrumbs with the same number of components are sorter alphabetically.
private func breadcrumbsAreInIncreasingOrder(_ lhs: [ResolvedTopicReference], _ rhs: [ResolvedTopicReference]) -> Bool {
    // If the breadcrumbs have the same number of components, sort alphabetically to produce stable results.
    guard lhs.count != rhs.count else {
        return lhs.map({ $0.path }).joined(separator: ",") < rhs.map({ $0.path }).joined(separator: ",")
    }
    // Otherwise, sort by the number of breadcrumb components.
    return lhs.count < rhs.count
}

