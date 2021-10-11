/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A lean tree of hashable unique value nodes.
///
/// - warning: The tree is not thread safe and it should be used in synchronized context.
struct BidirectionalTree<Node: Hashable> {
    
    enum Error: DescribedError {
        case nodeNotFound(Node, String)
        case nodeAlreadyExists(Node, String)
        var errorDescription: String {
            switch self {
            case .nodeNotFound(let node, let message): return "Node not found: \(String(describing: node).singleQuoted). \(message)"
            case .nodeAlreadyExists(let node, let message): return "Node already exists: \(String(describing: node).singleQuoted). \(message)"
            }
        }
    }

    /// Root node.
    private(set) var root: Node
    /// Children edges.
    private var children = [Node: [Node]]()
    /// Parent edges.
    private var parents = [Node: Node]()
    
    /// Initializes the tree with a root node.
    init(root: Node) {
        self.root = root
    }
    
    /// Adds a node to the tree under a given parent node.
    /// - throws: Throws when:
    ///    - `node` is already in the tree
    ///    - `parent` is not found in the tree
    mutating func add(_ node: Node, parent: Node) throws {
        guard parents[parent] != nil || parent == root else {
            throw Error.nodeNotFound(node, "Trying to add \(String(describing: node).singleQuoted) under \(String(describing: parent))")
        }
        guard parents[node] == nil && node != root else {
            throw Error.nodeAlreadyExists(node, "Trying to add \(String(describing: node).singleQuoted) under \(String(describing: parent))")
        }
        
        parents[node] = parent
        children[parent, default: []].append(node)
    }

    /// Replaces an existing node with a new node
    /// while preserving all parent/child relationships
    /// - throws: Throws when:
    ///    - `node` is not found in the tree
    ///    - `newNode` is already in the tree
    mutating func replace(_ node: Node, with newNode: Node) throws {
        guard parents[node] != nil || node == root else {
            throw Error.nodeNotFound(node, "Trying to replace \(String(describing: node).singleQuoted) with \(String(describing: newNode))")
        }
        guard parents[newNode] == nil && newNode != root else {
            throw Error.nodeAlreadyExists(node, "Trying to replace \(String(describing: node).singleQuoted) with \(String(describing: newNode))")
        }

        // Required by the precondition
        let parent = parents[node] ?? root
        
        // Update `node` parent's children, known to exist
        children[parent]!.firstIndex(of: node).map({
            _ = children[parent]!.remove(at: $0)
        })
        children[parent]!.append(newNode)
        
        // Update `node`'s parent
        parents.removeValue(forKey: node)
        parents[newNode] = parent
        
        if let children = self.children[node] {
            // Update `node`'s children
            self.children.removeValue(forKey: node)
            self.children[newNode] = children
            
            // Update `node`'s children's parent
            for child in children {
                parents[child] = newNode
            }
        }
    }
    
    /// Returns the children for a given node, if there are no children returns an empty array.
    /// - throws: Throws when:
    ///    - `node` is not found in the tree
    func children(of node: Node) throws -> [Node] {
        guard parents[node] != nil || node == root else {
            throw Error.nodeNotFound(node, "Trying to get children of \(String(describing: node).singleQuoted)")
        }
        return children[node] ?? []
    }
    
    /// Returns the parent for a given node, if `node` is the root node returns `nil`
    /// - throws: Throws when:
    ///    - `node` is not found in the tree
    func parent(of node: Node) throws -> Node? {
        guard node != root else { return nil }
        guard let parent = parents[node] else {
            throw Error.nodeNotFound(node, "Trying to get parent of \(String(describing: node).singleQuoted)")
        }
        return parent
    }
    
    /// Traverses pre-order starting at the given `node`, invokes `observe` for each node in turn.
    ///
    /// For example for this tree:
    /// ```
    ///         [1]
    ///    [2]       [5]
    /// [3]   [4]        [6]
    /// ```
    /// the order of nodes to pass to `observe` will be:
    /// 1, 2, 3, 4, 5, 6.
    /// - throws: Throws when:
    ///    - `node` is not found in the tree
    func traversePreOrder(from node: Node? = nil, _ observe: (Node) throws -> Void) throws {
        guard node == nil || parents[node!] != nil else {
            throw Error.nodeNotFound(node!, "Trying to start traversing at \(String(describing: node).singleQuoted)")
        }

        try observe(node ?? root)
        
        guard let children = children[node ?? root] else { return }
        for child in children {
            try traversePreOrder(from: child, observe)
        }
    }
    
    /// Reserves enough space to store the specified number of nodes.
    mutating func reserveCapacity(_ count: Int) {
        parents.reserveCapacity(count)
        children.reserveCapacity(count)
    }
}

extension BidirectionalTree {
    /// Returns a visual dump of the tree for debugging purposes.
    func dump(_ node: Node? = nil, decorator: String = "") throws -> String {
        let node = node ?? root
        var result = ""
        result.append("\(decorator) \(String(describing: node))\r\n")
        
        let children = try self.children(of: node)
        for (index, child) in children.enumerated() {
            var decorator = decorator
            if decorator.hasSuffix("├") {
                decorator = decorator.dropLast() + "│"
            }
            if decorator.hasSuffix("╰") {
                decorator = decorator.dropLast() + " "
            }
            let newDecorator = decorator + " " + (index == children.count-1 ? "╰" : "├")
            result.append(try dump(child, decorator: newDecorator))
        }

        return result
    }
}
