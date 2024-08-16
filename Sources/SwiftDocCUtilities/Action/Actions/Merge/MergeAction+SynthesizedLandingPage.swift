/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

extension MergeAction {
    struct RootRenderReferences {
        var documentation, tutorials: [TopicRenderReference]
        
        fileprivate var all: [TopicRenderReference] {
            documentation + tutorials
        }
        var isEmpty: Bool {
            documentation.isEmpty && tutorials.isEmpty
        }
        fileprivate var containsBothKinds: Bool {
            !documentation.isEmpty && !tutorials.isEmpty
        }
    }
    
    func readRootNodeRenderReferencesIn(dataDirectory: URL) throws -> RootRenderReferences {
        func inner(url: URL) throws -> [TopicRenderReference] {
            try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
                .compactMap {
                    guard $0.pathExtension == "json" else {
                        return nil
                    }
                    
                    let data = try fileManager.contents(of: $0)
                    return try JSONDecoder().decode(RootNodeRenderReference.self, from: data)
                        .renderReference
                }
                .sorted(by: { lhs, rhs in
                    lhs.title < rhs.title
                })
        }
        
        return .init(
            documentation: try inner(url: dataDirectory.appendingPathComponent("documentation", isDirectory: true)),
            tutorials:     try inner(url: dataDirectory.appendingPathComponent("tutorials", isDirectory: true))
        )
    }
    
    func makeSynthesizedLandingPage(
        name: String,
        reference: ResolvedTopicReference,
        roleHeading: String,
        rootRenderReferences: RootRenderReferences
    ) -> RenderNode {
        var renderNode = RenderNode(identifier: reference, kind: .article)
        
        renderNode.topicSectionsStyle = .detailedGrid
        renderNode.metadata.title = name
        renderNode.metadata.roleHeading = roleHeading
        renderNode.metadata.role = "collection"
        renderNode.hierarchy = nil
        renderNode.sections = []
        
        if rootRenderReferences.containsBothKinds {
            // If the combined archive contains both documentation and tutorial content, create separate topic sections for each.
            renderNode.topicSections = [
                .init(title: "Modules", abstract: nil, discussion: nil, identifiers: rootRenderReferences.documentation.map(\.identifier.identifier)),
                .init(title: "Tutorials", abstract: nil, discussion: nil, identifiers: rootRenderReferences.tutorials.map(\.identifier.identifier)),
            ]
        } else {
            // Otherwise, create a single unnamed topic section
            renderNode.topicSections = [
                .init(title: nil, abstract: nil, discussion: nil, identifiers: (rootRenderReferences.all).map(\.identifier.identifier)),
            ]
        }
        
        for renderReference in rootRenderReferences.documentation {
            renderNode.references[renderReference.identifier.identifier] = renderReference
        }
        for renderReference in rootRenderReferences.tutorials {
            renderNode.references[renderReference.identifier.identifier] = renderReference
        }
        
        return renderNode
    }
}

/// A type that decodes the root node reference from a root node's encoded render node data.
private struct RootNodeRenderReference: Decodable {
    /// The decoded root node render reference
    var renderReference: TopicRenderReference
    
    enum CodingKeys: CodingKey {
        // The only render node keys that should be needed
        case identifier, references
        // Extra render node keys in case we need to re-create the render reference from page content.
        case metadata, abstract, kind
    }
    
    struct StringCodingKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        var intValue: Int? = nil
        init?(intValue: Int) {
            fatalError("`SparseRenderNode.StringCodingKey` only support string values")
        }
    }
    
    init(from decoder: any Decoder) throws {
        // Instead of decoding the full render node, we only decode the information that's needed.
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let identifier = try container.decode(ResolvedTopicReference.self, forKey: .identifier)
        let rawIdentifier = identifier.url.absoluteString
        let referencesContainer = try container.nestedContainer(keyedBy: StringCodingKey.self, forKey: .references)
        
        // Every node should include a reference to the root page.
        // For reference documentation, this is because the root appears as a link in the breadcrumbs on every page.
        // For tutorials, this is because the tutorial table of content appears as a link in the top navigator.
        //
        // If the root page has a reference to itself, then that the fastest and easiest way to access the correct topic render reference.
        if let selfReference = try referencesContainer.decodeIfPresent(TopicRenderReference.self, forKey: .init(stringValue: rawIdentifier)!) {
            renderReference = selfReference
            return
        }
        
        // If for some unexpected reason this wasn't true, for example because of an unknown page kind,
        // we can create a new topic reference by decoding a little bit more information from the render node.
        let metadata = try container.decode(RenderMetadata.self, forKey: .metadata)
        
        renderReference = TopicRenderReference(
            identifier: RenderReferenceIdentifier(rawIdentifier),
            title: metadata.title ?? identifier.lastPathComponent,
            abstract: try container.decodeIfPresent([RenderInlineContent].self, forKey: .abstract) ?? [],
            url: identifier.path.lowercased(),
            kind: try container.decode(RenderNode.Kind.self, forKey: .kind),
            images: metadata.images
        )
    }
}
