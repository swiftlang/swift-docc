/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
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
    
    /// All of the traits that make up the different variants of this node.
    public var availableVariantTraits: Set<DocumentationDataVariantsTrait> {
        return Set(
            availableSourceLanguages
                .map(\.id)
                .map(DocumentationDataVariantsTrait.init(interfaceLanguage:))
        )
    }
    
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
    
    /// If true, the node was created implicitly and should not generally be rendered as a page of documentation.
    public var isVirtual: Bool
    
    /// The authored options for this node.
    ///
    /// Allows for control of settings such as automatic see also generation.
    public var options: Options?

    /// Authored metadata for the node.
    ///
    /// Documentation authors can add metadata to a page using the ``Metadata`` directive.
    public var metadata: Metadata?

    /// A discrete unit of documentation
    struct DocumentationChunk {
        /// The source of a documentation chunk: either a documentation extension file or an in-source documentation comment.
        enum Source {
            /// The documentation comes from a documentation extension file.
            case documentationExtension
            /// The documentation comes from an in-source documentation comment.
            case sourceCode(location: SymbolGraph.Symbol.Location?, offset: SymbolGraph.LineList.SourceRange?)
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
    
    /// Returns information about the node's in-source documentation comment chunk, or `nil` if the node doesn't have an in-source documentation chunk.
    var inSourceDocumentationChunk: (url: URL?, offset: SymbolGraph.LineList.SourceRange?)? {
        for docChunk in docChunks {
            guard case .sourceCode(let location, let offset) = docChunk.source else { continue }
            
            return (url: location?.url, offset: offset)
        }
        return nil
    }
    
    /// Linkable in-content sections.
    var anchorSections = [AnchorSection]()
    
    /// Collects any sections in the node content that could be
    /// linked to from other nodes' content.
    private mutating func updateAnchorSections() {
        // Scrub article discussion headings.
        let discussionSections: [DiscussionSection]
        if let discussion = (semantic as? Article)?.discussion {
            discussionSections = [discussion]
        } else if let discussionVariants = (semantic as? Symbol)?.discussionVariants {
            discussionSections = discussionVariants.allValues.map(\.variant)
        } else {
            discussionSections = []
        }
        
        anchorSections.removeAll()
        var seenAnchorTitles = Set<String>()
        
        func addAnchorSection(title: String) {
            // To preserve the order of headings and task groups in the content, we use *both* a `Set` and
            // an `Array` to ensure unique titles and to accumulate the linkable anchor section elements.
            guard !title.isEmpty, !seenAnchorTitles.contains(title) else { return }
            seenAnchorTitles.insert(title)
            anchorSections.append(
                AnchorSection(reference: reference.withFragment(title), title: title)
            )
        }
        
        for discussion in discussionSections {
            for child in discussion.content {
                if let heading = child as? Heading, heading.level > 1 {
                    addAnchorSection(title: heading.plainText)
                }
            }
        }
        
        let taskGroups: [TaskGroup]?
        if let article = semantic as? Article {
            taskGroups = article.topics?.taskGroups
        } else if let symbol = semantic as? Symbol {
            taskGroups = symbol.topics?.taskGroups
        } else {
            taskGroups = nil
        }
        
        for taskGroup in taskGroups ?? [] {
            addAnchorSection(title: taskGroup.heading?.plainText ?? "Topics")
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
    ///   - isVirtual: `true` if the node represents a virtual element that doesn't represent a rendered page of documentation, `false` otherwise.
    public init(reference: ResolvedTopicReference, kind: Kind, sourceLanguage: SourceLanguage, availableSourceLanguages: Set<SourceLanguage>? = nil, name: Name, markup: Markup, semantic: Semantic?, platformNames: Set<String>? = nil, isVirtual: Bool = false) {
        self.reference = reference
        self.kind = kind
        self.sourceLanguage = sourceLanguage
        self.availableSourceLanguages = availableSourceLanguages ?? Set([sourceLanguage])
        self.name = name
        self.markup = markup
        self.semantic = semantic
        self.symbol = nil
        self.platformNames = platformNames
        self.docChunks = [DocumentationChunk(source: .sourceCode(location: nil, offset: nil), markup: markup)]
        self.isVirtual = isVirtual
        
        if let article = semantic as? Article {
            self.options = article.options[.local]
            self.metadata = article.metadata
        } else {
            self.options = nil
            self.metadata = nil
        }
        
        updateAnchorSections()
    }

    /// Initializes a node without parsing its documentation source.
    ///
    /// - Parameters:
    ///   - reference: The unique reference to the node.
    ///   - unifiedSymbol: The symbol to create a documentation node for.
    ///   - moduleData: The module that the symbol belongs to.
    ///   - moduleName: The name of the module that the symbol belongs to.
    init(reference: ResolvedTopicReference, unifiedSymbol: UnifiedSymbolGraph.Symbol, moduleData: SymbolGraph.Module, moduleReference: ResolvedTopicReference) {
        self.reference = reference
        
        guard let defaultSymbol = unifiedSymbol.defaultSymbol else {
            fatalError("Unexpectedly failed to get 'defaultSymbol' from 'unifiedSymbol'.")
        }
        
        self.kind = Self.kind(for: defaultSymbol)
        self.sourceLanguage = reference.sourceLanguage
        self.name = .symbol(name: defaultSymbol.names.title)
        self.symbol = defaultSymbol
        self.unifiedSymbol = unifiedSymbol
        self.isVirtual = moduleData.isVirtual
        
        self.markup = Document()
        self.docChunks = []
        self.tags = (returns: [], throws: [], parameters: [])

        let platformName = moduleData.platform.name
        
        let symbolAvailabilityVariants = DocumentationDataVariants(
            symbolData: unifiedSymbol.mixins,
            platformName: platformName
        ) { mixins in
            mixins[SymbolGraph.Symbol.Availability.mixinKey] as? SymbolGraph.Symbol.Availability
        }
        
        let endpointVariants = DocumentationDataVariants(
            symbolData: unifiedSymbol.mixins,
            platformName: platformName
        ) { mixins -> HTTPEndpointSection? in
            if let endpoint = mixins[SymbolGraph.Symbol.HTTP.Endpoint.mixinKey] as? SymbolGraph.Symbol.HTTP.Endpoint {
                return HTTPEndpointSection(endpoint: endpoint)
            }
            return nil
        }

        let overloadVariants = DocumentationDataVariants(
            swiftVariant: unifiedSymbol.unifiedOverloadData.map { overloadData in
                Symbol.Overloads(references: [], displayIndex: overloadData.overloadGroupIndex)
            })

        var languages = Set([reference.sourceLanguage])
        var operatingSystemName = platformName.map({ Set([$0]) }) ?? []
        
        for (_, symbolAvailability) in symbolAvailabilityVariants.allValues {
            let (sourceLanguages, otherDomains) = symbolAvailability.availability
                .compactMap({ $0.domain?.rawValue })
                .categorize(where: SourceLanguage.init(knownLanguageName:))
            
            languages.formUnion(sourceLanguages)
            operatingSystemName.formUnion(otherDomains)
        }
        
        self.platformNames = Set(
            operatingSystemName.map { name in
                PlatformName(operatingSystemName: name).rawValue
            }
        )
        
        self.availableSourceLanguages = reference.sourceLanguages
        
        let semanticSymbol = Symbol(
            kindVariants: DocumentationDataVariants(
                symbolData: unifiedSymbol.kind,
                platformName: platformName
            ),
            titleVariants: DocumentationDataVariants(
                symbolData: unifiedSymbol.names,
                platformName: platformName,
                keyPath: \.title
            ),
            subHeadingVariants: DocumentationDataVariants(
                symbolData: unifiedSymbol.names,
                platformName: platformName,
                keyPath: \.subHeading
            ),
            navigatorVariants: DocumentationDataVariants(
                symbolData: unifiedSymbol.names,
                platformName: platformName,
                keyPath: \.navigator
            ),
            roleHeadingVariants: DocumentationDataVariants(
                symbolData: unifiedSymbol.kind,
                platformName: platformName,
                keyPath: \.displayName
            ),
            platformNameVariants: DocumentationDataVariants(
                defaultVariantValue: platformName.map(PlatformName.init(operatingSystemName:))
            ),
            moduleReference: moduleReference,
            externalIDVariants: DocumentationDataVariants(defaultVariantValue: unifiedSymbol.uniqueIdentifier),
            accessLevelVariants: DocumentationDataVariants(
                symbolData: unifiedSymbol.accessLevel,
                platformName: platformName,
                keyPath: \.rawValue
            ),
            availabilityVariants: symbolAvailabilityVariants,
            deprecatedSummaryVariants: .empty,
            mixinsVariants: DocumentationDataVariants(
                symbolData: unifiedSymbol.mixins,
                platformName: platformName
            ),
            relationshipsVariants: DocumentationDataVariants(
                defaultVariantValue: RelationshipsSection()
            ),
            abstractSectionVariants: .empty,
            discussionVariants: .empty,
            topicsVariants: .empty,
            seeAlsoVariants: .empty,
            returnsSectionVariants: .empty,
            parametersSectionVariants: .empty,
            dictionaryKeysSectionVariants: .empty,
            possibleValuesSectionVariants: .empty,
            httpEndpointSectionVariants: endpointVariants,
            httpBodySectionVariants: .empty,
            httpParametersSectionVariants: .empty,
            httpResponsesSectionVariants: .empty,
            redirectsVariants: .empty,
            crossImportOverlayModule: moduleData.bystanders.map({ (moduleData.name, $0) }),
            overloadsVariants: overloadVariants
        )

        try! semanticSymbol.mergeDeclarations(unifiedSymbol: unifiedSymbol)
        semanticSymbol.mergeAvailabilities(unifiedSymbol: unifiedSymbol)
        self.semantic = semanticSymbol
    }

    /// Given an optional documentation extension, initializes the node's documentation content.
    ///
    /// - Parameters:
    ///   - article: An optional documentation extension article.
    ///   - engine: A diagnostics engine.
    mutating func initializeSymbolContent(documentationExtension: Article?, engine: DiagnosticEngine) {
        precondition(unifiedSymbol != nil && symbol != nil, "You can only call initializeSymbolContent() on a symbol node.")
        
        let (markup, docChunks) = Self.contentFrom(
            documentedSymbol: unifiedSymbol?.documentedSymbol,
            documentationExtension: documentationExtension,
            engine: engine
        )
        
        self.markup = markup
        self.docChunks = docChunks

        // Parse the structured markup
        let markupModel = DocumentationMarkup(markup: markup)
        
        let symbolAvailability = symbol!.mixins.getValueIfPresent(for: SymbolGraph.Symbol.Availability.self)
        
        // Use a deprecation summary from the symbol docs or article content.
        var deprecated: DeprecatedSection? = markupModel.deprecation.map { DeprecatedSection.init(content: $0.elements) }

        // When deprecation is not authored explicitly, try using a deprecation message from annotation.
        if deprecated == nil, let symbolAvailability {
            let availabilityData = AvailabilityParser(symbolAvailability)
            deprecated = availabilityData.deprecationMessage().map(DeprecatedSection.init(text:))
        }

        // Merge in the symbol documentation content
        let semantic = self.semantic as! Symbol
        
        if let displayName = documentationExtension?.metadata?.displayName {
            switch displayName.style {
            case .conceptual:
                self.name = .conceptual(title: displayName.name)
            case .symbol:
                self.name = .symbol(name: displayName.name)
            }
            semantic.titleVariants = semantic.titleVariants.map { _ in
                displayName.name
            }
        }
        
        // Symbol is a by-reference type so we're updating the original `semantic` property instance.
        semantic.abstractSectionVariants = DocumentationDataVariants(
            defaultVariantValue: markupModel.abstractSection
        )
        semantic.discussionVariants = DocumentationDataVariants(
            defaultVariantValue: markupModel.discussionSection
        )
        semantic.topicsVariants = DocumentationDataVariants(
            defaultVariantValue: markupModel.topicsSection
        )
        semantic.seeAlsoVariants = DocumentationDataVariants(
            defaultVariantValue: markupModel.seeAlsoSection
        )
        semantic.deprecatedSummaryVariants = DocumentationDataVariants(
            defaultVariantValue: deprecated
        )
        semantic.redirectsVariants = DocumentationDataVariants(
            defaultVariantValue: documentationExtension?.redirects
        )
        
        let filter = ParametersAndReturnValidator(diagnosticEngine: engine, docChunkSources: docChunks.map(\.source))
        let (parametersSectionVariants, returnsSectionVariants) = filter.makeParametersAndReturnsSections(
            markupModel.discussionTags?.parameters,
            markupModel.discussionTags?.returns,
            unifiedSymbol
        )
        
        semantic.parametersSectionVariants = parametersSectionVariants
        semantic.returnsSectionVariants = returnsSectionVariants
        
        if let keys = markupModel.discussionTags?.dictionaryKeys, !keys.isEmpty {
            // Record the keys extracted from the markdown
            semantic.dictionaryKeysSectionVariants[.fallback] = DictionaryKeysSection(dictionaryKeys:keys)
        }
        
        if let parameters = markupModel.discussionTags?.httpParameters, !parameters.isEmpty {
            // Record the parameters extracted from the markdown
            semantic.httpParametersSectionVariants[.fallback] = HTTPParametersSection(parameters: parameters)
        }
        
        if let body = markupModel.discussionTags?.httpBody {
            // Record the body extracted from the markdown
            semantic.httpBodySectionVariants[.fallback] = HTTPBodySection(body: body)
        }
        
        if let responses = markupModel.discussionTags?.httpResponses, !responses.isEmpty {
            // Record the responses extracted from the markdown
            semantic.httpResponsesSectionVariants[.fallback] = HTTPResponsesSection(responses: responses)
        }
        
        if let possibleValues = markupModel.discussionTags?.possibleValues, !possibleValues.isEmpty {
            let validator = PossibleValuesSection.Validator(diagnosticEngine: engine)
            guard let symbolAllowedValues = symbol?.mixins[SymbolGraph.Symbol.AllowedValues.mixinKey] as? SymbolGraph.Symbol.AllowedValues else {
                possibleValues.forEach { 
                    engine.emit(validator.makeExtraPossibleValueProblem($0, knownPossibleValues: []))
                }
                return semantic.possibleValuesSectionVariants[.fallback] = PossibleValuesSection(possibleValues: [])
            }
            
            // Drop possible values defined in the markdown that are not defined
            // in the SymbolGraph and emit a warning.
            var knownPossibleValues = possibleValues.filter { possibleValue in
                if symbolAllowedValues.value.contains(where: { String($0) == possibleValue.value }) {
                    return true
                }
                // Record problem about extra possible value.
                engine.emit(
                    validator.makeExtraPossibleValueProblem(possibleValue, knownPossibleValues: Set(symbolAllowedValues.value.map { String($0) }))
                )
                return false
            }
            
            // Add the symbol possible values that are not documented.
            symbolAllowedValues.value.forEach { possibleValue in
                if !knownPossibleValues.contains(where: { $0.value == String(possibleValue) }) {
                    knownPossibleValues.append(
                        PossibleValueTag(value: String(possibleValue), contents: [])
                    )
                }
            }
            
            // Record the possible values extracted from the markdown.
            semantic.possibleValuesSectionVariants[.fallback] = PossibleValuesSection(possibleValues: knownPossibleValues)
        }
        
        options = documentationExtension?.options[.local]
        self.metadata = documentationExtension?.metadata
        
        updateAnchorSections()
    }
    
    /// Given a symbol and an optional article returns documentation content.
    /// - Parameters:
    ///   - symbol: A symbol graph symbol.
    ///   - article: An optional article with documentation content.
    ///   - engine: A diagnostics engine to use for problems found while parsing content.
    /// - Returns: The prepared node documentation content.
    static func contentFrom(
        documentedSymbol: SymbolGraph.Symbol?,
        documentationExtension: Article?,
        engine: DiagnosticEngine
    ) -> (markup: Markup, docChunks: [DocumentationChunk]) {
        let markup: Markup
        var documentationChunks: [DocumentationChunk]
        
        // We should ignore the symbol's documentation comment if it wasn't provided
        // or if the documentation extension was set to override.
        let ignoreDocComment = documentedSymbol?.docComment == nil
            || documentationExtension?.metadata?.documentationOptions?.behavior == .override
        
        if let documentationExtensionMarkup = documentationExtension?.markup, ignoreDocComment {
            markup = documentationExtensionMarkup
            documentationChunks = [
                DocumentationChunk(source: .documentationExtension, markup: documentationExtensionMarkup)
            ]
        } else if let symbol = documentedSymbol, let docComment = symbol.docComment {
            let docCommentString = docComment.lines.map { $0.text }.joined(separator: "\n")

            let docCommentLocation: SymbolGraph.Symbol.Location? = {
                if let uri = docComment.uri, let position = docComment.lines.first?.range?.start {
                    return .init(uri: uri, position: position)
                }
                return symbol.mixins.getValueIfPresent(for: SymbolGraph.Symbol.Location.self)
            }()
            
            let documentOptions: ParseOptions = [.parseBlockDirectives, .parseSymbolLinks, .parseMinimalDoxygen]
            let docCommentMarkup = Document(parsing: docCommentString, source: docCommentLocation?.url, options: documentOptions)
            let offset = symbol.docComment?.lines.first?.range

            let docCommentDirectives = docCommentMarkup.children.compactMap({ $0 as? BlockDirective })
            if !docCommentDirectives.isEmpty {
                let location = symbol.mixins.getValueIfPresent(
                    for: SymbolGraph.Symbol.Location.self
                )?.url()

                for directive in docCommentDirectives {
                    let range = docCommentMarkup.child(at: directive.indexInParent)?.range
                    
                    // Only throw warnings for known directive names.
                    //
                    // This is important so that we avoid throwing warnings when building
                    // Objective-C/C documentation that includes doxygen commands.
                    guard BlockDirective.allKnownDirectiveNames.contains(directive.name) else {
                        continue
                    }

                    // Renderable directives are processed like any other piece of structured markdown (tables, lists, etc.)
                    // and so are inherently supported in doc comments.
                    guard DirectiveIndex.shared.renderableDirectives[directive.name] == nil else {
                        continue
                    }

                    let diagnostic = Diagnostic(
                        source: location,
                        severity: .warning,
                        range: range,
                        identifier: "org.swift.docc.UnsupportedDocCommentDirective",
                        summary: "The \(directive.name.singleQuoted) directive is not supported in symbol source documentation",
                        explanation: "Found \(directive.name.singleQuoted) in \(symbol.absolutePath.singleQuoted)"
                    )
                    
                    var problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
                    
                    if let offset {
                        problem.offsetWithRange(offset)
                    }
                    
                    engine.emit(problem)
                }
            }
            
            documentationChunks = [
                DocumentationChunk(
                    source: .sourceCode(
                        location: docCommentLocation, // The documentation chunk represents the doc comment's location, which isn't necessarily the symbol's location.
                        offset: offset
                    ),
                    markup: docCommentMarkup
                )
            ]

            if let documentationExtensionMarkup = documentationExtension?.markup {
                // An `Article` always starts with a level 1 heading (and return `nil` if that's not the first child).
                // For documentation extension files, this heading is a link to the symbol—which isn't part of the content—so it is ignored.
                let documentationExtensionChildren = documentationExtensionMarkup.children.dropFirst().compactMap { $0 as? BlockMarkup }
                
                documentationChunks.append(DocumentationChunk(source: .documentationExtension, markup: documentationExtensionMarkup))
                markup = Document(Array(docCommentMarkup.blockChildren) + documentationExtensionChildren)
            } else {
                markup = docCommentMarkup
            }
        } else {
            markup = Document()
            documentationChunks = [DocumentationChunk(source: .sourceCode(location: nil, offset: nil), markup: markup)]
        }
        
        return (markup: markup, docChunks: documentationChunks)
    }

    /// Returns a documentation node kind for the given symbol kind.
    /// - Parameter symbol: A symbol graph symbol.
    /// - Returns: A documentation node kind.
    static func kind(for symbol: SymbolGraph.Symbol) -> Kind {
        return Self.kind(forKind: symbol.kind.identifier)
    }

    static func kind(forKind symbolKind: SymbolGraph.Symbol.KindIdentifier) -> Kind {
        switch symbolKind {
        case .`associatedtype`: return .associatedType
        case .`class`: return .class
        case .`deinit`: return .deinitializer
        case .dictionary: return .dictionary
        case .dictionaryKey: return .dictionaryKey
        case .`enum`: return .enumeration
        case .`case`: return .enumerationCase
        case .`func`: return .function
        case .httpRequest: return .httpRequest
        case .httpParameter: return .httpParameter
        case .httpBody: return .httpBody
        case .httpResponse: return .httpResponse
        case .`operator`: return .operator
        case .`init`: return .initializer
        case .ivar: return .instanceVariable
        case .macro: return .macro
        case .`method`: return .instanceMethod
        case .namespace: return .namespace
        case .`property`: return .instanceProperty
        case .`protocol`: return .protocol
        case .snippet: return .snippet
        case .`struct`: return .structure
        case .`subscript`: return .instanceSubscript
        case .`typeMethod`: return .typeMethod
        case .`typeProperty`: return .typeProperty
        case .`typeSubscript`: return .typeSubscript
        case .`typealias`: return .typeAlias
        case .union: return .union
        case .`var`: return .globalVariable
        case .module: return .module
        case .extendedModule: return .extendedModule
        case .extendedStructure: return .extendedStructure
        case .extendedClass: return .extendedClass
        case .extendedEnumeration: return .extendedEnumeration
        case .extendedProtocol: return .extendedProtocol
        case .unknownExtendedType: return .unknownExtendedType
        default: return .unknown
        }
    }
    
    /// Initializes a documentation node to represent a symbol from a symbol graph.
    ///
    /// - Parameters:
    ///   - reference: The unique reference to the node.
    ///   - symbol: The symbol to create a documentation node for.
    ///   - platformName: The names of the platform that the symbol is available for.
    ///   - moduleReference: A reference to the module that the symbol belongs to.
    ///   - article: The documentation extension content for this symbol.
    ///   - engine:The engine that collects any problems encountered during initialization.
    public init(reference: ResolvedTopicReference, symbol: SymbolGraph.Symbol, platformName: String?, moduleReference: ResolvedTopicReference, article: Article?, engine: DiagnosticEngine) {
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
        if let displayName = article?.metadata?.displayName {
            switch displayName.style {
            case .conceptual:
                self.name = .conceptual(title: displayName.name)
            case .symbol:
                self.name = .symbol(name: displayName.name)
            }
        } else {
            self.name = .symbol(name: symbol.names.title)
        }
        self.symbol = symbol
        
        // Prefer content sections coming from an article (documentation extension file)
        var deprecated: DeprecatedSection?
        
        let (markup, docChunks) = Self.contentFrom(documentedSymbol: symbol, documentationExtension: article, engine: engine)
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
        
        if let article {
            // Prefer authored deprecation summary over docs.
            deprecated = article.deprecationSummary.map { DeprecatedSection.init(content: $0.elements) }
        }
        if deprecated == nil, let symbolAvailability {
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
            moduleReference: moduleReference,
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
            dictionaryKeysSectionVariants: .init(swiftVariant: markupModel.discussionTags.flatMap({ $0.dictionaryKeys.isEmpty ? nil : DictionaryKeysSection(dictionaryKeys: $0.dictionaryKeys) })),
            possibleValuesSectionVariants: .init(swiftVariant: markupModel.discussionTags.flatMap({ $0.possibleValues.isEmpty ? nil : PossibleValuesSection(possibleValues: $0.possibleValues) })),
            httpEndpointSectionVariants: .empty,
            httpBodySectionVariants: .empty,
            httpParametersSectionVariants: .empty,
            httpResponsesSectionVariants: .empty,
            redirectsVariants: .init(swiftVariant: article?.redirects)
        )
        
        self.isVirtual = symbol.isVirtual
        
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
        self.isVirtual = false
        self.options = article.options[.local]
        self.metadata = article.metadata
        
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
