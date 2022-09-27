/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
import Markdown

public struct RenderReferenceDependencies {
    var topicReferences = [ResolvedTopicReference]()
    var linkReferences = [LinkReference]()
    var imageReferences = [ImageReference]()
    
    public init(topicReferences: [ResolvedTopicReference] = [], linkReferences: [LinkReference] = [], imageReferences: [ImageReference] = []) {
        self.topicReferences = topicReferences
        self.linkReferences = linkReferences
        self.imageReferences = imageReferences
    }
}

extension RenderReferenceDependencies: Codable {
    private enum CodingKeys: CodingKey {
        case topicReferences, linkReferences, imageReferences
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(topicReferences, forKey: .topicReferences)
        try container.encode(linkReferences, forKey: .linkReferences)
        try container.encodeIfNotEmpty(imageReferences, forKey: .imageReferences)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        topicReferences = try container.decode([ResolvedTopicReference].self, forKey: .topicReferences)
        linkReferences = try container.decode([LinkReference].self, forKey: .linkReferences)
        imageReferences = try container.decodeIfPresent([ImageReference].self, forKey: .imageReferences) ?? []
    }
}

/// A collection of functions that render a piece of documentation content.
public class DocumentationContentRenderer {

    let documentationContext: DocumentationContext
    let bundle: DocumentationBundle
    let urlGenerator: PresentationURLGenerator
    
    /// Creates a new content renderer for the given documentation context and bundle.
    /// - Parameters:
    ///   - documentationContext: A documentation context.
    ///   - bundle: A documentation bundle.
    public init(documentationContext: DocumentationContext, bundle: DocumentationBundle) {
        self.documentationContext = documentationContext
        self.bundle = bundle
        self.urlGenerator = PresentationURLGenerator(context: documentationContext, baseURL: bundle.baseURL)
    }
    
    /// For symbol nodes, returns the fragments mixin if any.
    func subHeadingFragments(for node: DocumentationNode) -> VariantCollection<[DeclarationRenderSection.Token]?> {
        guard let symbol = (node.semantic as? Symbol) else {
            return .init(defaultValue: nil)
        }
        
        return VariantCollection<[DeclarationRenderSection.Token]?>(
            from: symbol.subHeadingVariants,
            symbol.titleVariants,
            symbol.kindVariants
        ) { trait, subHeading, title, kind in
            var fragments = subHeading
                .map({ fragment -> DeclarationRenderSection.Token in
                    return DeclarationRenderSection.Token(fragment: fragment, identifier: nil)
                })
            if fragments.last?.text == "\n" { fragments.removeLast() }
            
            if trait == .swift {
                return Swift.subHeading(for: fragments, symbolTitle: title, symbolKind: kind.identifier.identifier)
            } else {
                return fragments
            }
        } ?? .init(defaultValue: nil)
    }
    
    /// For symbol nodes, returns the navigator title if any.
    func navigatorFragments(for node: DocumentationNode) -> VariantCollection<[DeclarationRenderSection.Token]?> {
        guard let symbol = (node.semantic as? Symbol) else {
            return .init(defaultValue: nil)
        }
        
        return VariantCollection<[DeclarationRenderSection.Token]?>(
            from: symbol.navigatorVariants,
            symbol.titleVariants
        ) { trait, navigator, title in
            var fragments = navigator.map { fragment -> DeclarationRenderSection.Token in
                return DeclarationRenderSection.Token(fragment: fragment, identifier: nil)
            }
            if fragments.last?.text == "\n" { fragments.removeLast() }
            
            if trait == .swift {
                return Swift.navigatorTitle(for: fragments, symbolTitle: title)
            } else {
                return fragments
            }
        } ?? .init(defaultValue: nil)
    }
    
    /// Returns the given amount of minutes as a string, for example: "1hr 10min".
    func formatEstimatedDuration(minutes: Int) -> String? {
        // TODO: Use DateComponentsFormatter once it's available on Linux (rdar://59787899) and 
        // when Swift-DocC supports generating localized documentation (github.com/apple/swift-docc/issues/218), since
        // DateComponentsFormatter formats content based on the user's locale.
//        let dateFormatter = DateComponentsFormatter()
//        if #available(OSX 10.12, *) {
//            dateFormatter.unitsStyle = .brief
//        }
//        dateFormatter.allowedUnits = [.hour, .minute]
//        return dateFormatter.string(from: TimeInterval(minutes * 60))
        let hours = minutes / 60
        let minutes = minutes % 60
        return "\(hours > 0 ? "\(hours)hr " : "")\(minutes)min"
    }

    /// Returns a metadata role for an article, depending if it's a collection, technology, or a free form article.
    func roleForArticle(_ article: Article, nodeKind: DocumentationNode.Kind) -> RenderMetadata.Role {
        // We create generated nodes with a semantic Article because they
        // can have doc extensions and the only way to tell them apart from
        // api collections or other articles is by their node kind.
        switch nodeKind {
        case .collectionGroup: return role(for: nodeKind)
        default: break
        }
        
        if article.topics?.taskGroups.isEmpty == false {
            // The documentation includes a "Topics" section, it's a collection or a group
            let isTechnologyRoot = article.metadata?.technologyRoot != nil
            return role(for: (isTechnologyRoot) ? .collection : .collectionGroup)
        } else {
            // The documentation is a plain article
            return role(for: .article)
        }
    }

    /// Returns a metadata role for the given documentation node kind.
    func role(for kind: DocumentationNode.Kind) -> RenderMetadata.Role {
        switch kind {
        // A list of special node kinds to map to predefined roles
        case .article: return .article
        case .chapter: return .collectionGroup
        case .collection: return .collection
        case .collectionGroup: return .collectionGroup
        case .technology, .technologyOverview: return .overview
        case .landingPage: return .article
        case .module, .extendedModule: return .collection
        case .onPageLandmark: return .pseudoSymbol
        case .root: return .collection
        case .sampleCode: return .sampleCode
        case .tutorialArticle: return .article
        case .tutorial: return .tutorial
        case .unknown: return .unknown
        case .volume: return .collectionGroup
        // All the remaining node kinds are symbols
        default: return .symbol
        }
    }
    
    // Generates a generic conformance section for the given reference.
    func conformanceSectionFor(_ reference: ResolvedTopicReference, collectedConstraints: [TopicReference: [SymbolGraph.Symbol.Swift.GenericConstraint]]) -> ConformanceSection? {
        guard let node = try? documentationContext.entity(with: reference),
            let symbol = node.symbol else {
            // Couldn't find the node for this reference
            return nil
        }
        
        // Render references can have either availability or conformance data
        var constraints: [SymbolGraph.Symbol.Swift.GenericConstraint] = []
        
        if let conformanceConstraints = collectedConstraints[.successfullyResolved(reference)], !conformanceConstraints.isEmpty {
            // Collected conformance constraints
            constraints = conformanceConstraints
        } else if let availabilityConstraints = (node.semantic as? Symbol)?.constraints, !availabilityConstraints.isEmpty {
            // Availability constraints
            constraints = availabilityConstraints
        } else {
            // No constraints for the given reference
            return nil
        }
        
        let isLeaf = SymbolReference.isLeaf(symbol)
        let parentName = documentationContext.parents(of: reference).first
            .flatMap { try? documentationContext.entity(with: $0) }
            .flatMap { $0?.symbol?.names.title }
        
        let options = ConformanceSection.ConstraintRenderOptions(
            isLeaf: isLeaf,
            parentName: parentName,
            selfName: symbol.names.title.components(separatedBy: .punctuationCharacters)[0])
        
        // This can still return `nil` if the constraints aren't render significant (aka always true constraints on `Self`)
        return ConformanceSection(constraints: constraints, options: options)
    }
    
    /// Given a node, returns if it's a beta documentation symbol or not.
    func isBeta(_ node: DocumentationNode) -> Bool {
        // We verify that this is a symbol with defined availability
        // and that we're feeding in a current set of platforms to the context.
        guard let symbol = node.semantic as? Symbol,
            let currentPlatforms = documentationContext.externalMetadata.currentPlatforms,
            !currentPlatforms.isEmpty,
            let symbolAvailability = symbol.availability else { return false }

        // Verify that if current platforms are in beta, they match the introduced version of the symbol
        for availability in symbolAvailability.availability {
            // If not available on this platform, skip to next platform.
            guard !availability.isUnconditionallyUnavailable, let introduced = availability.introducedVersion else {
                continue
            }
            
            // If we don't have introduced and current versions for the current platform
            // we can't tell if the symbol is beta.
            guard let name = availability.domain.map({ PlatformName(operatingSystemName: $0.rawValue) }),
                // Use the display name of the platform when looking up the current platforms
                // as we expect that form on the command line.
                let current = documentationContext.externalMetadata.currentPlatforms?[name.displayName] else {
                return false
            }

            // Verify that the current platform is in beta and the version number matches the introduced platform version.
            guard current.beta && introduced.isEqualToVersionTriplet(current.version) else {
                return false
            }
        }

        // If the code didn't return until now all requirements have been satisfied and it's a beta symbol.
        return true
    }

    /// Creates a render reference for the given topic reference.
    /// - Parameters:
    ///     - reference: A documentation node topic reference.
    ///     - overridingDocumentationNode: An optional overriding documentation node to create
    ///       the returned topic render reference from.
    ///
    ///       You should only provide an overriding documentation node in situations where a
    ///       full documentation build is not being performed (like when using a ``ConvertService``) and
    ///       the current ``DocumentationContext`` does not have a documentation node for
    ///       the given reference.
    ///
    /// - Returns: The rendered documentation node.
    func renderReference(for reference: ResolvedTopicReference, with overridingDocumentationNode: DocumentationNode? = nil, dependencies: inout RenderReferenceDependencies) -> TopicRenderReference {
        let resolver = LinkTitleResolver(context: documentationContext, source: reference.url)
        
        let titleVariants: DocumentationDataVariants<String>
        let kind: RenderNode.Kind
        var referenceRole: String?
        let node = try? overridingDocumentationNode ?? documentationContext.entity(with: reference)
        
        if let node = node, let resolvedTitle = resolver.title(for: node) {
            titleVariants = resolvedTitle
        } else if let anchorSection = documentationContext.nodeAnchorSections[reference] {
            // No need to continue, return a section topic reference
            return TopicRenderReference(
                identifier: RenderReferenceIdentifier(reference.absoluteString),
                title: anchorSection.title,
                abstract: [],
                url: urlGenerator.presentationURLForReference(reference, requireRelativeURL: true).absoluteString,
                kind: .section,
                estimatedTime: nil
            )
        } else if let topicGraphOnlyNode = documentationContext.topicGraph.nodeWithReference(reference) {
            // Some nodes are artificially inserted into the topic graph,
            // try resolving that way as a fallback after looking up `documentationCache`.
            titleVariants = .init(defaultVariantValue: topicGraphOnlyNode.title)
        } else {
            titleVariants = .init(defaultVariantValue: reference.absoluteString)
        }
        
        switch node?.kind {
        case .some(.tutorial):
            kind = .tutorial
            referenceRole = role(for: .tutorial).rawValue
        case .some(.tutorialArticle):
            kind = .article
            referenceRole = role(for: .tutorialArticle).rawValue
        case .some(.technology):
            kind = .overview
            referenceRole = role(for: .technology).rawValue
        case .some(.onPageLandmark):
            kind = .section
            referenceRole = role(for: .onPageLandmark).rawValue
        case .some(.sampleCode):
            kind = .article
            referenceRole = role(for: .sampleCode).rawValue
        case let nodeKind? where nodeKind.isSymbol:
            kind = .symbol
            referenceRole = role(for: nodeKind).rawValue
        case _ where node?.semantic is Article:
            kind = .article
            referenceRole = roleForArticle(node!.semantic as! Article, nodeKind: node!.kind).rawValue
        default:
            kind = .article
            referenceRole = role(for: .article).rawValue
        }
        
        let referenceURL = reference.absoluteString
        
        // Topic render references require the URLs to be relative, even if they're external.
        let presentationURL = urlGenerator.presentationURLForReference(reference, requireRelativeURL: true)
        
        var contentCompiler = RenderContentCompiler(context: documentationContext, bundle: bundle, identifier: reference)
        let abstractContent: VariantCollection<[RenderInlineContent]>
        
        var abstractedNode = node
        if kind == .section {
            // Sections don't have their own abstract so take the one of the container symbol.
            let containerReference = ResolvedTopicReference(
                bundleIdentifier: reference.bundleIdentifier,
                path: reference.path,
                sourceLanguages: reference.sourceLanguages
            )
            abstractedNode = try? documentationContext.entity(with: containerReference)
        }
        
        func extractAbstract(from paragraph: Paragraph?) -> [RenderInlineContent] {
            if let abstract = paragraph
                ?? abstractedNode.map({
                    DocumentationMarkup(markup: $0.markup, parseUpToSection: .abstract)
                })?.abstractSection?.paragraph,
                let renderedContent = contentCompiler.visit(abstract).first,
                case let .paragraph(p)? = renderedContent as? RenderBlockContent
            {
                return p.inlineContent
            } else {
                return []
            }
        }
        
        if let symbol = (abstractedNode?.semantic as? Symbol) {
            abstractContent = VariantCollection<[RenderInlineContent]>(
                from: symbol.abstractVariants
            ) { _, abstract in
                extractAbstract(from: abstract)
            } ?? .init(defaultValue: [])
        } else {
            abstractContent = .init(defaultValue: extractAbstract(from: (abstractedNode?.semantic as? Abstracted)?.abstract))
        }
        
        // Collect the reference dependencies.
        dependencies.topicReferences = Array(contentCompiler.collectedTopicReferences)
        dependencies.linkReferences = Array(contentCompiler.linkReferences.values)

        let isRequired = (node?.semantic as? Symbol)?.isRequired ?? false

        let estimatedTime = (node?.semantic as? Timed)?.durationMinutes.flatMap(formatEstimatedDuration(minutes:))

        var renderReference = TopicRenderReference(
            identifier: .init(referenceURL),
            titleVariants: VariantCollection<String>(from: titleVariants) ?? .init(defaultValue: ""),
            abstractVariants: abstractContent,
            url: presentationURL.absoluteString,
            kind: kind,
            required: isRequired,
            role: referenceRole,
            estimatedTime: estimatedTime
        )
        
        renderReference.images = node?.metadata?.pageImages.compactMap { pageImage -> TopicImage? in
            guard let image = TopicImage(
                pageImage: pageImage,
                with: documentationContext,
                in: reference
            ) else {
                return nil
            }
            
            guard let asset = documentationContext.resolveAsset(
                named: image.identifier.identifier,
                in: reference
            ) else {
                return nil
            }
            
            dependencies.imageReferences.append(
                ImageReference(
                    identifier: image.identifier,
                    altText: pageImage.alt,
                    imageAsset: asset
                )
            )
            
            return image
        } ?? []

        // Store the symbol's display name if present in the render reference
        renderReference.fragmentsVariants = node.flatMap(subHeadingFragments) ?? .init(defaultValue: [])
        // Store the symbol's navigator title if present in the render reference
        renderReference.navigatorTitleVariants = node.flatMap(navigatorFragments) ?? .init(defaultValue: [])
        
        // Omit the navigator title if it's identical to the fragments
        if renderReference.navigatorTitle == renderReference.fragments {
            renderReference.navigatorTitle = nil
        }
        
        // Number of default implementations provided
        if let count = (node?.semantic as? Symbol)?.defaultImplementations.implementations.count, count > 0 {
            renderReference.defaultImplementationCount = count
        }
        
        // If the topic is beta on all platforms
        renderReference.isBeta = node.map(isBeta) ?? false
        
        // If the topic is deprecated
        if let symbol = node?.semantic as? Symbol,
           (symbol.isDeprecated == true || symbol.deprecatedSummary != nil) {
            renderReference.isDeprecated = true
        }
        
        if kind == .section {
            renderReference.type = .section
        }
        renderReference.tags = tags(for: reference)

        return renderReference
    }
    
    /// Render tags for a given node.
    ///  - Returns: An optional list of tags, if there are no tags associated
    ///    with the given reference returns `nil`.
    func tags(for reference: ResolvedTopicReference) -> [RenderNode.Tag]? {
        var result = [RenderNode.Tag]()
        
        /// Add an SPI tag to SPI symbols.
        if let node = try? documentationContext.entity(with: reference),
            let symbol = node.semantic as? Symbol,
            symbol.isSPI {
            result.append(.spi)
        }
        
        guard !result.isEmpty else { return nil }
        return result
    }
    
    /// A value type to store an automatically curated task group and its sorting index.
    public struct ReferenceGroup: Codable {
        public let title: String?
        public let references: [ResolvedTopicReference]
    }

    /// Returns the task groups for a given node reference.
    func taskGroups(for reference: ResolvedTopicReference) -> [ReferenceGroup]? {
        guard let node = try? documentationContext.entity(with: reference) else { return nil }
        
        let groups: [TaskGroup]?
        switch node.semantic {
        case let symbol as Symbol:
            groups = symbol.topics?.taskGroups
        case let article as Article:
            groups = article.topics?.taskGroups
        default:
            // No other semantic entities have topic groups.
            return nil
        }
        
        guard let taskGroups = groups, !taskGroups.isEmpty else { return nil }

        // Find the linking group
        var resolvedTaskGroups = [ReferenceGroup]()

        for group in taskGroups {
            let resolvedReferences = group.links.compactMap { link -> ResolvedTopicReference? in
                guard let destination = link.destination.flatMap(URL.init(string:)),
                    destination.scheme != nil,
                    let linkHost = destination.host else {
                    // Probably an unresolved/invalid URL, ignore.
                    return nil
                }
                
                // For external links, verify they've resolved successfully and return `nil` otherwise.
                if linkHost != reference.bundleIdentifier {
                    let externalReference = ResolvedTopicReference(
                        bundleIdentifier: linkHost,
                        path: destination.path,
                        sourceLanguages: node.availableSourceLanguages
                    )
                    if documentationContext.externallyResolvedSymbols.contains(externalReference) {
                        return externalReference
                    }
                    return nil
                }
                return ResolvedTopicReference(
                    bundleIdentifier: reference.bundleIdentifier,
                    path: destination.path,
                    sourceLanguages: node.availableSourceLanguages
                )
            }
            
            resolvedTaskGroups.append(
                ReferenceGroup(title: group.heading?.plainText, references: resolvedReferences)
            )
        }
        
        return resolvedTaskGroups
    }
}

extension DocumentationContentRenderer {

    /// Node translator extension with some exceptions to apply to Swift symbols.
    enum Swift {
        
        /// Applies Swift symbol navigator titles rules to a title.
        /// Will strip the typeIdentifier's precise identifier.
        static func navigatorTitle(for tokens: [DeclarationRenderSection.Token], symbolTitle: String) -> [DeclarationRenderSection.Token] {
            return tokens.mapNameFragmentsToIdentifierKind(matching: symbolTitle)
        }

        private static let initKeyword = DeclarationRenderSection.Token(text: "init", kind: .keyword)
        private static let initIdentifier = DeclarationRenderSection.Token(text: "init", kind: .identifier)
        
        /// Applies Swift symbol subheading rules to a subheading.
        /// Will preserve the typeIdentifier's precise identifier.
        static func subHeading(for tokens: [DeclarationRenderSection.Token], symbolTitle: String, symbolKind: String) -> [DeclarationRenderSection.Token] {
            var tokens = tokens
            
            // 1. Map typeIdenifier tokens to identifier tokens where applicable
            tokens = tokens.mapNameFragmentsToIdentifierKind(matching: symbolTitle)
            
            
            // 2. Map the first found "keyword=init" to an "identifier" kind to enable syntax highlighting.
            let parsedKind = SymbolGraph.Symbol.KindIdentifier(identifier: symbolKind)
            if parsedKind == SymbolGraph.Symbol.KindIdentifier.`init`,
                let initIndex = tokens.firstIndex(of: initKeyword) {
                tokens[initIndex] = initIdentifier
            }
            
            return tokens
        }
    }

}

private extension Array where Element == DeclarationRenderSection.Token {
    // Replaces kind "typeIdentifier" with "identifier" if the fragments matches the pattern:
    // [keyword=_] [text=" "] [(typeIdentifier|identifier)=Name_0] ( [text="."] [typeIdentifier=Name_i] )*
    // where the Name_i from typeIdentifier tokens joined with separator "." equal the `symbolTitle`
    func mapNameFragmentsToIdentifierKind(matching symbolTitle: String) -> Self {
        // Check that the first 3 tokens are: [keyword=_] [text=" "] [(typeIdentifier|identifier)=_]
        guard count >= 3,
              self[0].kind == .keyword,
              self[1].kind == .text, self[1].text == " ",
              self[2].kind == .typeIdentifier || self[2].kind == .identifier
        else { return self }
        
        // If the first named token belongs to an identifier, this is a module prefix.
        // We store it for later comparison with the `combinedName`
        let modulePrefix = self[2].kind == .identifier ? self[2].text + "." : ""
        
        var combinedName = self[2].text
        
        var finalTypeIdentifierIndex = 2
        var remainder = self.dropFirst(3)
        // Continue checking for pairs of "." text tokens and typeIdentifier tokens: ( [text="."] [typeIdentifier=Name_i] )*
        while remainder.count >= 2 {
            let separator = remainder.removeFirst()
            guard separator.kind == .text, separator.text == "." else { break }
            let next = remainder.removeFirst()
            guard next.kind == .typeIdentifier else { break }
            
            finalTypeIdentifierIndex += 2
            combinedName += "." + next.text
        }
        
        guard combinedName == modulePrefix + symbolTitle else { return self }
        
        var mapped = self
        for index in stride(from: 2, to: finalTypeIdentifierIndex+1, by: 2) {
            let token = self[index]
            mapped[index] = DeclarationRenderSection.Token(
                text: token.text,
                kind: .identifier,
                preciseIdentifier: token.preciseIdentifier
            )
        }
        return mapped
    }
}
