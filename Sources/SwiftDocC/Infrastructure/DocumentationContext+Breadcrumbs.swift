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
        
        /// Prefer a tutorial table-of-contents page as the canonical path over a shorter path.
        static let preferTutorialTableOfContentsRoot = PathOptions(rawValue: 1 << 0)
    }
    
    /// Finds all finite (acyclic) paths, also called "breadcrumbs", to the given reference in the topic graph.
    ///
    /// Each path is a list of references that describe a walk through the topic graph from a leaf node up to, but not including, the given `reference`.
    ///
    /// The first path is the canonical path to the node. The other paths are sorted by increasing length (number of components).
    ///
    /// > Note:
    /// If all paths from the given reference are infinite (cycle back on themselves) then this function will return an empty list, because there are no _finite_ paths in the topic graph from that reference.
    ///
    /// - Parameters:
    ///   - reference: The reference to find paths to.
    ///   - options: Options for how the context produces node breadcrumbs.
    /// - Returns: A list of finite paths to the given reference in the topic graph.
    func finitePaths(to reference: ResolvedTopicReference, options: PathOptions = []) -> [[ResolvedTopicReference]] {
        topicGraph.reverseEdgesGraph
            .allFinitePaths(from: reference)
            // Graph traversal typically happens from the starting point outwards, but the callers of `finitePaths(to:options:)`
            // expect paths going inwards from the leaves to the starting point, excluding the starting point itself.
            // To match the caller's expectations we remove the starting point and then flip the paths.
            .map { $0.dropFirst().reversed() }
            .sorted { (lhs, rhs) -> Bool in
                // Order a path rooted in a tutorial table-of-contents as the canonical one.
                if options.contains(.preferTutorialTableOfContentsRoot), let first = lhs.first {
                    return try! entity(with: first).semantic is TutorialTableOfContents
                }
                
                return breadcrumbsAreInIncreasingOrder(lhs, rhs)
            }
    }
    
    /// Finds the shortest finite (acyclic) path, also called "breadcrumb", to the given reference in the topic graph.
    ///
    /// The path is a list of references that describe a walk through the topic graph from a leaf node up to, but not including, the given `reference`.
    ///
    /// > Note:
    /// If all paths from the given reference are infinite (cycle back on themselves) then this function will return `nil`, because there are no _finite_ paths in the topic graph from that reference.
    ///
    /// - Parameter reference: The reference to find the shortest path to.
    /// - Returns: The shortest path to the given reference, or `nil` if all paths to the reference are infinite (contain cycles).
    func shortestFinitePath(to reference: ResolvedTopicReference) -> [ResolvedTopicReference]? {
        topicGraph.reverseEdgesGraph
            .shortestFinitePaths(from: reference)
            // Graph traversal typically happens from the starting point outwards, but the callers of `shortestFinitePaths(to:)`
            // expect paths going inwards from the leaves to the starting point, excluding the starting point itself.
            // To match the caller's expectations we remove the starting point and then flip the paths.
            .map { $0.dropFirst().reversed() }
            .min(by: breadcrumbsAreInIncreasingOrder)
    }
    
    /// Finds all the reachable root node references from the given reference.
    ///
    /// > Note:
    /// If all paths from the given reference are infinite (cycle back on themselves) then this function will return an empty set, because there are no reachable roots in the topic graph from that reference.
    ///
    /// - Parameter reference: The reference to find reachable root node references from.
    /// - Returns: The references of the root nodes that are reachable fro the given reference, or `[]` if all paths from the reference are infinite (contain cycles).
    func reachableRoots(from reference: ResolvedTopicReference) -> Set<ResolvedTopicReference> {
        topicGraph.reverseEdgesGraph.reachableLeafNodes(from: reference)
    }
}

/// Compares two breadcrumbs for sorting so that the breadcrumb with fewer components come first and breadcrumbs with the same number of components are sorted alphabetically.
private func breadcrumbsAreInIncreasingOrder(_ lhs: [ResolvedTopicReference], _ rhs: [ResolvedTopicReference]) -> Bool {
    // If the breadcrumbs have the same number of components, sort alphabetically to produce stable results.
    guard lhs.count != rhs.count else {
        return lhs.map({ $0.path }).joined(separator: ",") < rhs.map({ $0.path }).joined(separator: ",")
    }
    // Otherwise, sort by the number of breadcrumb components.
    return lhs.count < rhs.count
}

