/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/**
 A directed graph of topics.
 
 Nodes represent a pointer to a `DocumentationNode`, the source of its contents, and a short title.
 
 > Important:
 > The topic graph has no awareness of source language specific edges.
 >
 > If an edge exist between two nodes and those nodes have representations in a given source language it *doesn't* mean that that edge exist in that language.
 > If you need information about source language specific edged between nodes, you need to query another source of information.
 */
struct TopicGraph {
    /// A node in the graph.
    class Node: Hashable, CustomDebugStringConvertible {
        /// The location of the node's contents.
        enum ContentLocation: Hashable {

            // TODO: make this take multiple URLs?
            /// The node exists as a whole file at some URL.
            case file(url: URL)
            
            /// The node exists as a subrange in a file at some URL, such as a documentation comment in source code.
            case range(SourceRange, url: URL)
            
            /// The node exist externally and doesn't have a local source.
            case external
            
            static func == (lhs: ContentLocation, rhs: ContentLocation) -> Bool {
                switch (lhs, rhs) {
                case (.file(let lhsURL), .file(let rhsURL)):
                    return lhsURL == rhsURL
                case (.range(let lhsRange, let lhsURL), .range(let rhsRange, let rhsURL)):
                    return lhsRange == rhsRange && lhsURL == rhsURL
                case (.external, .external):
                    return true
                default:
                    return false
                }
            }
            
            func hash(into hasher: inout Hasher) {
                switch self {
                case .file(let url):
                    hasher.combine(1)
                    hasher.combine(url)
                case .range(let range, let url):
                    hasher.combine(2)
                    hasher.combine(range)
                    hasher.combine(url)
                case .external:
                    hasher.combine(3)
                }
            }
        }
        
        /// The reference to the `DocumentationNode` this node represents.
        let reference: ResolvedTopicReference
        
        /// The kind of node.
        let kind: DocumentationNode.Kind
        
        /// The source of the node.
        let source: ContentLocation
        
        /// A short display title of the node.
        let title: String
        
        /// If true, the hierarchy path is resolvable.
        let isResolvable: Bool
        
        /// If true, the topic should not be rendered and exists solely to mark relationships.
        let isVirtual: Bool

        /// If true, the topic has been removed from the hierarchy due to being an extension whose children have been curated elsewhere.
        let isEmptyExtension: Bool
        
        /// If true, the topic should automatically organize into a topic section in its canonical container page's hierarchy for each language representation.
        var shouldAutoCurateInCanonicalLocation: Bool = true

        init(reference: ResolvedTopicReference, kind: DocumentationNode.Kind, source: ContentLocation, title: String, isResolvable: Bool = true, isVirtual: Bool = false, isEmptyExtension: Bool = false, shouldAutoCurateInCanonicalLocation: Bool = true) {
            self.reference = reference
            self.kind = kind
            self.source = source
            self.title = title
            self.isResolvable = isResolvable
            self.isVirtual = isVirtual
            self.isEmptyExtension = isEmptyExtension
            self.shouldAutoCurateInCanonicalLocation = shouldAutoCurateInCanonicalLocation
        }
        
        func withReference(_ reference: ResolvedTopicReference) -> Node {
            Node(
                reference: reference,
                kind: kind,
                source: source,
                title: title
            )
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(reference)
        }
        
        var debugDescription: String {
            return "TopicGraph.Node(reference: \(reference), kind: \(kind), source: \(source), title: \(title)"
        }
        
        static func == (lhs: Node, rhs: Node) -> Bool {
            return lhs.reference == rhs.reference
        }
    }
        
    /// The nodes in the graph.
    var nodes: [ResolvedTopicReference: Node]
    
    /// The edges in the graph.
    var edges: [ResolvedTopicReference: [ResolvedTopicReference]]
    /// A reversed lookup of the graph's edges.
    var reverseEdges: [ResolvedTopicReference: [ResolvedTopicReference]]
    
    /// Create an empty topic graph.
    init() {
        edges = [:]
        nodes = [:]
        reverseEdges = [:]
    }
    
    /// Adds a node to the graph.
    mutating func addNode(_ node: Node) {
        guard nodes[node.reference] == nil else {
            return
        }
        nodes[node.reference] = node
    }
    
    /// Replaces one node with another in the graph, and preserves the edges.
    mutating func replaceNode(_ node: Node, with newNode: Node) {
        let parentEdges = reverseEdges[node.reference]
        let parentReference = parentEdges?.first
        
        // 1. Remove the node edges
        let childrenEdges = edges[node.reference]
        removeEdges(from: node)
        edges.removeValue(forKey: node.reference)
        
        // 2. Remove reverse edges
        if let parentReference {
            edges[parentReference]!.removeAll(where: { ref -> Bool in
                return ref == node.reference
            })
        }
        
        // 3. Remove the node
        nodes.removeValue(forKey: node.reference)
        
        // Now we do the reverse actions for the new node
        
        // 3. Add the new node
        addNode(newNode)
        
        // 2. Add the reverse edges
        if let edges = childrenEdges {
            for edge in edges.compactMap({ nodes[$0] }) {
                addEdge(from: newNode, to: edge)
            }
        }

        // 1. Add the new edges
        if let parentReference, let parentNode = nodeWithReference(parentReference) {
            addEdge(from: parentNode, to: newNode)
        }
    }
    
    /// Updates the node with the given reference with a new reference.
    mutating func updateReference(_ reference: ResolvedTopicReference, newReference: ResolvedTopicReference) {
        nodes[reference] = nodes[reference]?.withReference(newReference)
    }
    
    /// Adds a topic edge but it doesn't verify if the nodes exist for the given references.
    /// > Warning: If the references don't match already existing nodes this operation might corrupt the topic graph.
    /// - Parameters:
    ///   - source: A source for the new edge.
    ///   - target: A target for the new edge.
    mutating func unsafelyAddEdge(source: ResolvedTopicReference, target: ResolvedTopicReference) {
        precondition(source != target, "Attempting to add edge between two equal nodes. \nsource: \(source)\ntarget: \(target)\n")
        
        // Do not add the edge if it exists already.
        guard edges[source]?.contains(target) != true else {
            return
        }
        
        edges[source, default: []].append(target)
        reverseEdges[target, default: []].append(source)
    }
    
    /**
     Adds a directed edge from a source node to a target node.
     - Note: Implicitly adds the `source` and `target` nodes to the graph, if they haven't been added yet.
     - Warning: A precondition is `source != target`.
     */
    mutating func addEdge(from source: Node, to target: Node) {
        precondition(source != target, "Attempting to add edge between two equal nodes. \nsource: \(source)\ntarget: \(target)\n")
        addNode(source)
        addNode(target)
        
        unsafelyAddEdge(source: source.reference, target: target.reference)
    }
    
    /// Removes the edges for a given node.
    ///
    /// For example, when a symbol's children are curated we need to remove
    /// the symbol-graph vended children.
    mutating func removeEdges(from source: Node) {
        guard edges.keys.contains(source.reference) else {
            return
        }
        for target in edges[source.reference, default: []] {
            reverseEdges[target]!.removeAll(where: { $0 == source.reference })
        }
        
        edges[source.reference] = []
    }

    mutating func removeEdges(to target: Node) {
        guard reverseEdges.keys.contains(target.reference) else {
            return
        }

        for source in reverseEdges[target.reference, default: []] {
            edges[source]!.removeAll(where: { $0 == target.reference })
        }

        reverseEdges[target.reference] = []
    }

    /// Removes the edge from one reference to another.
    /// - Parameters:
    ///   - source: The parent reference in the edge.
    ///   - target: The child reference in the edge.
    mutating func removeEdge(fromReference source: ResolvedTopicReference, toReference target: ResolvedTopicReference) {
        guard var nodeEdges = edges[source],
            let index = nodeEdges.firstIndex(of: target) else {
            return
        }
        
        reverseEdges[target]?.removeAll(where: { $0 == source })
        
        nodeEdges.remove(at: index)
        edges[source] = nodeEdges
    }

    /// Returns a ``Node`` in the graph with the given `reference` if it exists.
    func nodeWithReference(_ reference: ResolvedTopicReference) -> Node? {
        return nodes[reference]
    }
    
    /// Returns the targets of the given ``Node``.
    subscript(node: Node) -> [ResolvedTopicReference] {
        return edges[node.reference] ?? []
    }
    
    /// Returns a sequence that traverses the topic graph in depth first order from a given reference, without visiting the same node more than once.
    func depthFirstSearch(from reference: ResolvedTopicReference) -> some Sequence<Node> {
        edgesGraph
            .depthFirstSearch(from: reference)
            .lazy
            .map { nodeWithReference($0)! }
    }
    
    /// Returns a sequence that traverses the topic graph in breadth first order from a given reference, without visiting the same node more than once.
    func breadthFirstSearch(from reference: ResolvedTopicReference) -> some Sequence<Node> {
        edgesGraph
            .breadthFirstSearch(from: reference)
            .lazy
            .map { nodeWithReference($0)! }
    }
    
    /// A directed graph of the edges in the topic graph.
    var edgesGraph: DirectedGraph<ResolvedTopicReference> {
        DirectedGraph(edges: edges)
    }
    
    /// A directed graph of the reverse edges in the topic graph.
    var reverseEdgesGraph: DirectedGraph<ResolvedTopicReference> {
        DirectedGraph(edges: reverseEdges)
    }

    /// Returns true if a node exists with the given reference and it's set as linkable.
    func isLinkable(_ reference: ResolvedTopicReference) -> Bool {
        // Sections (represented by the node path + fragment with the section name)
        // don't have nodes in the topic graph so we verify that
        // the path without the fragment is resolvable.
        return nodeWithReference(reference.withFragment(nil))?.isResolvable == true
    }
    
    /// Generates a hierarchical dump of the topic graph, starting at the given node.
    ///
    /// To print the graph using the absolute URL of each node use:
    /// ```swift
    /// print(topicGraph.dump(startingAt: moduleNode, keyPath: \.reference.absoluteString))
    /// ```
    /// This will produce output along the lines of:
    /// ```
    /// doc://com.testbundle/documentation/MyFramework
    /// ├ doc://com.testbundle/documentation/MyFramework/MyProtocol
    /// │ ╰ doc://com.testbundle/documentation/MyFramework/MyClass
    /// │   ├ doc://com.testbundle/documentation/MyFramework/MyClass/myfunction()
    /// │   ╰ doc://com.testbundle/documentation/MyFramework/MyClass/init()
    /// ...
    /// ```
    ///
    /// - Precondition: All paths through the topic graph from the starting node are finite (acyclic).
    func dump(startingAt node: Node, keyPath: KeyPath<TopicGraph.Node, String> = \.title, decorator: String = "") -> String {
        if let cycle = edgesGraph.firstCycle(from: node.reference) {
            let cycleDescription = cycle.map(\.absoluteString).joined(separator: " -> ")
            preconditionFailure("Traversing the topic graph from \(node.reference.absoluteString) encounters an infinite cyclic path: \(cycleDescription) -cycle-> \(cycleDescription) ...")
        }
        
        var result = ""
        result.append("\(decorator) \(node[keyPath: keyPath])\n")
        if let childEdges = edges[node.reference]?.sorted(by: { $0.path < $1.path }) {
            for (index, childRef) in childEdges.enumerated() {
                var decorator = decorator
                if decorator.hasSuffix("├") {
                    decorator = decorator.dropLast() + "│"
                }
                if decorator.hasSuffix("╰") {
                    decorator = decorator.dropLast() + " "
                }
                let newDecorator = decorator + " " + (index == childEdges.count-1 ? "╰" : "├")
                if let node = nodeWithReference(childRef) {
                    // We recurse into the child's hierarchy only if it's a legit topic node;
                    // otherwise, when for example this is a symbol curated via external resolving and it's
                    // not found in the current topic graph, we skip it.
                    result.append(dump(startingAt: node, keyPath: keyPath, decorator: newDecorator))
                }
            }
        }
        return result
    }
}
