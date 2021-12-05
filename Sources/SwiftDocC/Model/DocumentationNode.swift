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

/// A documentation node holds all the information about a documentation entity's content.
///
/// Information about relationships between documentation entities can be retrieved from the ``DocumentationContext``. The documentation context is also used
/// to look up nodes by their unique ``reference``.
public struct DocumentationNode {
    /// The unique reference to the node.
    public var reference: ResolvedTopicReference
    
    /// The type of node.
    public var kind: Kind
    
    /// The programming language in which the node is relevant.
    public var sourceLanguage: SourceLanguage
    
    /// All the languages in which the node is available.
    public var availableSourceLanguages: Set<SourceLanguage>
    
    /// The names of the platforms for which the node is available.
    public var platformNames: Set<String>?
    
    /// The name of the node.
    public var name: Name
    
    /// The markup that makes up the content of this documentation node.
    ///
    /// After the ``semantic`` object is created, consulting this property is likely incorrect because
    /// it does not include information such as resolved links.
    public var markup: Markup
    
    /// The parsed documentation structure that's described by the documentation content of this documentation node.
    public var semantic: Semantic!
    
    /// The symbol that backs this node if it's backed by a symbol, otherwise `nil`.
    public var symbol: SymbolGraph.Symbol?

    /// The unified symbol data that backs this node, if it's backed by a symbol; otherwise `nil`.
    public var unifiedSymbol: UnifiedSymbolGraph.Symbol?

    /// A discrete unit of documentation
    struct DocumentationChunk {
        /// The source of a documentation chunk: either a documentation extension file or an in-source documentation comment.
        enum Source {
            /// The documentation comes from a documentation extension file.
            case documentationExtension
            /// The documentation comes from an in-source documentation comment.
            case sourceCode(location: SymbolGraph.Symbol.Location?)
        }

        let source: Source
        let markup: Markup
    }

    /// Where the documentation for the current node came from: source code or documentation extension.
    ///
    /// Documentation can exist in source code comments and extension files. This property stores each
    /// piece of documentation and indicates where the documentation originated. All of the chunks are
    /// combined to form the complete documentation for this node and stored in the ``DocumentationNode/markup``
    /// property.
    var docChunks: [DocumentationChunk]
    
    /// Linkable in-content sections.
    var anchorSections = [AnchorSection]()
    
    /// Collects any sections in the node content that could be
    /// linked to from other nodes' content.
    private mutating func updateAnchorSections() {
        // Scrub article discussion headings.
        var discussion: DiscussionSection?
        switch semantic {
            case let article as Article:
                discussion = article.discussion
            case let symbol as Symbol:
                discussion = symbol.discussion
            default: break
        }
        
        if let discussion = discussion {
            for child in discussion.content {
                // For any H2/H3 sections found in the topic's discussion
                // create an `AnchorSection` and add it to `anchorSections`
                // so we can index all anchors found in the bundle for link resolution.
                if let heading = child as? Heading, heading.level > 1, heading.level < 4 {
                    anchorSections.append(
                        AnchorSection(reference: reference.withFragment(urlReadableFragment(heading.plainText)), title: heading.plainText)
                    )
                }
            }
        }
    }
    
    /// Initializes a documentation node with all its initial values.
    ///
    /// - Parameters:
    ///   - reference: The unique reference to the node.
    ///   - kind: The type of node.
    ///   - sourceLanguage: The programming language in which the node is relevant.
    ///   - availableSourceLanguages: All the languages in which the node is available.
    ///   - name: The name of the node.
    ///   - markup: The markup that makes up the content for the node.
    ///   - semantic: The parsed documentation structure that's described by the documentation content.
    ///   - platformNames: The names of the platforms for which the node is available.
    public init(reference: ResolvedTopicReference, kind: Kind, sourceLanguage: SourceLanguage, availableSourceLanguages: Set<SourceLanguage>? = nil, name: Name, markup: Markup, semantic: Semantic?, platformNames: Set<String>? = nil) {
        self.reference = reference
        self.kind = kind
        self.sourceLanguage = sourceLanguage
        self.availableSourceLanguages = availableSourceLanguages ?? Set([sourceLanguage])
        self.name = name
        self.markup = markup
        self.semantic = semantic
        self.symbol = nil
        self.platformNames = platformNames
        self.docChunks = [DocumentationChunk(source: .sourceCode(location: nil), markup: markup)]
        updateAnchorSections()
    }

    /// Initializes a node without parsing its documentation source.
    ///
    /// - Parameters:
    ///   - reference: The unique reference to the node.
    ///   - symbol: The symbol to create a documentation node for.
    ///   - platformName: The name of the platforms for which the node is available.
    ///   - moduleName: The name of the module that the symbol belongs to.
    init(reference: ResolvedTopicReference, unifiedSymbol: UnifiedSymbolGraph.Symbol, platformName: String?, moduleName: String, bystanderModules: [String]? = nil) {
        self.reference = reference
        
        guard reference.sourceLanguage == .swift || FeatureFlags.current.isExperimentalObjectiveCSupportEnabled else {
            fatalError("""
                Only Swift symbols are currently supported. \
                This initializer is only called with symbols from the symbol graph, which currently only supports Swift.
                """
            )
        }
        
        guard let symbol = unifiedSymbol.defaultSymbol else {
            fatalError("Unexpectedly failed to get 'defaultSymbol' from 'unifiedSymbol'.")
        }
        
        self.kind = Self.kind(for: symbol)
        self.sourceLanguage = reference.sourceLanguage
        self.name = .symbol(declaration: .init([.plain(symbol.names.title)]))
        self.symbol = symbol
        self.unifiedSymbol = unifiedSymbol
        
        self.markup = Document()
        self.docChunks = []
        self.tags = (returns: [], throws: [], parameters: [])
        
        let symbolAvailability = symbol.mixins[SymbolGraph.Symbol.Availability.mixinKey] as? SymbolGraph.Symbol.Availability
        var languages = Set([reference.sourceLanguage])
        var operatingSystemName = platformName.map({ Set([$0]) }) ?? []
        
        let availabilityDomains = symbolAvailability?.availability.compactMap({ $0.domain?.rawValue })
        if let (sourceLanguages, otherDomains) = availabilityDomains?.categorize(where: SourceLanguage.init(knownLanguageName:)) {
            languages.formUnion(sourceLanguages)
            operatingSystemName.formUnion(otherDomains)
        }
        platformNames = Set(operatingSystemName.map { PlatformName(operatingSystemName: $0).rawValue })
        availableSourceLanguages = languages
        
        let extendedModule = (symbol.mixins[SymbolGraph.Symbol.Swift.Extension.mixinKey] as? SymbolGraph.Symbol.Swift.Extension)?.extendedModule

        let sema = Symbol(
            kindVariants: .init(swiftVariant: symbol.kind),
            titleVariants: .init(swiftVariant: symbol.names.title),
            subHeadingVariants: .init(swiftVariant: symbol.names.subHeading),
            navigatorVariants: .init(swiftVariant: symbol.names.navigator),
            roleHeadingVariants: .init(swiftVariant: symbol.kind.displayName),
            platformNameVariants: .init(swiftVariant: platformName.map(PlatformName.init(operatingSystemName:))),
            moduleNameVariants: .init(swiftVariant: moduleName),
            extendedModuleVariants: .init(swiftVariant: extendedModule),
            externalIDVariants: .init(swiftVariant: symbol.identifier.precise),
            accessLevelVariants: .init(swiftVariant: symbol.accessLevel.rawValue),
            availabilityVariants: .init(swiftVariant: symbolAvailability),
            deprecatedSummaryVariants: .init(swiftVariant: nil),
            mixinsVariants: .init(swiftVariant: symbol.mixins),
            relationshipsVariants: .init(swiftVariant: RelationshipsSection()),
            abstractSectionVariants: .init(swiftVariant: AbstractSection(paragraph: .init([Text("Placeholder Abstract")]))),
            discussionVariants: .init(swiftVariant: nil),
            topicsVariants: .init(swiftVariant: nil),
            seeAlsoVariants: .init(swiftVariant: nil),
            returnsSectionVariants: .init(swiftVariant: nil),
            parametersSectionVariants: .init(swiftVariant: nil),
            redirectsVariants: .init(swiftVariant: nil),
            bystanderModuleNamesVariants: .init(swiftVariant: bystanderModules)
        )

        try! sema.mergeDeclarations(unifiedSymbol: unifiedSymbol)

        self.semantic = sema
    }

    /// Given an optional article updates the node's content.
    /// - Parameters:
    ///   - article: An optional documentation extension article.
    ///   - engine: A diagnostics engine.
    mutating func initializeSymbolContent(article: Article?, engine: DiagnosticEngine) {
        precondition(symbol != nil, "You can only call initializeSymbolContent() on a symbol node.")
        let (markup, docChunks) = Self.contentFrom(symbol: symbol!, article: article, engine: engine)
        
        self.markup = markup
        self.docChunks = docChunks

        // Parse the structured markup
        let markupModel = DocumentationMarkup(markup: markup)
        
        let symbolAvailability = symbol!.mixins[SymbolGraph.Symbol.Availability.mixinKey] as? SymbolGraph.Symbol.Availability
        
        // Use a deprecation summary from the symbol docs or article content.
        var deprecated: DeprecatedSection? = markupModel.deprecation.map { DeprecatedSection.init(content: $0.elements) }

        // When deprecation is not authored explicitly, try using a deprecation message from annotation.
        if deprecated == nil, let symbolAvailability = symbolAvailability {
            let availabilityData = AvailabilityParser(symbolAvailability)
            deprecated = availabilityData.deprecationMessage().map(DeprecatedSection.init(text:))
        }

        // Merge in the symbol documentation content
        let semantic = self.semantic as! Symbol
        
        // Symbol is a by-reference type so we're updating the original `semantic` property instance.
        semantic.abstractSection = markupModel.abstractSection
        semantic.discussion = markupModel.discussionSection
        semantic.topics = markupModel.topicsSection
        semantic.seeAlso = markupModel.seeAlsoSection
        semantic.deprecatedSummary = deprecated
        semantic.redirects = article?.redirects
        
        if let returns = markupModel.discussionTags?.returns, !returns.isEmpty {
            semantic.returnsSection = ReturnsSection(content: returns[0].contents)
        }
        
        if let parameters = markupModel.discussionTags?.parameters, !parameters.isEmpty {
            semantic.parametersSection = ParametersSection(parameters: parameters)
        }
        
        updateAnchorSections()
    }
    
    /// Given a symbol and an optional article returns documentation content.
    /// - Parameters:
    ///   - symbol: A symbol graph symbol.
    ///   - article: An optional article with documentation content.
    ///   - engine: A diagnostics engine to use for problems found while parsing content.
    /// - Returns: The prepared node documentation content.
    static func contentFrom(symbol: SymbolGraph.Symbol, article: Article?, engine: DiagnosticEngine)
        -> (markup: Markup, docChunks: [DocumentationChunk]) {
        
        let markup: Markup
        let docChunks: [DocumentationChunk]
        
        switch (article?.markup.flatMap{_ in article}, symbol.docComment) {
        case (nil, nil):
            markup = Document()
            docChunks = [DocumentationChunk(source: .sourceCode(location: nil), markup: markup)]
            
        case (let article?, nil),
             (let article?, _) where article.metadata?.documentationOptions?.behavior == .override:
            markup = article.markup!
            docChunks = [DocumentationChunk(source: .documentationExtension, markup: markup)]
            
        case (_, let docComment?):
            let docCommentString = docComment.lines.map { $0.text }.joined(separator: "\n")
            let docCommentMarkup = Document(parsing: docCommentString, options: [.parseBlockDirectives, .parseSymbolLinks])
            
            let docCommentDirectives = docCommentMarkup.children.compactMap({ $0 as? BlockDirective })
            if !docCommentDirectives.isEmpty {
                let location = (symbol.mixins[SymbolGraph.Symbol.Location.mixinKey] as? SymbolGraph.Symbol.Location)?.url()
                
                for comment in docCommentDirectives {
                    let range = docCommentMarkup.child(at: comment.indexInParent)?.range
                    
                    var diagnostic = Diagnostic(
                        source: location,
                        severity: .warning,
                        range: range,
                        identifier: "org.swift.docc.UnsupportedDocCommentDirective",
                        summary: "Directives are not supported in symbol source documentation",
                        explanation: "Found \(comment.name.singleQuoted) in \(symbol.absolutePath.singleQuoted)"
                    )
                    
                    if let offset = docComment.lines.first?.range {
                        diagnostic = diagnostic.offsetedWithRange(offset)
                    }
                    
                    engine.emit(Problem(diagnostic: diagnostic, possibleSolutions: []))
                }
            }

            var docs: [DocumentationChunk] = [DocumentationChunk(source: .sourceCode(location: symbol.mixins[SymbolGraph.Symbol.Location.mixinKey] as? SymbolGraph.Symbol.Location), markup: docCommentMarkup)]

            if let articleMarkup = article?.markup {
                // An `Article` always starts with a level 1 heading (and return `nil` if that's not the first child).
                // For documentation extension files, this heading is a link to the symbol—which isn't part of the content—so it is ignored.
                let articleChildren = articleMarkup.children.dropFirst().compactMap { $0 as? BlockMarkup }
                docs.append(DocumentationChunk(source: .documentationExtension, markup: articleMarkup))
                markup = Document(Array(docCommentMarkup.blockChildren) + articleChildren)
            } else {
                markup = docCommentMarkup
            }
            docChunks = docs
        }
        
        return (markup: markup, docChunks: docChunks)
    }

    /// Returns a documentation node kind for the given symbol kind.
    /// - Parameter symbol: A symbol graph symbol.
    /// - Returns: A documentation node kind.
    static func kind(for symbol: SymbolGraph.Symbol) -> Kind {
        return Self.kind(forKind: symbol.kind.identifier)
    }

    static func kind(forKind symbolKind: SymbolGraph.Symbol.KindIdentifier) -> Kind {
        switch symbolKind  {
        case .`associatedtype`: return .associatedType
        case .`class`: return .class
        case .`deinit`: return .deinitializer
        case .`enum`: return .enumeration
        case .`case`: return .enumerationCase
        case .`func`: return .function
        case .`operator`: return .operator
        case .`init`: return .initializer
        case .`method`: return .instanceMethod
        case .`property`: return .instanceProperty
        case .`protocol`: return .protocol
        case .`struct`: return .structure
        case .`subscript`: return .instanceSubscript
        case .`typeMethod`: return .typeMethod
        case .`typeProperty`: return .typeProperty
        case .`typeSubscript`: return .typeSubscript
        case .`typealias`: return .typeAlias
        case .`var`: return .globalVariable

        case .module: return .module
        case .unknown: return .unknown
        }
    }

    /// Initializes a documentation node to represent a symbol from a symbol graph.
    ///
    /// - Parameters:
    ///   - reference: The unique reference to the node.
    ///   - symbol: The symbol to create a documentation node for.
    ///   - platformNames: The names of the platforms for which the node is available.
    ///   - moduleName: The name of the module that the symbol belongs to.
    ///   - article: The documentation extension content for this symbol.
    ///   - engine:The engine that collects any problems encountered during initialization.
    ///   - bystanderModules: An optional list of cross-import module names.
    public init(reference: ResolvedTopicReference, symbol: SymbolGraph.Symbol, platformName: String?, moduleName: String, article: Article?, engine: DiagnosticEngine, bystanderModules: [String]? = nil) {
        self.reference = reference
        
        guard reference.sourceLanguage == .swift else {
            fatalError("""
                Only Swift symbols are currently supported. \
                This initializer is only called with symbols from the symbol graph, which currently only supports Swift.
                """
            )
        }
        self.kind = Self.kind(for: symbol)
        self.sourceLanguage = reference.sourceLanguage
        self.name = .symbol(declaration: .init([.plain(symbol.names.title)]))
        self.symbol = symbol
        
        // Prefer content sections coming from an article (documentation extension file)
        var deprecated: DeprecatedSection?
        
        let (markup, docChunks) = Self.contentFrom(symbol: symbol, article: article, engine: engine)
        self.markup = markup
        self.docChunks = docChunks
        
        let symbolAvailability = symbol.mixins[SymbolGraph.Symbol.Availability.mixinKey] as? SymbolGraph.Symbol.Availability
        
        var languages = Set([reference.sourceLanguage])
        var operatingSystemName = platformName.map({ Set([$0]) }) ?? []
        
        let availabilityDomains = symbolAvailability?.availability.compactMap({ $0.domain?.rawValue })
        if let (sourceLanguages, otherDomains) = availabilityDomains?.categorize(where: SourceLanguage.init(knownLanguageName:)) {
            languages.formUnion(sourceLanguages)
            operatingSystemName.formUnion(otherDomains)
        }
        platformNames = Set(operatingSystemName.map { PlatformName(operatingSystemName: $0).rawValue })
        availableSourceLanguages = languages
        
        if let article = article {
            // Prefer authored deprecation summary over docs.
            deprecated = article.deprecationSummary.map { DeprecatedSection.init(content: $0.elements) }
        }
        if deprecated == nil, let symbolAvailability = symbolAvailability {
            let availabilityData = AvailabilityParser(symbolAvailability)
            deprecated = availabilityData.deprecationMessage().map(DeprecatedSection.init(text:))
        }
        
        // Parse the structured markup
        let markupModel = DocumentationMarkup(markup: markup)

        self.semantic = Symbol(
            kindVariants: .init(swiftVariant: symbol.kind),
            titleVariants: .init(swiftVariant: symbol.names.title),
            subHeadingVariants: .init(swiftVariant: symbol.names.subHeading),
            navigatorVariants: .init(swiftVariant: symbol.names.navigator),
            roleHeadingVariants: .init(swiftVariant: symbol.kind.displayName),
            platformNameVariants: .init(swiftVariant: platformName.map(PlatformName.init(operatingSystemName:))),
            moduleNameVariants: .init(swiftVariant: moduleName),
            externalIDVariants: .init(swiftVariant: symbol.identifier.precise),
            accessLevelVariants: .init(swiftVariant: symbol.accessLevel.rawValue),
            availabilityVariants: .init(swiftVariant: symbolAvailability),
            deprecatedSummaryVariants: .init(swiftVariant: deprecated),
            mixinsVariants: .init(swiftVariant: symbol.mixins),
            relationshipsVariants: .init(swiftVariant: RelationshipsSection()),
            abstractSectionVariants: .init(swiftVariant: markupModel.abstractSection),
            discussionVariants: .init(swiftVariant: markupModel.discussionSection),
            topicsVariants: .init(swiftVariant: markupModel.topicsSection),
            seeAlsoVariants: .init(swiftVariant: markupModel.seeAlsoSection),
            returnsSectionVariants: .init(swiftVariant: markupModel.discussionTags.flatMap({ $0.returns.isEmpty ? nil : ReturnsSection(content: $0.returns[0].contents) })),
            parametersSectionVariants: .init(swiftVariant: markupModel.discussionTags.flatMap({ $0.parameters.isEmpty ? nil : ParametersSection(parameters: $0.parameters) })),
            redirectsVariants: .init(swiftVariant: article?.redirects),
            bystanderModuleNamesVariants: .init(swiftVariant: bystanderModules)
        )
        
        updateAnchorSections()
    }
    
    public enum Error: DescribedError {
        case missingMarkup
        
        public var errorDescription: String {
            switch self {
                case .missingMarkup: return "Markup not found."
            }
        }
    }
    
    /// Initializes a documentation node to represent an article.
    ///
    /// - Parameters:
    ///   - reference: The unique reference to the node.
    ///   - article: The documentation extension content for this symbol.
    ///   - problems: A mutable collection of problems to update with any problem encountered while initializing the node.
    init(reference: ResolvedTopicReference, article: Article) throws {
        guard let articleMarkup = article.markup else {
            throw Error.missingMarkup
        }
        
        self.reference = reference
        self.kind = .article
        self.semantic = article
        self.sourceLanguage = reference.sourceLanguage
        self.name = .conceptual(title: article.title?.title ?? "")
        self.availableSourceLanguages = [reference.sourceLanguage]
        self.docChunks = [DocumentationChunk(source: .documentationExtension, markup: articleMarkup)]
        self.markup = articleMarkup
        
        updateAnchorSections()
    }

    /// The collection of parsed callout tags for return values, thrown errors, and parameters.
    ///
    /// When the symbol's markup contains callout tags like this:
    /// ```
    /// - Parameter name: Description of the name parameter.
    /// - Throws: Description of potential errors.
    /// - Returns: Description of the return value.
    /// ```
    /// That markup is parsed into collections of ``Parameter`` values, ``Throw`` values, and ``Return`` values.
    ///
    /// The markup for the callout tags is excluded from the markup for the ``DiscussionSection``.
    public typealias Tags = (returns: [Return], throws: [Throw], parameters: [Parameter])
    
    /// Callout tags found in the symbol's markup.
    ///
    /// These tags contain information about the symbol's return values, potential errors, and parameters.
    public var tags: Tags = (returns: [], throws: [], parameters: [])
}
