/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A rendering-friendly representation of a documentation node.
///
/// A render node contains all the data required for a renderer to display a topic's documentation. This includes the topic's
/// authored markup documentation, hierarchy information (the topic's curation), API availability, and more.
///
/// The fields of a render node are populated depending on the documentation page's type. For example, reference
/// documentation pages (i.e., symbols and articles) have their child topics listed in ``topicSections``, but for Tutorial pages,
/// that field is empty.
///
/// Information about external resources such as other documentation pages or media is stored in the ``references`` dictionary.
///
/// An OpenAPI specification for render node is available in the repo at `Sources/SwiftDocC/SwiftDocC.docc/Resources/RenderNode.spec.json`.
///
/// ### Versioning
///
/// The render node schema constantly evolves to support new documentation features. To help clients maintain compatibility,
/// we associate each schema with a version. See ``schemaVersion`` for more details.
///
/// ## Topics
///
/// ### General
///
/// - ``schemaVersion``
/// - ``kind-swift.property``
/// - ``sections``
/// - ``references``
/// - ``hierarchy``
/// - ``metadata``
///
/// ### Reference Documentation Data
///
/// Data specific for reference documentation nodes.
///
/// - ``abstract``
/// - ``primaryContentSections``
/// - ``topicSections``
/// - ``relationshipSections``
/// - ``defaultImplementationsSections``
/// - ``seeAlsoSections``
/// - ``deprecationSummary``
/// - ``variants``
/// - ``diffAvailability``
///
/// ### Sample Code Data
///
/// Data specific for sample code nodes.
///
/// - ``sampleDownload``
///
/// ### Models
///
/// - ``Variant``
public struct RenderNode {
    /// The current version of the render node schema.
    ///
    /// The schema version describes the compatibility of a client with a render node value. Clients should be able to decode
    /// render node values of the same major version, but are not guaranteed to be able to decode values of other major versions.
    /// For example, a client that supports render node `2.5.0` should be able to process any render node of version greater than
    /// or equal to `2.0.0` and less than `3.0.0` _with no regressions_, ignoring new fields in render nodes of version greater
    /// than `2.5.0`.
    ///
    /// The components should be incremented as follows:
    /// - The _major_ component should be incremented when introducing a change that prevents clients from processing
    /// older render node values, for example when creating a new required property.
    /// - The _minor_ component should be incremented when introducing a change that's compatible with older values, for example
    /// when creating a new optional property.
    /// - The _pre-release_ component can be used during development to indicate a new version without incrementing the major or
    /// minor components. When creating a DocC release, the render node version should not have a pre-release
    /// component.
    ///
    /// > Note: The patch value is currently unused and always set to `0`.
    public var schemaVersion = SemanticVersion(
        major: 0,
        minor: 1,
        patch: 0
    )
    
    /// The identifier of the render node.
    ///
    /// The identifier of a render node is typically the same as the documentation node it's representing.
    public var identifier: ResolvedTopicReference
    
    /// The kind of this documentation node.
    public var kind: Kind
        
    /// The values of the references used in documentation node. These can be references to other nodes, media, and more.
    public var references: [String: RenderReference] = [:]
        
    /// Hierarchy information about the context in which this documentation node is placed.
    public var hierarchy: RenderHierarchy?
    
    /// Arbitrary metadata information about the render node.
    public var metadata = RenderMetadata()
    
    // MARK: Reference documentation nodes
    
    /// The abstract of the node, which provides a short overview of its contents.
    public var abstract: [RenderInlineContent]?
    
    /// The main sections of a reference documentation node.
    public var primaryContentSections = [RenderSection]()
    
    /// The Topics sections of this documentation node, which contain links to useful related documentation nodes.
    public var topicSections = [TaskGroupRenderSection]()
    
    /// The Relationships sections of a reference documentation node, which describes how this symbol is related to others.
    public var relationshipSections = [RelationshipsRenderSection]()
    
    /// The Default Implementations sections of symbol node, which list APIs that provide a default implementation of the symbol.
    public var defaultImplementationsSections = [TaskGroupRenderSection]()
        
    /// The See Also sections of a node, which list documentation resources related to this documentation node.
    public var seeAlsoSections = [TaskGroupRenderSection]()
        
    /// A description of why this symbol is deprecated.
    public var deprecationSummary: [RenderBlockContent]?

    /// List of variants of the same documentation node for various languages, etc.
    public var variants: [RenderNode.Variant]?
    
    /// Information about what API diffs are available for this symbol.
    public var diffAvailability: DiffAvailability?
    
    // MARK: Sample code nodes
    
    /// Download information for sample code nodes.
    public var sampleDownload: SampleDownloadSection?
    
    /// Download not available information.
    public var downloadNotAvailableSummary: [RenderBlockContent]?
    
    /// Creates an instance given an identifier and a kind.
    public init(identifier: ResolvedTopicReference, kind: Kind) {
        self.identifier = identifier
        self.kind = kind
    }
    
    // MARK: Tutorials nodes
    
    /// The sections of this node.
    ///
    /// For tutorial pages, this property is the top-level grouping for the page's contents.
    public var sections: [RenderSection] = []
    
    /// The kind of content represented by this node.
    public enum Kind: String, Codable {
        case symbol
        case article
        case tutorial = "project"
        case section
        case overview
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            switch try container.decode(String.self) {
            case "symbol":
                self = .symbol
            case "article":
                self = .article
            case "tutorial", "project":
                self = .tutorial
            case "section":
                self = .section
            case "overview":
                self = .overview
                
            case let unknown:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown RenderNode.Kind: '\(unknown)'.")
            }
        }
    }
}
