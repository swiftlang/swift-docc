/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import SymbolKit

// Link resolution works in two parts:
//
//  1. When DocC compiles a documentation bundle and encounters an "external" reference it will call out to
//     resolve that reference using the external resolver that's been registered for that bundle identifier.
//     The reference may be a page in another documentation bundle or a page from another source.
//
//  2. Once DocC has finished compiling the documentation bundle it will summarize all the pages and on-page
//     elements that can be linked to.
//     This information is returned when another documentation bundle resolves a reference for that page.
//
//
//   DocC                                                                                           Backend endpoint
//  ┌──────────────────────────────────────────────────────────┐                                   ┌───────────────────────────────┐
//  │ ┌──────────────────────────┐                             │                                   │                               │
//  │ │                          │                             │                                   │                               │
//  │ │   DocumentationContext   │                             │                                   │                               │
//  │ │     Register bundle      │                             │                                   │                               │
//  │ │                          │                             │                                   │                               │
//  │ └──────────────────────────┘       Resolve external      │                                   │                               │
//  │               │                       references         │                                   │                               │
//  │               ▼                                          │                                   │                               │
//  │ ┌──────────────────────────┐       ┌────────────────┐    │    ┌───────────────────────┐      │                               │
//  │ │                          │       │                │    │    │                       │      │                               │
//  │ │   DocumentationContext   │──────▶│ Out-of-process │────┼───▶│  Request information  │─────▶│                               │
//  │ │      Resolve links       │◀──────│    resolver    │◀───┼────│     from a server     │◀─────│◀ ─ ┬ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─      │
//  │ │                          │       │                │    │    │                       │      │                         │     │
//  │ └──────────────────────────┘       └────────────────┘    │    └───────────────────────┘      │    │                          │
//  │               │                                          │                                   │        Either respond   │     │
//  │               │                                          │                                   │    │  with information        │
//  │               │                                          │                                   │         about another   │     │
//  │              ...                                         │                                   │    │      DocC page           │
//  │               │                                          │                                   │                         │     │
//  │               │                                          │                                   │    │         OR               │
//  │               ▼                                          │                                   │                         │     │
//  │ ┌──────────────────────────┐                             │                                   │    │    Respond with          │
//  │ │                          │                             │                                   │       information about │     │
//  │ │      ConvertAction       │                             │                                   │    │     a page from          │
//  │ │    Convert and render    │                             │                                   │        another source   │     │
//  │ │                          │                             │                                   │    │                          │
//  │ └──────────────────────────┘                             │                                   │                         │     │
//  │               │                Encode information about  │                                   │    │                          │
//  │               ▼                 every page and on-page   │                                   │                         │     │
//  │ ┌──────────────────────────┐     element that can be     │    ┌───────────────────────┐      │    │                          │   Other sources
//  │ │                          │    referenced externally    │    │                       │      │                         ┝ ─ ─ ┤◀────────────────
//  │ │      ConvertAction       │                             │    │  Process and upload   │      │    │                          │
//  │ │ write linkable entities  │─────────────────────────────┼───▶│ information about the │─────▶├ ─ ─                     └ ─ ─ ┤◀────────────────
//  │ │                          │                             │    │   linkable elements   │      │                               │
//  │ └──────────────────────────┘                             │    │                       │      │                               │
//  │                                                          │    └───────────────────────┘      │                               │
//  └──────────────────────────────────────────────────────────┘                                   └───────────────────────────────┘

/// A summary of an element that you can link to from outside the documentation bundle.
///
/// The non-optional properties of this summary are all the information needed when another bundle references this element.
///
/// Various information from the summary is used depending on what content references the summarized element. For example:
///  - In a paragraph of text, a link to this element will use the ``title`` as the link text and style the tile in code font if the ``kind`` is a type of symbol.
///  - In a task group, the the ``title`` and ``abstract-swift.property`` is displayed together to give more context about this element and the element may be marked as deprecated
///    based on the values of its  ``platforms`` and other metadata about the current versions of the platforms.
public struct LinkDestinationSummary: Codable, Equatable {
    /// The kind of the summarized element.
    public let kind: DocumentationNode.Kind
    
    /// The language of the summarized element.
    public let language: SourceLanguage
    
    /// The relative path to this element.
    public let path: String
    
    /// The resolved topic reference URL to this element.
    public var referenceURL: URL
    
    /// The title of the summarized element.
    public let title: String
    
    /// An abstract is a single paragraph of rendered inline content.
    public typealias Abstract = [RenderInlineContent]
    /// The abstract of the summarized element.
    public let abstract: Abstract?
    
    /// All the languages in which the summarized element is available.
    public let availableLanguages: Set<SourceLanguage>

    /// The availability information for a platform.
    public typealias PlatformAvailability = AvailabilityRenderItem
    /// Information about the platforms for which the summarized element is available.
    public let platforms: [PlatformAvailability]?
    
    // Note to implementors when adding new properties:
    //  Any new property that DocC doesn't need to get back when resolving references should be optional
    //  so that external documentation sources don't need to provide that data.
    //  Adding new required properties is considered breaking change since existing external documentation sources
    //  wouldn't necessarily meet these new requirements.
    
    /// A collection of identifiers that all relate to some common task, as described by the title.
    public struct TaskGroup: Codable, Equatable {
        /// The title of this task group
        public let title: String?
        /// The identifiers of all the elements that are part of this task group.
        public let identifiers: [String]
        
        /// Creates a new task group that lists a number of elements that relate to a common task.
        ///
        /// - Parameters:
        ///   - title: The optional title for this task group.
        ///   - identifiers: The identifiers of all the elements that are part of this task group.
        public init(title: String?, identifiers: [String]) {
            self.title = title
            self.identifiers = identifiers
        }
    }
    
    /// The reference URLs of the summarized element's children, grouped by their task groups.
    ///
    /// - Note: It's possible for more than one task group to have the same title.
    /// - Note: This property represents conceptual children. Since See Also sections conceptually represent siblings they should not be included.
    public let taskGroups: [TaskGroup]?
    
    /// The unique, precise identifier for this symbol that you use to reference it across different systems, or `nil` if the summarized element isn't a symbol.
    public let usr: String?
    
    /// The rendered fragments of a symbol's declaration.
    public typealias DeclarationFragments = [DeclarationRenderSection.Token]
    /// The fragments for this symbol's declaration, or `nil` if the summarized element isn't a symbol.
    public let declarationFragments: DeclarationFragments?
    
    /// Any previous URLs for this element.
    ///
    /// A web server can use this list of URLs to redirect to the current URL.
    public let redirects: [URL]?
}

// MARK: - Accessing the externally linkable elements

public extension DocumentationNode {
    /// Summarizes the node and all of its child elements that you can link to from outside the bundle.
    ///
    /// - Parameters:
    ///   - context: The context in which references that are found the node's content are resolved in.
    ///   - renderNode: The render node representation of this documentation node.
    /// - Returns: The list of summary elements, with the node's summary as the first element.
    func externallyLinkableElementSummaries(context: DocumentationContext, renderNode: RenderNode) -> [LinkDestinationSummary] {
        guard let bundle = context.bundle(identifier: reference.bundleIdentifier) else {
            // Don't return anything for external references that don't have a bundle in the context.
            return []
        }
        let urlGenerator = PresentationURLGenerator(context: context, baseURL: bundle.baseURL)
        let presentationURL = urlGenerator.presentationURLForReference(reference)
        
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: reference)

        let platforms = renderNode.metadata.platforms
        
        let landmarkSummaries = ((semantic as? Tutorial)?.landmarks ?? (semantic as? TutorialArticle)?.landmarks ?? []).map {
            LinkDestinationSummary(landmark: $0, basePath: presentationURL.path, page: self, platforms: platforms, compiler: &compiler)
        }
        
        let taskGroups: [LinkDestinationSummary.TaskGroup]
        switch kind {
        case .tutorial, .tutorialArticle, .technology, .technologyOverview, .chapter, .volume, .onPageLandmark:
            taskGroups = [.init(title: nil, identifiers: context.children(of: reference).map { $0.reference.absoluteString })]
        default:
            taskGroups = renderNode.topicSections.map { group in .init(title: group.title, identifiers: group.identifiers) }
        }
        return [LinkDestinationSummary(documentationNode: self, path: presentationURL.path, taskGroups: taskGroups, platforms: platforms, compiler: &compiler)] + landmarkSummaries
    }
}

// MARK: - Creating Link Destination Summaries

extension Abstracted {
    /// Renders an optionally-available element abstract.
    ///
    /// - Parameter compiler: The content compiler to render the abstract.
    /// - Returns: The rendered abstract, or `nil` of the element doesn't have an abstract.
    func renderedAbstract(using compiler: inout RenderContentCompiler) -> LinkDestinationSummary.Abstract? {
        guard let abstract = abstract, case RenderBlockContent.paragraph(let inlineContent)? = compiler.visitParagraph(abstract).first else {
            return nil
        }
        return inlineContent
    }
}

extension LinkDestinationSummary {
    
    /// Creates a link destination summary for this page.
    ///
    /// - Parameters:
    ///   - documentationNode: The render node to summarize.
    ///   - path: The bundle-relative path to this page.
    ///   - taskGroups: The task groups that lists the children of this page.
    ///   - compiler: The content compiler that's used to render the node's abstract.
    init(documentationNode: DocumentationNode, path: String, taskGroups: [TaskGroup], platforms: [PlatformAvailability]?, compiler: inout RenderContentCompiler) {
        let declaration = (documentationNode.semantic as? Symbol)?.subHeading.map { declaration in
            return declaration.map { fragment in
                DeclarationRenderSection.Token(fragment: fragment, identifier: nil)
            }
        }
        
        self.init(
            kind: documentationNode.kind,
            language: documentationNode.sourceLanguage,
            path: path,
            referenceURL: documentationNode.reference.url,
            title: ReferenceResolver.title(forNode: documentationNode),
            abstract: (documentationNode.semantic as? Abstracted)?.renderedAbstract(using: &compiler),
            availableLanguages: documentationNode.availableSourceLanguages,
            platforms: platforms,
            taskGroups: taskGroups,
            usr: (documentationNode.semantic as? Symbol)?.externalID,
            declarationFragments: declaration,
            redirects: (documentationNode.semantic as? Redirected)?.redirects?.map { $0.oldPath }
        )
    }
}

extension LinkDestinationSummary {
    
    /// Creates a link destination summary for a landmark on a page.
    ///
    /// - Parameters:
    ///   - landmark: The landmark to summarize.
    ///   - basePath: The bundle-relative path of the page that contain this section.
    ///   - page: The topic reference of the page that contain this section.
    ///   - compiler: The content compiler that's used to render the section's abstract.
    init(landmark: Landmark, basePath: String, page: DocumentationNode, platforms: [PlatformAvailability]?, compiler: inout RenderContentCompiler) {
        let anchor = urlReadableFragment(landmark.title)
        
        let abstract: Abstract
        if let abstracted = landmark as? Abstracted {
            abstract = abstracted.renderedAbstract(using: &compiler) ?? []
        } else if let paragraph = landmark.markup.children.lazy.compactMap({ $0 as? Paragraph }).first, case RenderBlockContent.paragraph(let inlineContent)? = compiler.visitParagraph(paragraph).first {
            abstract = inlineContent
        } else {
            abstract = []
        }
        
        self.init(
            kind: .onPageLandmark,
            language: page.sourceLanguage,
            path: basePath + "#\(anchor)", // use an in-page anchor for the landmark's path
            referenceURL: page.reference.withFragment(anchor).url,
            title: landmark.title,
            abstract: abstract,
            availableLanguages: page.availableSourceLanguages,
            platforms: platforms,
            taskGroups: [], // Landmarks have no children
            usr: nil, // Only symbols have a USR
            declarationFragments: nil, // Only symbols have declarations
            redirects: (landmark as? Redirected)?.redirects?.map { $0.oldPath }
        )
    }
}

// MARK: - Codable conformance

// Add Codable methods—which include an initializer—in an extension so that it doesn't override the member-wise initializer.
extension LinkDestinationSummary {
    enum CodingKeys: String, CodingKey {
        case kind, path, referenceURL, title, abstract, language, taskGroups, usr, availableLanguages, platforms, redirects
        case declarationFragments = "fragments"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind.id, forKey: .kind)
        try container.encode(path, forKey: .path)
        try container.encode(referenceURL, forKey: .referenceURL)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(abstract, forKey: .abstract)
        try container.encode(language.id, forKey: .language)
        try container.encode(availableLanguages.map { $0.id }, forKey: .availableLanguages)
        try container.encodeIfPresent(platforms, forKey: .platforms)
        try container.encodeIfPresent(taskGroups, forKey: .taskGroups)
        try container.encodeIfPresent(usr, forKey: .usr)
        try container.encodeIfPresent(declarationFragments, forKey: .declarationFragments)
        try container.encodeIfPresent(redirects, forKey: .redirects)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kindID = try container.decode(String.self, forKey: .kind)
        guard let foundKind = DocumentationNode.Kind.allKnownValues.first(where: { $0.id == kindID }) else {
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown DocumentationNode.Kind identifier: '\(kindID)'.")
        }
        kind = foundKind
        path = try container.decode(String.self, forKey: .path)
        referenceURL = try container.decode(URL.self, forKey: .referenceURL)
        title = try container.decode(String.self, forKey: .title)
        abstract = try container.decodeIfPresent(Abstract.self, forKey: .abstract)
        let languageID = try container.decode(String.self, forKey: .language)
        guard let foundLanguage = SourceLanguage.knownLanguages.first(where: { $0.id == languageID }) else {
            throw DecodingError.dataCorruptedError(forKey: .language, in: container, debugDescription: "Unknown SourceLanguage identifier: '\(languageID)'.")
        }
        language = foundLanguage
        
        let availableLanguageIDs = try container.decode([String].self, forKey: .availableLanguages)
        availableLanguages = try Set(availableLanguageIDs.map { languageID in
            guard let foundLanguage = SourceLanguage.knownLanguages.first(where: { $0.id == languageID }) else {
                throw DecodingError.dataCorruptedError(forKey: .availableLanguages, in: container, debugDescription: "Unknown SourceLanguage identifier: '\(languageID)'.")
            }
            return foundLanguage
        })
        platforms = try container.decodeIfPresent([AvailabilityRenderItem].self, forKey: .platforms)
        taskGroups = try container.decodeIfPresent([TaskGroup].self, forKey: .taskGroups)
        usr = try container.decodeIfPresent(String.self, forKey: .usr)
        declarationFragments = try container.decodeIfPresent(DeclarationFragments.self, forKey: .declarationFragments)
        redirects = try container.decodeIfPresent([URL].self, forKey: .redirects)
    }
}
