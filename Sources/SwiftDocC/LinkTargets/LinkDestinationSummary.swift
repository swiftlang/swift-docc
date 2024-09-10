/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
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
///  - In a task group, the ``title`` and ``abstract`` is displayed together to give more context about this element and the element may be marked as deprecated
///    based on the values of its  ``platforms`` and other metadata about the current versions of the platforms.
///
/// The summary may include content that vary based on the source language. The content that is different in another source language is specified in a ``Variant``. Any property on the variant that is `nil` has the same value as the summarized element's value. 
public struct LinkDestinationSummary: Codable, Equatable {
    /// The kind of the summarized element.
    public let kind: DocumentationNode.Kind
    
    /// The language of the summarized element.
    public let language: SourceLanguage
    
    /// The relative presentation URL for this element.
    public let relativePresentationURL: URL
    
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
        
    /// Images that are used to represent the summarized element.
    public let topicImages: [TopicImage]?
    
    /// References used in the content of the summarized element.
    ///
    /// This includes the element's ``topicImages`` or references from the element's ``abstract``.
    /// This also includes any references for all variants' content.
    public var references: [RenderReference]?
    
    /// A variant of content for a summarized element.
    ///
    /// - Note: All properties except for ``traits`` are optional. If a property is `nil` it means that the value is the same as the summarized element's value.
    public struct Variant: Codable, Equatable {
        /// The traits of the variant.
        public let traits: [RenderNode.Variant.Trait]
        
        /// A wrapper for variant values that can either be specified, meaning the variant has a custom value, or not, meaning the variant has the same value as the summarized element.
        ///
        /// This alias is used to make the property declarations more explicit while at the same time offering the convenient syntax of optionals.
        public typealias VariantValue = Optional
        
        /// The kind of the variant or `nil` if the kind is the same as the summarized element.
        public let kind: VariantValue<DocumentationNode.Kind>
        
        /// The source language of the variant or `nil` if the kind is the same as the summarized element.
        public let language: VariantValue<SourceLanguage>
        
        /// The relative presentation URL of the variant or `nil` if the relative is the same as the summarized element.
        public let relativePresentationURL: VariantValue<URL>
        
        /// The title of the variant or `nil` if the title is the same as the summarized element.
        public let title: VariantValue<String>
        
        /// The abstract of the variant or `nil` if the abstract is the same as the summarized element.
        ///
        /// If the summarized element has an abstract but the variant doesn't, this property will be `Optional.some(nil)`.
        public let abstract: VariantValue<Abstract?>
        
        /// The taskGroups of the variant or `nil` if the taskGroups is the same as the summarized element.
        ///
        /// If the summarized element has task groups but the variant doesn't, this property will be `Optional.some(nil)`.
        public let taskGroups: VariantValue<[TaskGroup]?>
        
        /// The precise symbol identifier of the variant or `nil` if the precise symbol identifier is the same as the summarized element.
        ///
        /// If the summarized element has a precise symbol identifier but the variant doesn't, this property will be `Optional.some(nil)`.
        public let usr: VariantValue<String?>
        
        /// The declaration of the variant or `nil` if the declaration is the same as the summarized element.
        ///
        /// If the summarized element has a declaration but the variant doesn't, this property will be `Optional.some(nil)`.
        public let declarationFragments: VariantValue<DeclarationFragments?>
        
        /// Images that are used to represent the summarized element or `nil` if the images are the same as the summarized element.
        ///
        /// If the summarized element has an image but the variant doesn't, this property will be `Optional.some(nil)`.
        public let topicImages: VariantValue<[TopicImage]?>
        
        /// Creates a new summary variant with the values that are different from the main summarized values.
        /// 
        /// - Parameters:
        ///   - traits: The traits of the variant.
        ///   - kind: The kind of the variant or `nil` if the kind is the same as the summarized element.
        ///   - language: The source language of the variant or `nil` if the kind is the same as the summarized element.
        ///   - relativePresentationURL: The relative presentation URL of the variant or `nil` if the relative is the same as the summarized element.
        ///   - title: The title of the variant or `nil` if the title is the same as the summarized element.
        ///   - abstract: The abstract of the variant or `nil` if the abstract is the same as the summarized element.
        ///   - taskGroups: The taskGroups of the variant or `nil` if the taskGroups is the same as the summarized element.
        ///   - usr: The precise symbol identifier of the variant or `nil` if the precise symbol identifier is the same as the summarized element.
        ///   - declarationFragments: The declaration of the variant or `nil` if the declaration is the same as the summarized element.
        ///   - topicImages: Images that are used to represent the summarized element or `nil` if the images are the same as the summarized element.
        public init(
            traits: [RenderNode.Variant.Trait],
            kind: VariantValue<DocumentationNode.Kind> = nil,
            language: VariantValue<SourceLanguage> = nil,
            relativePresentationURL: VariantValue<URL> = nil,
            title: VariantValue<String> = nil,
            abstract: VariantValue<LinkDestinationSummary.Abstract?> = nil,
            taskGroups: VariantValue<[LinkDestinationSummary.TaskGroup]?> = nil,
            usr: VariantValue<String?> = nil,
            declarationFragments: VariantValue<LinkDestinationSummary.DeclarationFragments?> = nil,
            topicImages: VariantValue<[TopicImage]?> = nil
        ) {
            self.traits = traits
            self.kind = kind
            self.language = language
            self.relativePresentationURL = relativePresentationURL
            self.title = title
            self.abstract = abstract
            self.taskGroups = taskGroups
            self.usr = usr
            self.declarationFragments = declarationFragments
            self.topicImages = topicImages
        }
    }
    
    /// The variants of content (kind, title, abstract, path, urs, declaration, and task groups) for this summarized element.
    public let variants: [Variant]
    
    /// Creates a new summary of an element that can be linked to from outside the local documentation.
    ///
    /// - Parameters:
    ///   - kind: The kind of the summarized element.
    ///   - language: The language of the summarized element.
    ///   - relativePresentationURL: The relative presentation URL for this element.
    ///   - referenceURL: The resolved topic reference URL to this element.
    ///   - title: The title of the summarized element.
    ///   - abstract: The abstract of the summarized element.
    ///   - availableLanguages: All the languages in which the summarized element is available.
    ///   - platforms: Information about the platforms for which the summarized element is available.
    ///   - taskGroups: The reference URLs of the summarized element's children, grouped by their task groups.
    ///   - usr: The unique, precise identifier for this symbol that you use to reference it across different systems, or `nil` if the summarized element isn't a symbol.
    ///   - declarationFragments: The fragments for this symbol's declaration, or `nil` if the summarized element isn't a symbol.
    ///   - redirects: Any previous URLs for this element, or `nil` if this element has no previous URLs.
    ///   - topicImages: Images that are used to represent the summarized element, or `nil` if this element has no topic images.
    ///   - references: References used in the content of the summarized element, or `nil` if this element has no references to other content.
    ///   - variants: The variants of content (kind, title, abstract, path, urs, declaration, and task groups) for this summarized element.
    public init(
        kind: DocumentationNode.Kind,
        language: SourceLanguage,
        relativePresentationURL: URL,
        referenceURL: URL, title: String,
        abstract: LinkDestinationSummary.Abstract? = nil,
        availableLanguages: Set<SourceLanguage>,
        platforms: [LinkDestinationSummary.PlatformAvailability]? = nil,
        taskGroups: [LinkDestinationSummary.TaskGroup]? = nil,
        usr: String? = nil,
        declarationFragments: LinkDestinationSummary.DeclarationFragments? = nil,
        redirects: [URL]? = nil,
        topicImages: [TopicImage]? = nil,
        references: [RenderReference]? = nil,
        variants: [LinkDestinationSummary.Variant]
    ) {
        self.kind = kind
        self.language = language
        self.relativePresentationURL = relativePresentationURL
        self.referenceURL = referenceURL
        self.title = title
        self.abstract = abstract
        self.availableLanguages = availableLanguages
        self.platforms = platforms
        self.taskGroups = taskGroups
        self.usr = usr
        self.declarationFragments = declarationFragments
        self.redirects = redirects
        self.topicImages = topicImages
        self.references = references
        self.variants = variants
    }
}

// MARK: - Accessing the externally linkable elements

public extension DocumentationNode {
    /// Summarizes the node and all of its child elements that you can link to from outside the bundle.
    ///
    /// - Parameters:
    ///   - context: The context in which references that are found the node's content are resolved in.
    ///   - renderNode: The render node representation of this documentation node.
    ///   - includeTaskGroups: Whether or not the link summaries should include task groups
    /// - Returns: The list of summary elements, with the node's summary as the first element.
    func externallyLinkableElementSummaries(
        context: DocumentationContext,
        renderNode: RenderNode,
        includeTaskGroups: Bool = true
    ) -> [LinkDestinationSummary] {
        guard let bundle = context.bundle(identifier: reference.bundleIdentifier) else {
            // Don't return anything for external references that don't have a bundle in the context.
            return []
        }
        let urlGenerator = PresentationURLGenerator(context: context, baseURL: bundle.baseURL)
        let relativePresentationURL = urlGenerator.presentationURLForReference(reference).withoutHostAndPortAndScheme()
        
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: reference)

        let platforms = renderNode.metadata.platforms
        
        let landmarkSummaries = ((semantic as? Tutorial)?.landmarks ?? (semantic as? TutorialArticle)?.landmarks ?? []).compactMap {
            LinkDestinationSummary(landmark: $0, relativeParentPresentationURL: relativePresentationURL, page: self, platforms: platforms, compiler: &compiler)
        }
        
        var taskGroupVariants: [[RenderNode.Variant.Trait]: [LinkDestinationSummary.TaskGroup]] = [:]
        let taskGroups: [LinkDestinationSummary.TaskGroup]?
        if includeTaskGroups {
            switch kind {
            case .tutorial, .tutorialArticle, .technology, .technologyOverview, .chapter, .volume, .onPageLandmark:
                taskGroups = [.init(title: nil, identifiers: context.children(of: reference).map { $0.reference.absoluteString })]
            default:
                var topicSectionGroups: [LinkDestinationSummary.TaskGroup] = renderNode.topicSections.map { group in .init(title: group.title, identifiers: group.identifiers) }

                if let overloadChildren = context.topicGraph.overloads(of: self.reference), !overloadChildren.isEmpty {
                    topicSectionGroups.append(.init(title: "Overloads", identifiers: overloadChildren.map(\.absoluteString)))
                }

                taskGroups = topicSectionGroups
                for variant in renderNode.topicSectionsVariants.variants {
                    taskGroupVariants[variant.traits] = renderNode.topicSectionsVariants.value(for: variant.traits).map { group in .init(title: group.title, identifiers: group.identifiers) }
                }
            }
        } else {
            taskGroups = nil
        }
        return [
            LinkDestinationSummary(
                documentationNode: self,
                renderNode: renderNode,
                relativePresentationURL: relativePresentationURL,
                taskGroups: taskGroups,
                taskGroupVariants: taskGroupVariants,
                platforms: platforms,
                compiler: &compiler
            )
        ] + landmarkSummaries
    }
}

// MARK: - Creating Link Destination Summaries

extension Abstracted {
    /// Renders an optionally-available element abstract.
    ///
    /// - Parameter compiler: The content compiler to render the abstract.
    /// - Returns: The rendered abstract, or `nil` of the element doesn't have an abstract.
    func renderedAbstract(using compiler: inout RenderContentCompiler) -> LinkDestinationSummary.Abstract? {
        guard let abstract, case RenderBlockContent.paragraph(let p)? = compiler.visitParagraph(abstract).first else {
            return nil
        }
        return p.inlineContent
    }
}

extension LinkDestinationSummary {
    
    /// Creates a link destination summary for this page.
    ///
    /// - Parameters:
    ///   - documentationNode: The render node to summarize.
    ///   - relativePresentationURL: The relative presentation URL for this page.
    ///   - taskGroups: The task groups that lists the children of this page.
    ///   - compiler: The content compiler that's used to render the node's abstract.
    init(
        documentationNode: DocumentationNode,
        renderNode: RenderNode,
        relativePresentationURL: URL,
        taskGroups: [TaskGroup]?,
        taskGroupVariants: [[RenderNode.Variant.Trait]: [TaskGroup]],
        platforms: [PlatformAvailability]?,
        compiler: inout RenderContentCompiler
    ) {
        let redirects = (documentationNode.semantic as? Redirected)?.redirects?.map { $0.oldPath }
        let referenceURL = documentationNode.reference.url
        
        let topicImages = renderNode.metadata.images
        let referenceIdentifiers = topicImages.map(\.identifier)
        
        guard let symbol = documentationNode.semantic as? Symbol, let summaryTrait = documentationNode.availableVariantTraits.first(where: { $0.interfaceLanguage == documentationNode.sourceLanguage.id }) else {
            // Only symbol documentation currently support multi-language variants (rdar://86580915)
            let references = referenceIdentifiers
                .compactMap { renderNode.references[$0.identifier] }
                .sorted(by: \.identifier.identifier)
            
            self.init(
                kind: documentationNode.kindForLinkDestinationSummary,
                language: documentationNode.sourceLanguage,
                relativePresentationURL: relativePresentationURL,
                referenceURL: referenceURL,
                title: ReferenceResolver.title(forNode: documentationNode),
                abstract: (documentationNode.semantic as? Abstracted)?.renderedAbstract(using: &compiler),
                availableLanguages: documentationNode.availableSourceLanguages,
                platforms: platforms,
                taskGroups: taskGroups,
                usr: nil,
                declarationFragments: nil,
                redirects: redirects,
                topicImages: topicImages.nilIfEmpty,
                references: references.nilIfEmpty,
                variants: []
            )
            return
        }
        
        // Precompute the summarized elements information so that variants can compare their information against it and remove redundant duplicate information.
        
        // Multi-language symbols need to access the default content via the variant accessors (rdar://86580516)
        let kind = DocumentationNode.kind(forKind: (symbol.kindVariants[summaryTrait] ?? symbol.kind).identifier)
        let title = symbol.titleVariants[summaryTrait] ?? symbol.title
        
        func renderSymbolAbstract(_ symbolAbstract: Paragraph?) -> Abstract? {
            guard let abstractParagraph = symbolAbstract, case RenderBlockContent.paragraph(let p)? = compiler.visitParagraph(abstractParagraph).first else {
                return nil
            }
            return p.inlineContent
        }
        
        let abstract = renderSymbolAbstract(symbol.abstractVariants[summaryTrait] ?? symbol.abstract)
        let usr = symbol.externalIDVariants[summaryTrait] ?? symbol.externalID
        let declaration = (symbol.declarationVariants[summaryTrait] ?? symbol.declaration).renderDeclarationTokens()
        let language = documentationNode.sourceLanguage
        
        let variants: [Variant] = documentationNode.availableVariantTraits.compactMap { trait in
            // Skip the variant for the summarized elements source language.
            guard let interfaceLanguage = trait.interfaceLanguage, interfaceLanguage != documentationNode.sourceLanguage.id else {
                return nil
            }
            
            let declarationVariant = symbol.declarationVariants[trait]?.renderDeclarationTokens()
            
            let abstractVariant: Variant.VariantValue<Abstract?> = symbol.abstractVariants[trait].map { renderSymbolAbstract($0) }
            
            func nilIfEqual<Value: Equatable>(main: Value, variant: Value?) -> Value? {
                return main == variant ? nil : variant
            }
            
            let variantTraits = [RenderNode.Variant.Trait.interfaceLanguage(interfaceLanguage)]
            return Variant(
                traits: variantTraits,
                kind: nilIfEqual(main: kind, variant: symbol.kindVariants[trait].map { DocumentationNode.kind(forKind: $0.identifier) }),
                language: nilIfEqual(main: language, variant: SourceLanguage(knownLanguageIdentifier: interfaceLanguage)),
                relativePresentationURL: nil, // The symbol variant uses the same relative path
                title: nilIfEqual(main: title, variant: symbol.titleVariants[trait]),
                abstract: nilIfEqual(main: abstract, variant: abstractVariant),
                taskGroups: nilIfEqual(main: taskGroups, variant: taskGroupVariants[variantTraits]),
                usr: nil, // The symbol variant uses the same USR
                declarationFragments: nilIfEqual(main: declaration, variant: declarationVariant),
                topicImages: nil // The symbol variant doesn't currently have their own images
            )
        }
        
        let references = referenceIdentifiers
            .compactMap { renderNode.references[$0.identifier] }
            .sorted(by: \.identifier.identifier)
        
        self.init(
            kind: kind,
            language: language,
            relativePresentationURL: relativePresentationURL,
            referenceURL: referenceURL,
            title: title,
            abstract: abstract,
            availableLanguages: documentationNode.availableSourceLanguages,
            platforms: platforms,
            taskGroups: taskGroups,
            usr: usr,
            declarationFragments: declaration,
            redirects: redirects,
            topicImages: topicImages.nilIfEmpty,
            references: references.nilIfEmpty,
            variants: variants
        )
    }
}

private extension [[PlatformName?]: SymbolGraph.Symbol.DeclarationFragments] {
    func mainRenderFragments() -> SymbolGraph.Symbol.DeclarationFragments? {
        guard count > 1 else {
            return first?.value
        }
        
        return self.min(by: { lhs, rhs in
            // Join all the platform IDs and use that to get a stable value
            lhs.key.compactMap(\.?.rawValue).joined() < lhs.key.compactMap(\.?.rawValue).joined()
        })?.value
    }
    
    func renderDeclarationTokens() -> [DeclarationRenderSection.Token]? {
        return mainRenderFragments()?.declarationFragments.map {
            DeclarationRenderSection.Token(fragment: $0, identifier: nil)
        }
    }
}

extension LinkDestinationSummary {
    
    /// Creates a link destination summary for a landmark on a page.
    ///
    /// - Parameters:
    ///   - landmark: The landmark to summarize.
    ///   - relativeParentPresentationURL: The bundle-relative path of the page that contain this section.
    ///   - page: The topic reference of the page that contain this section.
    ///   - compiler: The content compiler that's used to render the section's abstract.
    init?(landmark: Landmark, relativeParentPresentationURL: URL, page: DocumentationNode, platforms: [PlatformAvailability]?, compiler: inout RenderContentCompiler) {
        let anchor = urlReadableFragment(landmark.title)
        
        guard let relativePresentationURL: URL = {
            var components = URLComponents(url: relativeParentPresentationURL, resolvingAgainstBaseURL: false)
            components?.fragment = anchor // use an in-page anchor for the landmark's path
            return components?.url
        }() else {
            return nil
        }
        
        let abstract: Abstract?
        if let abstracted = landmark as? Abstracted {
            abstract = abstracted.renderedAbstract(using: &compiler) ?? []
        } else if let paragraph = landmark.markup.children.lazy.compactMap({ $0 as? Paragraph }).first, case RenderBlockContent.paragraph(let p)? = compiler.visitParagraph(paragraph).first {
            abstract = p.inlineContent
        } else {
            abstract = nil
        }
        
        self.init(
            kind: .onPageLandmark,
            language: page.sourceLanguage,
            relativePresentationURL: relativePresentationURL,
            referenceURL: page.reference.withFragment(anchor).url,
            title: landmark.title,
            abstract: abstract,
            availableLanguages: page.availableSourceLanguages,
            platforms: platforms,
            taskGroups: [], // Landmarks have no children
            usr: nil, // Only symbols have a USR
            declarationFragments: nil, // Only symbols have declarations
            redirects: (landmark as? Redirected)?.redirects?.map { $0.oldPath },
            topicImages: nil, // Landmarks doesn't have topic images
            references: nil, // Landmarks have no references, since only topic image references is currently supported
            variants: []
        )
    }
}

// MARK: - Codable conformance

// Add Codable methods—which include an initializer—in an extension so that it doesn't override the member-wise initializer.
extension LinkDestinationSummary {
    enum CodingKeys: String, CodingKey {
        case kind, referenceURL, title, abstract, language, taskGroups, usr, availableLanguages, platforms, redirects, topicImages, references, variants
        case relativePresentationURL = "path"
        case declarationFragments = "fragments"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind.id, forKey: .kind)
        try container.encode(relativePresentationURL, forKey: .relativePresentationURL)
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
        try container.encodeIfPresent(topicImages, forKey: .topicImages)
        try container.encodeIfPresent(references?.map { CodableRenderReference($0) }, forKey: .references)
        
        if !variants.isEmpty {
            try container.encode(variants, forKey: .variants)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kindID = try container.decode(String.self, forKey: .kind)
        guard let foundKind = DocumentationNode.Kind.allKnownValues.first(where: { $0.id == kindID }) else {
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown DocumentationNode.Kind identifier: '\(kindID)'.")
        }
        kind = foundKind
        relativePresentationURL = try container.decode(URL.self, forKey: .relativePresentationURL)
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
        topicImages = try container.decodeIfPresent([TopicImage].self, forKey: .topicImages)
        references = try container.decodeIfPresent([CodableRenderReference].self, forKey: .references).map { decodedReferences in
            decodedReferences.map(\.reference)
        }
        
        variants = try container.decodeIfPresent([Variant].self, forKey: .variants) ?? []
    }
}

extension LinkDestinationSummary.Variant {
    enum CodingKeys: String, CodingKey {
        case traits, kind, title, abstract, language, usr, taskGroups, topicImages
        case relativePresentationURL = "path"
        case declarationFragments = "fragments"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(traits, forKey: .traits)
        try container.encodeIfPresent(kind?.id, forKey: .kind)
        try container.encodeIfPresent(relativePresentationURL, forKey: .relativePresentationURL)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(abstract, forKey: .abstract)
        try container.encodeIfPresent(language?.id, forKey: .language)
        try container.encodeIfPresent(usr, forKey: .usr)
        try container.encodeIfPresent(declarationFragments, forKey: .declarationFragments)
        try container.encodeIfPresent(taskGroups, forKey: .taskGroups)
        try container.encodeIfPresent(topicImages, forKey: .topicImages)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let traits = try container.decode([RenderNode.Variant.Trait].self, forKey: .traits)
        for case .interfaceLanguage(let languageID) in traits {
            guard SourceLanguage.knownLanguages.contains(where: { $0.id == languageID }) else {
                throw DecodingError.dataCorruptedError(forKey: .traits, in: container, debugDescription: "Unknown SourceLanguage identifier: '\(languageID)'.")
            }
        }
        self.traits = traits
        
        let kindID = try container.decodeIfPresent(String.self, forKey: .kind)
        if let kindID {
            guard let foundKind = DocumentationNode.Kind.allKnownValues.first(where: { $0.id == kindID }) else {
                throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown DocumentationNode.Kind identifier: '\(kindID)'.")
            }
            kind = foundKind
        } else {
            kind = nil
        }
        
        let languageID = try container.decodeIfPresent(String.self, forKey: .language)
        if let languageID {
            guard let foundLanguage = SourceLanguage.knownLanguages.first(where: { $0.id == languageID }) else {
                throw DecodingError.dataCorruptedError(forKey: .language, in: container, debugDescription: "Unknown SourceLanguage identifier: '\(languageID)'.")
            }
            language = foundLanguage
        } else {
            language = nil
        }
        relativePresentationURL = try container.decodeIfPresent(URL.self, forKey: .relativePresentationURL)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        abstract = try container.decodeIfPresent(LinkDestinationSummary.Abstract?.self, forKey: .abstract)
        usr = try container.decodeIfPresent(String?.self, forKey: .usr)
        declarationFragments = try container.decodeIfPresent(LinkDestinationSummary.DeclarationFragments?.self, forKey: .declarationFragments)
        taskGroups = try container.decodeIfPresent([LinkDestinationSummary.TaskGroup]?.self, forKey: .taskGroups)
        topicImages = try container.decodeIfPresent([TopicImage]?.self, forKey: .topicImages)
    }
}

// MARK: - Equatable conformance

// Manually implement `==(_:_:)` since ``RenderReference`` doesn't conform to Equatable.
// (Adding that conformance would add a Self requirement that would add the need for type erasure in other places)
extension LinkDestinationSummary {
    public static func == (lhs: LinkDestinationSummary, rhs: LinkDestinationSummary) -> Bool {
        // The reference URL and usr have identity-like qualities.
        // If those are different the other data-like properties would also be different.
        guard lhs.referenceURL == rhs.referenceURL else { return false }
        guard lhs.usr == rhs.usr else { return false }
        
        // Compare the data-like properties in the order that they are declared (above).
        guard lhs.kind == rhs.kind else { return false }
        guard lhs.language == rhs.language else { return false }
        guard lhs.relativePresentationURL == rhs.relativePresentationURL else { return false }
        guard lhs.title == rhs.title else { return false }
        guard lhs.abstract == rhs.abstract else { return false }
        guard lhs.availableLanguages == rhs.availableLanguages else { return false }
        guard lhs.platforms == rhs.platforms else { return false }
        guard lhs.taskGroups == rhs.taskGroups else { return false }
        guard lhs.declarationFragments == rhs.declarationFragments else { return false }
        guard lhs.redirects == rhs.redirects else { return false }
        guard lhs.topicImages == rhs.topicImages else { return false }
        guard lhs.variants == rhs.variants else { return false }
        
        // Since `RenderReference` doesn't conform to Equatable, the `references` need to be compared manually.
        // There's a known number of render references types for the various `RenderReferenceType` cases.
        guard lhs.references?.count == rhs.references?.count else { return false }
        for (lhsRef, rhsRef) in zip(lhs.references ?? [], rhs.references ?? []) {
            switch (lhsRef, rhsRef) {
            case let (lhsImageRef, rhsImageRef) as (ImageReference, ImageReference):
                guard lhsImageRef == rhsImageRef else { return false }
                continue
                
            case let (lhsVideoRef, rhsVideoRef) as (VideoReference, VideoReference):
                guard lhsVideoRef == rhsVideoRef else { return false }
                continue
                
            case let (lhsFileRef, rhsFileRef) as (FileReference, FileReference):
                guard lhsFileRef == rhsFileRef else { return false }
                continue
                
            case let (lhsFileTypeRef, rhsFileTypeRef) as (FileTypeReference, FileTypeReference):
                guard lhsFileTypeRef == rhsFileTypeRef else { return false }
                continue
                
            case let (lhsXcodeRequirementRef, rhsXcodeRequirementRef) as (XcodeRequirementReference, XcodeRequirementReference):
                guard lhsXcodeRequirementRef == rhsXcodeRequirementRef else { return false }
                continue
                
            // This case covers both `topic` and `section` render references. See CodableRenderReference.
            case let (lhsTopicRef, rhsTopicRef) as (TopicRenderReference, TopicRenderReference):
                guard lhsTopicRef == rhsTopicRef else { return false }
                continue
                
            case let (lhsDownloadRef, rhsDownloadRef) as (DownloadReference, DownloadReference):
                guard lhsDownloadRef == rhsDownloadRef else { return false }
                continue
                    
            case let (lhsLinkRef, rhsLinkRef) as (LinkReference, LinkReference):
                guard lhsLinkRef == rhsLinkRef else { return false }
                continue
                
            case let (lhsUnresolvedRef, rhsUnresolvedRef) as (UnresolvedRenderReference, UnresolvedRenderReference):
                guard lhsUnresolvedRef == rhsUnresolvedRef else { return false }
                continue
                
            default:
                return false
            }
        }
        
        return true
    }
}

private extension DocumentationNode {
    /// The documentation node kind that should be used when creating a link destination
    /// summary for this node.
    var kindForLinkDestinationSummary: DocumentationNode.Kind {
        // If this page has an explicit page kind set with the `@PageKind` metadata directive, that
        // is the one that should be used for the link destination summary.
        //
        // This allows specialized articles, like SampleCode pages, that are otherwise treated as
        // articles in the compilation process to still be rendered correctly when linked against.
        // However, this solution is less than ideal...
        //
        // FIXME: Implement a more robust solution for handling specialized article-like pages.
        //
        // This implementation is less than ideal. There should be a more robust way of handling
        // specialized articles, like sample code pages, that benefit from being treated as articles in
        // some parts of the compilation process (like curation) but not others (like link destination
        // summary creation and render node translation).
        return metadata?.pageKind?.kind.documentationNodeKind ?? kind
    }
}

// MARK: - Private helpers

private extension Collection {
    var nilIfEmpty: Self? {
        isEmpty ? nil : self
    }
}
