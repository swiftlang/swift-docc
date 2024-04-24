/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension DocumentationContext {
    /// Options to consider when producing node breadcrumbs.
    struct PathOptions: OptionSet {
        let rawValue: Int
        
        /// Prefer a technology as the canonical path over a shorter path.
        static let preferTechnologyRoot = PathOptions(rawValue: 1 << 0)
    }
    
    /// Finds all finite paths (breadcrumbs) to the given node reference.
    ///
    /// Each path is a list of references for the nodes traversed while walking the topic graph from a root node to, but not including, the given `reference`.
    ///
    /// The first path is the canonical path to the node. The other paths are sorted by increasing length (number of components).
    ///
    /// - Parameters:
    ///   - reference: The reference to build that paths to.
    ///   - options: Options to consider when producing node breadcrumbs.
    /// - Returns: A list of finite paths to the given reference in the topic graph.
    func pathsTo(_ reference: ResolvedTopicReference, options: PathOptions = []) -> [[ResolvedTopicReference]] {
        return DirectedGraph(neighbors: topicGraph.reverseEdges)
            .allFinitePaths(from: reference)
            .map { $0.dropFirst().reversed() }
            .sorted { (lhs, rhs) -> Bool in
                // Order a path rooted in a technology as the canonical one.
                if options.contains(.preferTechnologyRoot), let first = lhs.first {
                    return try! entity(with: first).semantic is Technology
                }
                
                // If the breadcrumbs have equal amount of components
                // sort alphabetically to produce stable paths order.
                guard lhs.count != rhs.count else {
                    return lhs.map({ $0.path }).joined(separator: ",") < rhs.map({ $0.path }).joined(separator: ",")
                }
                // Order by the length of the breadcrumb.
                return lhs.count < rhs.count
            }
    }
}
