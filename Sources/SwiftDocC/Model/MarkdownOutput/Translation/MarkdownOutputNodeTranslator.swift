/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Creates a ``MarkdownOutputNode`` from a ``DocumentationNode``.
public struct MarkdownOutputNodeTranslator {
    
    var visitor: MarkdownOutputSemanticVisitor
    
    public init(context: DocumentationContext, bundle: DocumentationBundle, node: DocumentationNode) {
        self.visitor = MarkdownOutputSemanticVisitor(context: context, bundle: bundle, node: node)
    }
    
    public mutating func createOutput() -> WritableMarkdownOutputNode? {
        if let node = visitor.start() {
            return WritableMarkdownOutputNode(identifier: visitor.identifier, node: node)
        }
        return nil
    }
}

public struct WritableMarkdownOutputNode {
    public let identifier: ResolvedTopicReference
    public let node: MarkdownOutputNode
}
