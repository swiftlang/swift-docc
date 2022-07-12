/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/**
 A directed graph of topics.
 
 Nodes represent a pointer to a `DocumentationNode`, the source of its contents, and a short title.
 */
struct TopicGraph {
    /// A decision about whether to continue a depth-first or breadth-first traversal after visiting a node.
    enum Traversal {
        /// Stop here, do not visit any more nodes.
        case stop
        
        /// Continue to visit nodes.
        case `continue`
    }
    
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
        
        init(reference: ResolvedTopicReference, kind: DocumentationNode.Kind, source: ContentLocation, title: String, isResolvable: Bool = true, isVirtual: Bool = false) {
            self.reference = reference
            self.kind = kind
            self.source = source
            self.title = title
            self.isResolvable = isResolvable
            self.isVirtual = isVirtual
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
        if let parentReference = parentReference {
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
        if let parentReference = parentReference, let parentNode = nodeWithReference(parentReference) {
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
        
        // Do not add the edge if it exists already.
        guard edges[source.reference]?.contains(target.reference) != true else {
            return
        }
        
        edges[source.reference, default: []].append(target.reference)
        reverseEdges[target.reference, default: []].append(source.reference)
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
    
    /// Traverses the graph depth-first and passes each node to `observe`.
    func traverseDepthFirst(from startingNode: Node, _ observe: (Node) -> Traversal) {
        var seen = Set<Node>()
        var nodesToVisit = [startingNode]
        while !nodesToVisit.isEmpty {
            let node = nodesToVisit.removeLast()
            guard !seen.contains(node) else {
                continue
            }
            let children = self[node].map {
                nodeWithReference($0)!
            }
            nodesToVisit.append(contentsOf: children)
            guard case .continue = observe(node) else {
                break
            }
            seen.insert(node)
        }
    }
    
    /// Traverses the graph breadth-first and passes each node to `observe`.
    func traverseBreadthFirst(from startingNode: Node, _ observe: (Node) -> Traversal) {
        var seen = Set<Node>()
        var nodesToVisit = [startingNode]
        while !nodesToVisit.isEmpty {
            let node = nodesToVisit.removeFirst()
            guard !seen.contains(node) else {
                continue
            }
            let children = self[node].map {
                nodeWithReference($0)!
            }
            nodesToVisit.append(contentsOf: children)
            guard case .continue = observe(node) else {
                break
            }
            seen.insert(node)
        }
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
    func dump(startingAt node: Node, keyPath: KeyPath<TopicGraph.Node, String> = \.title, decorator: String = "") -> String {
        var result = ""
        result.append("\(decorator) \(node[keyPath: keyPath])\r\n")
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
