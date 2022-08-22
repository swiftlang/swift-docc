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
/// ### Variants
///
/// Different variants of a documentation page can be represented by a single render node using the ``variantOverrides`` property.
/// This property holds overrides that clients should apply to the render JSON when processing documentation for specific programming languages. The overrides
/// are organized by traits (e.g., language) and it's up to the client to determine which trait is most appropriate for them. For example, a client that wants to
/// process the Objective-C version of documentation should apply the overrides associated with the `interfaceLanguage: objc` trait.
///
/// Use the ``RenderJSONEncoder/makeEncoder(prettyPrint:emitVariantOverrides:)`` API to instantiate a JSON encoder that's configured
/// to accumulate variant overrides and emit them to the ``variantOverrides`` property.
///
/// The overrides are emitted in the [JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) format.
///
/// To apply variants onto a render node using `SwiftDocC`, use the ``RenderNodeVariantOverridesApplier`` API.
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
/// ### Multi-Language Reference Documentation Data
///
/// Data specific for reference documentation nodes that are available in multiple programming languages.
///
/// - ``abstractVariants``
/// - ``primaryContentSectionsVariants``
/// - ``topicSectionsVariants``
/// - ``relationshipSectionsVariants``
/// - ``defaultImplementationsSectionsVariants``
/// - ``seeAlsoSectionsVariants``
/// - ``deprecationSummaryVariants``
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
public struct RenderNode: VariantContainer {
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
        minor: 3,
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
    
    /// The default value for the abstract of the node, which provides a short overview of its contents.
    public var abstract: [RenderInlineContent]? {
        get { getVariantDefaultValue(keyPath: \.abstractVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.abstractVariants) }
    }
    
    /// The variants of the abstract of the node, which provide a short overview of its contents.
    public var abstractVariants: VariantCollection<[RenderInlineContent]?> = .init(defaultValue: nil)
    
    /// The default value of the main sections of a reference documentation node.
    public var primaryContentSections: [RenderSection] {
        get { primaryContentSectionsVariants.compactMap(\.defaultValue?.section) }
        set {
            primaryContentSectionsVariants = newValue.enumerated().map { index, section in
                let section = CodableContentSection(section)
                
                if primaryContentSectionsVariants.indices.contains(index) {
                    var variantCollection = primaryContentSectionsVariants[index]
                    variantCollection.defaultValue = section
                    return variantCollection
                } else {
                    return VariantCollection<CodableContentSection?>(defaultValue: section)
                }
            }
        }
    }
    
    /// The variants of the primary content sections of the node, which are the main sections of a reference documentation node.
    public var primaryContentSectionsVariants: [VariantCollection<CodableContentSection?>] = []
    
    /// The visual style that should be used when rendering this page's Topics section.
    public var topicSectionsStyle: TopicsSectionStyle
    
    /// The default Topics sections of this documentation node, which contain links to useful related documentation nodes.
    public var topicSections: [TaskGroupRenderSection] {
        get { getVariantDefaultValue(keyPath: \.topicSectionsVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.topicSectionsVariants) }
    }
    
    /// The variants for the Topics sections of this documentation node, which contain links to useful related documentation nodes.
    public var topicSectionsVariants: VariantCollection<[TaskGroupRenderSection]> = .init(defaultValue: [])
    
    /// The default Relationships sections of a reference documentation node, which describes how this symbol is related to others.
    public var relationshipSections: [RelationshipsRenderSection] {
        get { getVariantDefaultValue(keyPath: \.relationshipSectionsVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.relationshipSectionsVariants) }
    }
    
    /// The variants of the Relationships sections of a reference documentation node, which describe how this symbol is related to others.
    public var relationshipSectionsVariants: VariantCollection<[RelationshipsRenderSection]> = .init(defaultValue: [])
    
    /// The default Default Implementations sections of symbol node, which list APIs that provide a default implementation of the symbol.
    public var defaultImplementationsSections: [TaskGroupRenderSection] {
        get { getVariantDefaultValue(keyPath: \.defaultImplementationsSectionsVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.defaultImplementationsSectionsVariants) }
    }
    
    /// The variants of the Default Implementations sections of symbol node, which list APIs that provide a default implementation of the symbol.
    public var defaultImplementationsSectionsVariants: VariantCollection<[TaskGroupRenderSection]> = .init(defaultValue: [])
        
    /// The See Also sections of a node, which list documentation resources related to this documentation node.
    public var seeAlsoSections: [TaskGroupRenderSection] {
        get { getVariantDefaultValue(keyPath: \.seeAlsoSectionsVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.seeAlsoSectionsVariants) }
    }
    
    /// The variants of the See Also sections of a node, which list documentation resources related to this documentation node.
    public var seeAlsoSectionsVariants: VariantCollection<[TaskGroupRenderSection]> = .init(defaultValue: [])
        
    /// A description of why this symbol is deprecated.
    public var deprecationSummary: [RenderBlockContent]? {
        get { getVariantDefaultValue(keyPath: \.deprecationSummaryVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.deprecationSummaryVariants) }
    }
    
    /// The variants of the description of why this symbol is deprecated.
    public var deprecationSummaryVariants: VariantCollection<[RenderBlockContent]?> = .init(defaultValue: nil)

    /// List of variants of the same documentation node for various languages.
    public var variants: [RenderNode.Variant]?
    
    /// Language-specific overrides for documentation.
    ///
    /// This property holds overrides that clients should apply to the render JSON when processing documentation for specific languages. The overrides are
    /// organized by traits (e.g., language) and it's up to the client to determine which trait is most appropriate for them. For example, a client that wants to
    /// process the Objective-C version of documentation should apply the overrides associated with the `interfaceLanguage: objc` trait.
    ///
    /// The overrides are emitted in the [JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) format.
    public var variantOverrides: VariantOverrides?
    
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
        self.topicSectionsStyle = .list
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
