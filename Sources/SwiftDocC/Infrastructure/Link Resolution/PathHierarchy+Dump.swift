/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// This API isn't exposed anywhere and is only used from a debugger.
#if DEBUG

private import SymbolKit
private import DocCCommon

/// A node in a tree structure that can be printed into a visual representation for debugging.
private typealias DumpableNode = TreeStringRepresentation.Node

private extension PathHierarchy.Node {
    /// Maps the path hierarchy subtree into a representation that can be printed into a visual form for debugging.
    func dumpableNode() -> DumpableNode {
        // Each node is printed as 3-layer hierarchy with the child names, their kind disambiguation, and their hash disambiguation.
        
        // One layer for the node itself that displays information about the symbol
        return DumpableNode(
            name: symbol.map(describe(_:)) ?? "[ \(name) ]",
            children: children.sorted(by: \.key).map { (childName, disambiguationTree) -> DumpableNode in
                
                // A second layer that displays the kind disambiguation
                let grouped = [String: [PathHierarchy.DisambiguationContainer.Element]](grouping: disambiguationTree.storage, by: { $0.kind ?? "_" })
                return DumpableNode(
                    name: childName,
                    children: grouped.sorted(by: \.key).map { (kind, kindTree) -> DumpableNode in
                        
                        // A third layer that displays the hash disambiguation
                        DumpableNode(
                            name: kind,
                            children: kindTree.sorted(by: { lhs, rhs in (lhs.hash ?? "_") < (rhs.hash ?? "_") }).map { (element) -> DumpableNode in
                                
                                // Recursively dump the subtree
                                DumpableNode(name: element.hash ?? "_", children: [element.node.dumpableNode()])
                            }
                        )
                    }
                )
            }
        )
    }
}

private func describe(_ symbol: SymbolGraph.Symbol) -> String {
    guard let (parameterTypes, returnValueTypes) = PathHierarchy.functionSignatureTypeNames(for: symbol) else {
        return "{ \(symbol.identifier.precise) }"
    }
    
    return "{ \(symbol.identifier.precise) : (\(parameterTypes.joined(separator: ", "))) -> (\(returnValueTypes.joined(separator: ", "))) }"
}

extension PathHierarchy {
    /// Creates a visual representation or the path hierarchy for debugging.
    func dump() -> String {
        var children = modules.sorted(by: \.name).map { $0.dumpableNode() }
        if articlesContainer.symbol == nil {
            children.append(articlesContainer.dumpableNode()) // The article parent can be the same node as the module
        }
        children.append(contentsOf: [tutorialContainer.dumpableNode(), tutorialOverviewContainer.dumpableNode()])
        
        let root = DumpableNode(name: ".", children: children)
        return TreeStringRepresentation.dump(root)
    }
}

#endif
