/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
@_spi(MarkdownOutput) import SwiftDocCMarkdownOutput

/// Creates ``CollectedMarkdownOutput`` from a ``DocumentationNode``.
internal struct MarkdownOutputNodeTranslator {
    
    var visitor: MarkdownOutputSemanticVisitor
    
    init(context: DocumentationContext, bundle: DocumentationBundle, node: DocumentationNode) {
        self.visitor = MarkdownOutputSemanticVisitor(context: context, bundle: bundle, node: node)
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
        get throws {
            WritableMarkdownOutputNode(identifier: identifier, nodeData: try node.data)
        }
    }
}

@_spi(MarkdownOutput)
public struct WritableMarkdownOutputNode {
    public let identifier: ResolvedTopicReference
    public let nodeData: Data
}

extension MarkdownOutputManifest {
    var writable: WritableMarkdownOutputManifest {
        get throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            #if DEBUG
            encoder.outputFormatting.insert(.prettyPrinted)
            #endif
            let data = try encoder.encode(self)
            return WritableMarkdownOutputManifest(title: title, manifestData: data)
        }
    }
}

@_spi(MarkdownOutput)
public struct WritableMarkdownOutputManifest {
    public let title: String
    public let manifestData: Data
}
