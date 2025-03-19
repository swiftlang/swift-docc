/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

extension MergeAction {
    struct RootRenderReferences {
        struct Information {
            var reference: TopicRenderReference
            var dependencies: RenderReferenceDependencies
            
            var rawIdentifier: String {
                reference.identifier.identifier
            }
        }
        var documentation, tutorials: [Information]
        
        fileprivate var all: [Information] {
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
        func inner(url: URL) throws -> [RootRenderReferences.Information] {
            try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
                .compactMap {
                    guard $0.pathExtension == "json" else {
                        return nil
                    }
                    
                    let data = try fileManager.contents(of: $0)
                    let decoded = try JSONDecoder().decode(RootNodeRenderReference.self, from: data)
                    
                    return .init(reference: decoded.renderReference, dependencies: decoded.renderDependencies)
                }
                .sorted(by: { lhs, rhs in
                    lhs.reference.title < rhs.reference.title
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
        topicsStyle: TopicsVisualStyle.Style,
        rootRenderReferences: RootRenderReferences
    ) -> RenderNode {
        var renderNode = RenderNode(identifier: reference, kind: .article)
        
        renderNode.topicSectionsStyle = switch topicsStyle {
            case .list:         .list
            case .compactGrid:  .compactGrid
            case .detailedGrid: .detailedGrid
            case .hidden:       .hidden
        }
        renderNode.metadata.title = name
        renderNode.metadata.roleHeading = roleHeading
        renderNode.metadata.role = "collection"
        renderNode.sections = []
        
        if rootRenderReferences.containsBothKinds {
            // If the combined archive contains both documentation and tutorial content, create separate topic sections for each.
            renderNode.topicSections = [
                .init(title: "Modules", abstract: nil, discussion: nil, identifiers: rootRenderReferences.documentation.map(\.rawIdentifier)),
                .init(title: "Tutorials", abstract: nil, discussion: nil, identifiers: rootRenderReferences.tutorials.map(\.rawIdentifier)),
            ]
        } else {
            // Otherwise, create a single unnamed topic section
            renderNode.topicSections = [
                .init(title: nil, abstract: nil, discussion: nil, identifiers: (rootRenderReferences.all).map(\.rawIdentifier)),
            ]
        }
        
        for renderReference in rootRenderReferences.documentation {
            renderNode.references[renderReference.rawIdentifier] = renderReference.reference
            
            for imageReference in renderReference.dependencies.imageReferences {
                renderNode.references[imageReference.identifier.identifier] = imageReference
            }
        }
        for renderReference in rootRenderReferences.tutorials {
            renderNode.references[renderReference.rawIdentifier] = renderReference.reference
            // Tutorial pages don't have page images.
        }
        
        return renderNode
    }
}

/// A type that decodes the root node reference from a root node's encoded render node data.
private struct RootNodeRenderReference: Decodable {
    /// The decoded root node render reference
    var renderReference: TopicRenderReference
    var renderDependencies: RenderReferenceDependencies
    
    enum CodingKeys: CodingKey {
        // The only render node keys that should be needed
        case identifier, references
        // Extra render node keys in case we need to re-create the render reference from page content.
        case metadata, abstract, kind
    }
    
    struct StringCodingKey: CodingKey {
        var stringValue: String
        init(stringValue: String) {
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
        
        // Every node should include a reference to the root page.
        // For reference documentation, this is because the root appears as a link in the breadcrumbs on every page.
        // For tutorials, this is because the tutorial table of content appears as a link in the top navigator.
        //
        // If the root page has a reference to itself, then that the fastest and easiest way to access the correct topic render reference.
        if container.contains(.references) {
            let referencesContainer = try container.nestedContainer(keyedBy: StringCodingKey.self, forKey: .references)
            if let selfReference = try referencesContainer.decodeIfPresent(TopicRenderReference.self, forKey: .init(stringValue: rawIdentifier)) {
                renderReference = selfReference
                
                let imageReferences = try Self.decodeImageReferences(container: referencesContainer, images: selfReference.images)
                renderDependencies = RenderReferenceDependencies(
                    topicReferences: [],
                    linkReferences: [],
                    imageReferences: imageReferences
                )
                return
            }
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
        
        let imageReferences: [ImageReference]
        if !metadata.images.isEmpty, container.contains(.references) {
            imageReferences = try Self.decodeImageReferences(
                container: try container.nestedContainer(keyedBy: StringCodingKey.self, forKey: .references),
                images: metadata.images
            )
        } else {
            imageReferences = []
        }
        
        renderDependencies = RenderReferenceDependencies(
            topicReferences: [],
            linkReferences: [],
            imageReferences: imageReferences
        )
    }
    
    private static func decodeImageReferences(container: KeyedDecodingContainer<RootNodeRenderReference.StringCodingKey>, images: [TopicImage]) throws -> [ImageReference] {
        try images.map { image in
            try container.decode(ImageReference.self, forKey: .init(stringValue: image.identifier.identifier))
        }
    }
}
