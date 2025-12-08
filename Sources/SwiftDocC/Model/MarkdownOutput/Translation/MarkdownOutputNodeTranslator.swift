/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Creates ``CollectedMarkdownOutput`` from a ``DocumentationNode``.
internal struct MarkdownOutputNodeTranslator {
    
    var visitor: MarkdownOutputSemanticVisitor
    
    init(context: DocumentationContext, node: DocumentationNode) {
        self.visitor = MarkdownOutputSemanticVisitor(context: context, node: node)
    }
    
    mutating func createOutput() -> CollectedMarkdownOutput? {
        if let node = visitor.start() {
            return CollectedMarkdownOutput(identifier: visitor.identifier, node: node, manifest: visitor.manifest)
        }
        return nil
    }
}

struct CollectedMarkdownOutput {
    let identifier: ResolvedTopicReference
    let node: MarkdownOutputNode
    let manifest: MarkdownOutputManifest?
    
    var writable: WritableMarkdownOutputNode {
        WritableMarkdownOutputNode(identifier: identifier, node: node)
    }
}

package struct WritableMarkdownOutputNode {
    package let identifier: ResolvedTopicReference
    package let node: MarkdownOutputNode
}
