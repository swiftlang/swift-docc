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
        fileprivate struct Information {
            var reference: TopicRenderReference
            var dependencies: [any RenderReference]
            
            var rawIdentifier: String {
                reference.identifier.identifier
            }
        }
        fileprivate var documentation, tutorials: [Information]
        
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
            // Path might not exist (e.g. tutorials for a reference-only archive)
            guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            else { return [] }
            return try contents
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
            
            for dependencyReference in renderReference.dependencies {
                renderNode.references[dependencyReference.identifier.identifier] = dependencyReference
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
    var renderDependencies: [any RenderReference]
    
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
        let imageReferencePrefix = identifier.bundleID.rawValue + "/"
        
        // Every node should include a reference to the root page.
        // For reference documentation, this is because the root appears as a link in the breadcrumbs on every page.
        // For tutorials, this is because the tutorial table of content appears as a link in the top navigator.
        //
        // If the root page has a reference to itself, then that the fastest and easiest way to access the correct topic render reference.
        if container.contains(.references) {
            let referencesContainer = try container.nestedContainer(keyedBy: StringCodingKey.self, forKey: .references)
            if var selfReference = try referencesContainer.decodeIfPresent(TopicRenderReference.self, forKey: .init(stringValue: rawIdentifier)) {
                renderDependencies = try Self.decodeDependencyReferences(
                    container: referencesContainer,
                    images: selfReference.images,
                    imageReferencePrefix: imageReferencePrefix,
                    abstract: selfReference.abstract
                )
                
                // Image references don't include the bundle ID that they're part of and can collide with other images.
                for index in selfReference.images.indices {
                    selfReference.images[index].identifier.addPrefix(imageReferencePrefix)
                }
               
                renderReference = selfReference
                
                return
            }
        }
        
        // If for some unexpected reason this wasn't true, for example because of an unknown page kind,
        // we can create a new topic reference by decoding a little bit more information from the render node.
        let metadata = try container.decode(RenderMetadata.self, forKey: .metadata)
        
        var prefixedImages = metadata.images
        // Image references don't include the bundle ID that they're part of and can collide with other images.
        for index in prefixedImages.indices {
            prefixedImages[index].identifier.addPrefix(imageReferencePrefix)
        }
        
        renderReference = TopicRenderReference(
            identifier: RenderReferenceIdentifier(rawIdentifier),
            title: metadata.title ?? identifier.lastPathComponent,
            abstract: try container.decodeIfPresent([RenderInlineContent].self, forKey: .abstract) ?? [],
            url: identifier.path.lowercased(),
            kind: try container.decode(RenderNode.Kind.self, forKey: .kind),
            images: prefixedImages
        )
        
        if container.contains(.references) {
            renderDependencies = try Self.decodeDependencyReferences(
                container: try container.nestedContainer(keyedBy: StringCodingKey.self, forKey: .references),
                images: metadata.images,
                imageReferencePrefix: imageReferencePrefix,
                abstract: renderReference.abstract
            )
            
        } else {
            renderDependencies = []
        }
    }
    
    private static func decodeDependencyReferences(
        container: KeyedDecodingContainer<RootNodeRenderReference.StringCodingKey>,
        images: [TopicImage],
        imageReferencePrefix: String,
        abstract: [RenderInlineContent]
    ) throws -> [any RenderReference] {
        var references: [any RenderReference] = []

        for image in images {
            // Image references don't include the bundle ID that they're part of and can collide with other images.
            var imageRef = try container.decode(ImageReference.self, forKey: .init(stringValue: image.identifier.identifier))
            imageRef.identifier.addPrefix(imageReferencePrefix)
            
            references.append(imageRef)
        }
        
        for case .reference(identifier: let identifier, isActive: _, overridingTitle: _, overridingTitleInlineContent: _) in abstract {
            references.append(
                try container.decode(TopicRenderReference.self, forKey: .init(stringValue: identifier.identifier))
            )
        }
        
        return references
    }
}

private extension RenderReferenceIdentifier {
    mutating func addPrefix(_ prefix: String) {
        identifier = prefix + identifier
    }
}
