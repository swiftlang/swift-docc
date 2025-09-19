/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// Visits the semantic structure of a documentation node and returns a ``MarkdownOutputNode``
internal struct MarkdownOutputSemanticVisitor: SemanticVisitor {
    
    let context: DocumentationContext
    let bundle: DocumentationBundle
    let documentationNode: DocumentationNode
    let identifier: ResolvedTopicReference
    var markdownWalker: MarkdownOutputMarkupWalker
    
    init(context: DocumentationContext, bundle: DocumentationBundle, node: DocumentationNode) {
        self.context = context
        self.bundle = bundle
        self.documentationNode = node
        self.identifier = node.reference
        self.markdownWalker = MarkdownOutputMarkupWalker(context: context, bundle: bundle, identifier: identifier)
    }
    
    public typealias Result = MarkdownOutputNode?
    
    // Tutorial processing
    private var sectionIndex = 0
    private var stepIndex = 0
    private var lastCode: Code?
    
    mutating func start() -> MarkdownOutputNode? {
        visit(documentationNode.semantic)
    }
}

extension MarkdownOutputNode.Metadata {
    public init(documentType: DocumentType, bundle: DocumentationBundle, reference: ResolvedTopicReference) {
        self.documentType = documentType
        self.metadataVersion = Self.version.description
        self.uri = reference.path
        self.title = reference.lastPathComponent
        self.framework = bundle.displayName
    }
}

// MARK: Article Output
extension MarkdownOutputSemanticVisitor {
    
    public mutating func visitArticle(_ article: Article) -> MarkdownOutputNode? {
        var metadata = MarkdownOutputNode.Metadata(documentType: .article, bundle: bundle, reference: identifier)
        if let title = article.title?.plainText {
            metadata.title = title
        }
        
        if
            let metadataAvailability = article.metadata?.availability,
            !metadataAvailability.isEmpty {
            metadata.availability = metadataAvailability.map { .init($0) }
        }
        metadata.role = DocumentationContentRenderer.roleForArticle(article, nodeKind: documentationNode.kind).rawValue
        markdownWalker.visit(article.title)
        markdownWalker.visit(article.abstract)
        markdownWalker.visit(section: article.discussion)
        markdownWalker.withRenderingLinkList {
            $0.visit(section: article.topics, addingHeading: "Topics")
            $0.visit(section: article.seeAlso, addingHeading: "See Also")
        }
        return MarkdownOutputNode(metadata: metadata, markdown: markdownWalker.markdown)
    }
}

import Markdown

// MARK: Symbol Output
extension MarkdownOutputSemanticVisitor {
    
    public mutating func visitSymbol(_ symbol: Symbol) -> MarkdownOutputNode? {
        var metadata = MarkdownOutputNode.Metadata(documentType: .symbol, bundle: bundle, reference: identifier)
        
        metadata.symbol = .init(symbol, context: context, bundle: bundle)
        
        // Availability
        
        let symbolAvailability = symbol.availability?.availability.map {
            MarkdownOutputNode.Metadata.Availability($0)
        }
        
        if let availability = symbolAvailability, availability.isEmpty == false {
            metadata.availability = availability
        } else if let primaryModule = metadata.symbol?.modules.first, let defaultAvailability = bundle.info.defaultAvailability?.modules[primaryModule] {
            metadata.availability = defaultAvailability.map { .init($0) }
        }
        
        // Content
        
        markdownWalker.visit(Heading(level: 1, Text(symbol.title)))
        markdownWalker.visit(symbol.abstract)
        if let declarationFragments = symbol.declaration.first?.value.declarationFragments {
            let declaration = declarationFragments
                .map { $0.spelling }
                .joined()
            let code = CodeBlock(declaration)
            markdownWalker.visit(code)
        }
        
        if let parametersSection = symbol.parametersSection, parametersSection.parameters.isEmpty == false {
            markdownWalker.visit(Heading(level: 2, Text(ParametersSection.title ?? "Parameters")))
            for parameter in parametersSection.parameters {
                markdownWalker.visit(Paragraph(InlineCode(parameter.name)))
                markdownWalker.visit(container: MarkupContainer(parameter.contents))
            }
        }
        
        markdownWalker.visit(section: symbol.returnsSection)
        
        markdownWalker.visit(section: symbol.discussion, addingHeading: symbol.kind.identifier.swiftSymbolCouldHaveChildren ? "Overview" : "Discussion")
        markdownWalker.withRenderingLinkList {
            $0.visit(section: symbol.topics, addingHeading: "Topics")
            $0.visit(section: symbol.seeAlso, addingHeading: "See Also")
        }
        return MarkdownOutputNode(metadata: metadata, markdown: markdownWalker.markdown)
    }
}

import SymbolKit

extension MarkdownOutputNode.Metadata.Symbol {
    init(_ symbol: SwiftDocC.Symbol, context: DocumentationContext, bundle: DocumentationBundle) {
        self.kind = symbol.kind.displayName
        self.preciseIdentifier = symbol.externalID ?? ""
                
        // Gather modules
        var modules = [String]()

        if let main = try? context.entity(with: symbol.moduleReference) {
            modules.append(main.name.plainText)
        }
        if let crossImport = symbol.crossImportOverlayModule {
            modules.append(contentsOf: crossImport.bystanderModules)
        }
        if let extended = symbol.extendedModuleVariants.firstValue, modules.contains(extended) == false {
            modules.append(extended)
        }
        
        self.modules = modules
    }
}

extension MarkdownOutputNode.Metadata.Availability {
    init(_ item: SymbolGraph.Symbol.Availability.AvailabilityItem) {
        self.platform = item.domain?.rawValue ?? "*"
        self.introduced = item.introducedVersion?.description
        self.deprecated = item.deprecatedVersion?.description
        self.unavailable = item.obsoletedVersion != nil
    }
    
    init(_ availability: DefaultAvailability.ModuleAvailability) {
        self.platform = availability.platformName.displayName
        self.introduced = availability.introducedVersion
        self.deprecated = nil
        self.unavailable = availability.versionInformation == .unavailable
    }
    
    init(_ availability: Metadata.Availability) {
        self.platform = availability.platform.rawValue
        self.introduced = availability.introduced.description
        self.deprecated = availability.deprecated?.description
        self.unavailable = false
    }
}

// MARK: Tutorial Output
extension MarkdownOutputSemanticVisitor {
    // Tutorial table of contents is not useful as markdown or indexable content
    public func visitTutorialTableOfContents(_ tutorialTableOfContents: TutorialTableOfContents) -> MarkdownOutputNode? {
        return nil
    }
    
    public mutating func visitTutorial(_ tutorial: Tutorial) -> MarkdownOutputNode? {
        var metadata = MarkdownOutputNode.Metadata(documentType: .tutorial, bundle: bundle, reference: identifier)
        if tutorial.intro.title.isEmpty == false {
            metadata.title = tutorial.intro.title
        }

        sectionIndex = 0
        for child in tutorial.children {
            _ = visit(child)
        }
        return MarkdownOutputNode(metadata: metadata, markdown: markdownWalker.markdown)
    }
    
    public mutating func visitTutorialSection(_ tutorialSection: TutorialSection) -> MarkdownOutputNode? {
        sectionIndex += 1
        
        markdownWalker.visit(Heading(level: 2, Text("Section \(sectionIndex): \(tutorialSection.title)")))
        for child in tutorialSection.children {
            _ = visit(child)
        }
        return nil
    }
    
    public mutating func visitSteps(_ steps: Steps) -> MarkdownOutputNode? {
        stepIndex = 0
        for child in steps.children {
            _ = visit(child)
        }
        
        if let code = lastCode {
            markdownWalker.visit(code)
            lastCode = nil
        }
        
        return nil
    }
    
    public mutating func visitStep(_ step: Step) -> MarkdownOutputNode? {
        
        // Check if the step contains another version of the current code reference
        if let code = lastCode {
            if let stepCode = step.code {
                if stepCode.fileName != code.fileName {
                    // New reference, render before proceeding
                    markdownWalker.visit(code)
                }
            } else {
                // No code, render the current one before proceeding
                markdownWalker.visit(code)
                lastCode = nil
            }
        }
        
        lastCode = step.code
        
        stepIndex += 1
        markdownWalker.visit(Heading(level: 3, Text("Step \(stepIndex)")))
        for child in step.children {
            _ = visit(child)
        }
        if let media = step.media {
            _ = visit(media)
        }
        return nil
    }
    
    public mutating func visitIntro(_ intro: Intro) -> MarkdownOutputNode? {
        
        markdownWalker.visit(Heading(level: 1, Text(intro.title)))
        
        for child in intro.children {
            _ = visit(child)
        }
        return nil
    }
    
    public mutating func visitMarkupContainer(_ markupContainer: MarkupContainer) -> MarkdownOutputNode? {
        markdownWalker.withRemoveIndentation(from: markupContainer.elements.first) {
            $0.visit(container: markupContainer)
        }
        return nil
    }
    
    public mutating func visitImageMedia(_ imageMedia: ImageMedia) -> MarkdownOutputNode? {
        markdownWalker.visit(imageMedia)
        return nil
    }
    
    public mutating func visitVideoMedia(_ videoMedia: VideoMedia) -> MarkdownOutputNode? {
        markdownWalker.visit(videoMedia)
        return nil
    }
    
    public mutating func visitContentAndMedia(_ contentAndMedia: ContentAndMedia) -> MarkdownOutputNode? {
        for child in contentAndMedia.children {
            _ = visit(child)
        }
        return nil
    }
    
    public mutating func visitCode(_ code: Code) -> MarkdownOutputNode? {
        // Code rendering is handled in visitStep(_:)
        return nil
    }
}


// MARK: Visitors not used for markdown output
extension MarkdownOutputSemanticVisitor {
        
    public mutating func visitXcodeRequirement(_ xcodeRequirement: XcodeRequirement) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitAssessments(_ assessments: Assessments) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitMultipleChoice(_ multipleChoice: MultipleChoice) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitJustification(_ justification: Justification) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitChoice(_ choice: Choice) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
        
    public mutating func visitTechnology(_ technology: TutorialTableOfContents) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
        
    public mutating func visitVolume(_ volume: Volume) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitChapter(_ chapter: Chapter) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitTutorialReference(_ tutorialReference: TutorialReference) -> MarkdownOutputNode? {
        return nil
    }
    
    public mutating func visitResources(_ resources: Resources) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitTile(_ tile: Tile) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitComment(_ comment: Comment) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitTutorialArticle(_ article: TutorialArticle) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitStack(_ stack: Stack) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitDeprecationSummary(_ summary: DeprecationSummary) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
}
