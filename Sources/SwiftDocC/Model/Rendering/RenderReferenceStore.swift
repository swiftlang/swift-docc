/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A storage for render reference information.
///
/// This store stores render references which can be looked up during ``RenderNode`` conversion. It's commonly created by a
/// ``RenderContext``, which precomputes render reference information before render node conversion.
///
/// ## See Also
/// - ``RenderContext``
public struct RenderReferenceStore: Codable {
    /// The topics in the store.
    public var topics: [ResolvedTopicReference: TopicContent]
    /// The assets in the store.
    public var assets: [AssetReference: DataAsset]
    
    /// Creates a new render reference store given resolved topics and their reference information.
    public init(
        topics: [ResolvedTopicReference: TopicContent] = [:],
        assets: [AssetReference: DataAsset] = [:]
    ) {
        self.topics = topics
        self.assets = assets
    }
    
    /// Returns render reference information for the given topic.
    public func content(for topic: ResolvedTopicReference) -> TopicContent? {
        topics[topic]
    }
    
    /// Returns asset information for the given asset name.
    public func content(forAssetNamed assetName: String, bundleIdentifier: String) -> DataAsset? {
        assets[AssetReference(assetName: assetName, bundleIdentifier: bundleIdentifier)]
    }
}

public extension RenderReferenceStore {
    /// Pre-rendered pieces of content for a given node.
    struct TopicContent: Codable {
        /// The topic render reference.
        public let renderReference: RenderReference
        /// Render reference dependencies.
        public let renderReferenceDependencies: RenderReferenceDependencies
        /// The canonical path to a node.
        public let canonicalPath: [ResolvedTopicReference]?
        /// A lookup of a topic's task groups.
        public let taskGroups: [DocumentationContentRenderer.ReferenceGroup]?
        /// The original source file of the topic.
        public let source: URL?
        /// Whether the topic is a documentation extension.
        public let isDocumentationExtensionContent: Bool
        
        private enum CodingKeys: CodingKey {
            case renderReference, canonicalPath, taskGroups, source, isDocumentationExtensionContent, renderReferenceDependencies
        }
        
        /// Creates a new content value given a render reference, canonical path, and task group information.
        /// - Parameters:
        ///   - renderReference: The topic render reference.
        ///   - canonicalPath: The canonical path to a node.
        ///   - taskGroups: A lookup of a topic's task groups.
        ///   - source: The original source file location of the topic.
        ///   - isDocumentationExtensionContent: Whether the topic is a documentation extension.
        public init(
            renderReference: RenderReference,
            canonicalPath: [ResolvedTopicReference]?,
            taskGroups: [DocumentationContentRenderer.ReferenceGroup]?,
            source: URL?,
            isDocumentationExtensionContent: Bool,
            renderReferenceDependencies: RenderReferenceDependencies = RenderReferenceDependencies()
        ) {
            self.renderReference = renderReference
            self.canonicalPath = canonicalPath
            self.taskGroups = taskGroups
            self.source = source
            self.isDocumentationExtensionContent = isDocumentationExtensionContent
            self.renderReferenceDependencies = renderReferenceDependencies
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            renderReference = try container.decode(
                CodableRenderReference.self, forKey: .renderReference).reference
            
            canonicalPath = try container.decodeIfPresent(
                [ResolvedTopicReference].self, forKey: .canonicalPath)
            
            taskGroups = try container.decodeIfPresent(
                [DocumentationContentRenderer.ReferenceGroup].self, forKey: .taskGroups)
            
            source = try container.decodeIfPresent(URL.self, forKey: .source)
            
            isDocumentationExtensionContent = try container.decode(Bool.self, forKey: .isDocumentationExtensionContent)
            
            renderReferenceDependencies = try container.decodeIfPresent(RenderReferenceDependencies.self, forKey: .renderReferenceDependencies) ?? RenderReferenceDependencies()
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(CodableRenderReference(renderReference), forKey: .renderReference)
            try container.encodeIfPresent(canonicalPath, forKey: .canonicalPath)
            try container.encodeIfPresent(taskGroups, forKey: .taskGroups)
            try container.encodeIfPresent(source, forKey: .source)
            try container.encode(isDocumentationExtensionContent, forKey: .isDocumentationExtensionContent)
            try container.encode(renderReferenceDependencies, forKey: .renderReferenceDependencies)
        }
    }
}
