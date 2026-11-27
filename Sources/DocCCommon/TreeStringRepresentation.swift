/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A namespace for internal debug or test functionality to print the visual string representation of some tree structure.
package enum TreeStringRepresentation {
    /// A node in the tree structure
    package struct Node {
        /// The name that's displayed for this node in the tree's string representation
        ///
        /// - Tip: You can include any type of human-readable metadata that you want in the name.
        package var name: String
        /// The descendants of this node in the tree structure.
        package var children: [Node]
        
        /// Creates a new node with the given name and children.
        package init(name: String, children: [Node]) {
            self.name = name
            self.children = children
        }
    }
    
    /// Traverses the tree structure of this node and its descendants and returns a visual string representation of hierarchy that structure.
    ///
    /// ## Example
    /// ```swift
    /// Node(name: "Outer", children: [
    ///     Node(name: "Inner", children: [
    ///         Node(name: "Leaf One", children: []),
    ///         Node(name: "Leaf Two", children: []),
    ///     ])
    /// ])
    /// ```
    /// The string `dump()` of the tree hierarchy above is shown below:
    /// ```
    /// Outer
    /// ╰╴Inner
    ///   ├╴Leaf One
    ///   ╰╴Leaf Two
    /// ```
    package static func dump(_ node: Node) -> String {
        String(Self.dump(node, decorator: "").dropLast()) // remove the trailing newline
    }
    
    private static func dump(_ node: Node, decorator: String) -> String {
        var result = ""
        result.append(decorator)
        if !decorator.isEmpty {
            result.append("╴")
        }
        result.append(node.name + "\n")

        for (index, child) in node.children.enumerated() {
            var decorator = decorator
            if decorator.hasSuffix("├") {
                decorator = decorator.dropLast() + "│ "
            }
            if decorator.hasSuffix("╰") {
                decorator = decorator.dropLast() + "  "
            }
            let newDecorator = decorator + (index == node.children.count-1 ? "╰" : "├")
            result.append(dump(child, decorator: newDecorator))
        }
        return result
    }
}
