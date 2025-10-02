/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@_spi(MarkdownOutput) import SwiftDocCMarkdownOutput

/// Visits the semantic structure of a documentation node and returns a ``MarkdownOutputNode``
internal struct MarkdownOutputSemanticVisitor: SemanticVisitor {
    
    let context: DocumentationContext
    let bundle: DocumentationBundle
    let documentationNode: DocumentationNode
    let identifier: ResolvedTopicReference
    var markdownWalker: MarkdownOutputMarkupWalker
    var manifest: MarkdownOutputManifest?
    
    init(context: DocumentationContext, bundle: DocumentationBundle, node: DocumentationNode) {
        self.context = context
        self.bundle = bundle
        self.documentationNode = node
        self.identifier = node.reference
        self.markdownWalker = MarkdownOutputMarkupWalker(context: context, bundle: bundle, identifier: identifier)
    }
    
    typealias Result = MarkdownOutputNode?
    
    // Tutorial processing
    private var sectionIndex = 0
    private var stepIndex = 0
    private var lastCode: Code?
    
    mutating func start() -> MarkdownOutputNode? {
        visit(documentationNode.semantic)
    }
}

extension MarkdownOutputNode.Metadata {
    init(documentType: DocumentType, bundle: DocumentationBundle, reference: ResolvedTopicReference) {
        self.init(
            documentType: documentType,
            uri: reference.path,
            title: reference.lastPathComponent,
            framework: bundle.displayName
        )
    }
}

// MARK: - Manifest construction
extension MarkdownOutputSemanticVisitor {
    
    mutating func add(target: ResolvedTopicReference, type: MarkdownOutputManifest.RelationshipType, subtype: String?) {
        add(targetURI: target.path, type: type, subtype: subtype)
    }
    
    mutating func add(fallbackTarget: String, type: MarkdownOutputManifest.RelationshipType, subtype: String?) {
        let uri: String
        let components = fallbackTarget.components(separatedBy: ".")
        if components.count > 1 {
            uri = "/documentation/\(components.joined(separator: "/"))"
        } else {
            uri = fallbackTarget
        }
        add(targetURI: uri, type: type, subtype: subtype)
    }
    
    mutating func add(targetURI: String, type: MarkdownOutputManifest.RelationshipType, subtype: String?) {
        let relationship = MarkdownOutputManifest.Relationship(sourceURI: identifier.path, relationshipType: type, subtype: subtype, targetURI: targetURI)
        manifest?.relationships.insert(relationship)
    }
}

// MARK: Article Output
extension MarkdownOutputSemanticVisitor {
    
    mutating func visitArticle(_ article: Article) -> MarkdownOutputNode? {
        var metadata = MarkdownOutputNode.Metadata(documentType: .article, bundle: bundle, reference: identifier)
        if let title = article.title?.plainText {
            metadata.title = title
        }
        
        let document = MarkdownOutputManifest.Document(
            uri: identifier.path,
            documentType: .article,
            title: metadata.title
        )
        
        manifest = MarkdownOutputManifest(title: bundle.displayName, documents: [document])
        
        if
            let metadataAvailability = article.metadata?.availability,
            !metadataAvailability.isEmpty {
            metadata.availability = metadataAvailability.map { .init($0) }
        }
        metadata.role = DocumentationContentRenderer.roleForArticle(article, nodeKind: documentationNode.kind).rawValue
        markdownWalker.visit(article.title)
        markdownWalker.visit(article.abstract)
        markdownWalker.visit(section: article.discussion)
        
        // Only care about references from these sections
        markdownWalker.outgoingReferences = []
        markdownWalker.withRenderingLinkList {
            $0.visit(section: article.topics, addingHeading: "Topics")
            $0.visit(section: article.seeAlso, addingHeading: "See Also")
        }
        
        manifest?.relationships.formUnion(markdownWalker.outgoingReferences)
        return MarkdownOutputNode(metadata: metadata, markdown: markdownWalker.markdown)
    }
}

import Markdown

// MARK: Symbol Output
extension MarkdownOutputSemanticVisitor {
    
    mutating func visitSymbol(_ symbol: Symbol) -> MarkdownOutputNode? {
        var metadata = MarkdownOutputNode.Metadata(documentType: .symbol, bundle: bundle, reference: identifier)
        
        metadata.symbol = .init(symbol, context: context, bundle: bundle)
        metadata.role = symbol.kind.displayName
        
        let document = MarkdownOutputManifest.Document(
            uri: identifier.path,
            documentType: .symbol,
            title: metadata.title
        )
        manifest = MarkdownOutputManifest(title: bundle.displayName, documents: [document])
        
        // Availability - defaults, overridden with symbol, overriden with metadata
        
        var availabilities: [String: MarkdownOutputNode.Metadata.Availability] = [:]
        if let primaryModule = metadata.symbol?.modules.first {
            bundle.info.defaultAvailability?.modules[primaryModule]?.forEach {
                let meta = MarkdownOutputNode.Metadata.Availability($0)
                availabilities[meta.platform] = meta
            }
        }
         
        symbol.availability?.availability.forEach {
            let meta = MarkdownOutputNode.Metadata.Availability($0)
            availabilities[meta.platform] = meta
        }
        
        documentationNode.metadata?.availability.forEach {
            let meta = MarkdownOutputNode.Metadata.Availability($0)
            availabilities[meta.platform] = meta
        }
        
        metadata.availability = availabilities.values.sorted(by: \.platform)
         
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
        
        markdownWalker.outgoingReferences = []
        markdownWalker.withRenderingLinkList {
            $0.visit(section: symbol.topics, addingHeading: "Topics")
            $0.visit(section: symbol.seeAlso, addingHeading: "See Also")
        }
        
        manifest?.relationships.formUnion(markdownWalker.outgoingReferences)
        
        for relationshipGroup in symbol.relationships.groups {
            for destination in relationshipGroup.destinations {
                switch context.resolve(destination, in: identifier) {
                case .success(let resolved):
                    add(target: resolved, type: .relatedSymbol, subtype: relationshipGroup.kind.rawValue)
                case .failure:
                    if let fallback = symbol.relationships.targetFallbacks[destination] {
                        add(fallbackTarget: fallback, type: .relatedSymbol, subtype: relationshipGroup.kind.rawValue)
                    }
                }
            }
        }
        return MarkdownOutputNode(metadata: metadata, markdown: markdownWalker.markdown)
    }
}

import SymbolKit

extension MarkdownOutputNode.Metadata.Symbol {
    init(_ symbol: SwiftDocC.Symbol, context: DocumentationContext, bundle: DocumentationBundle) {
                
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
        self.init(
            kind: symbol.kind.identifier.identifier,
            preciseIdentifier: symbol.externalID ?? "",
            modules: modules
        )
    }
}

extension MarkdownOutputNode.Metadata.Availability {
    init(_ item: SymbolGraph.Symbol.Availability.AvailabilityItem) {
        self.init(
            platform: item.domain?.rawValue ?? "*",
            introduced: item.introducedVersion?.description,
            deprecated: item.deprecatedVersion?.description,
            unavailable: item.obsoletedVersion != nil
        )
    }
    
    // From the info.plist of the module
    init(_ availability: DefaultAvailability.ModuleAvailability) {
        self.init(
            platform: availability.platformName.rawValue,
            introduced: availability.introducedVersion,
            deprecated: nil,
            unavailable: availability.versionInformation == .unavailable
        )
    }
    
    init(_ availability: Metadata.Availability) {
        self.init(
            platform: availability.platform.rawValue,
            introduced: availability.introduced.description,
            deprecated: availability.deprecated?.description,
            unavailable: false
        )
    }
}

// MARK: Tutorial Output
extension MarkdownOutputSemanticVisitor {
    // Tutorial table of contents is not useful as markdown or indexable content
    func visitTutorialTableOfContents(_ tutorialTableOfContents: TutorialTableOfContents) -> MarkdownOutputNode? {
        return nil
    }
    
    mutating func visitTutorial(_ tutorial: Tutorial) -> MarkdownOutputNode? {
        var metadata = MarkdownOutputNode.Metadata(documentType: .tutorial, bundle: bundle, reference: identifier)
        
        if tutorial.intro.title.isEmpty == false {
            metadata.title = tutorial.intro.title
        }

        let document = MarkdownOutputManifest.Document(
            uri: identifier.path,
            documentType: .tutorial,
            title: metadata.title
        )
        
        manifest = MarkdownOutputManifest(title: metadata.title, documents: [document])
        
        sectionIndex = 0
        for child in tutorial.children {
            _ = visit(child)
        }
        return MarkdownOutputNode(metadata: metadata, markdown: markdownWalker.markdown)
    }
    
    mutating func visitTutorialSection(_ tutorialSection: TutorialSection) -> MarkdownOutputNode? {
        sectionIndex += 1
        
        markdownWalker.visit(Heading(level: 2, Text("Section \(sectionIndex): \(tutorialSection.title)")))
        for child in tutorialSection.children {
            _ = visit(child)
        }
        return nil
    }
    
    mutating func visitSteps(_ steps: Steps) -> MarkdownOutputNode? {
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
    
    mutating func visitStep(_ step: Step) -> MarkdownOutputNode? {
        
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
    
    mutating func visitIntro(_ intro: Intro) -> MarkdownOutputNode? {
        
        markdownWalker.visit(Heading(level: 1, Text(intro.title)))
        
        for child in intro.children {
            _ = visit(child)
        }
        return nil
    }
    
    mutating func visitMarkupContainer(_ markupContainer: MarkupContainer) -> MarkdownOutputNode? {
        markdownWalker.withRemoveIndentation(from: markupContainer.elements.first) {
            $0.visit(container: markupContainer)
        }
        return nil
    }
    
    mutating func visitImageMedia(_ imageMedia: ImageMedia) -> MarkdownOutputNode? {
        markdownWalker.visit(imageMedia)
        return nil
    }
    
    mutating func visitVideoMedia(_ videoMedia: VideoMedia) -> MarkdownOutputNode? {
        markdownWalker.visit(videoMedia)
        return nil
    }
    
    mutating func visitContentAndMedia(_ contentAndMedia: ContentAndMedia) -> MarkdownOutputNode? {
        for child in contentAndMedia.children {
            _ = visit(child)
        }
        return nil
    }
    
    mutating func visitCode(_ code: Code) -> MarkdownOutputNode? {
        // Code rendering is handled in visitStep(_:)
        return nil
    }
}


// MARK: Visitors not currently used for markdown output
extension MarkdownOutputSemanticVisitor {
        
    mutating func visitXcodeRequirement(_ xcodeRequirement: XcodeRequirement) -> MarkdownOutputNode? {
        return nil
    }
    
    mutating func visitAssessments(_ assessments: Assessments) -> MarkdownOutputNode? {
        return nil
    }
    
    mutating func visitMultipleChoice(_ multipleChoice: MultipleChoice) -> MarkdownOutputNode? {
        return nil
    }
    
    mutating func visitJustification(_ justification: Justification) -> MarkdownOutputNode? {
        return nil
    }
    
    mutating func visitChoice(_ choice: Choice) -> MarkdownOutputNode? {
        return nil
    }
        
    mutating func visitTechnology(_ technology: TutorialTableOfContents) -> MarkdownOutputNode? {
        return nil
    }
        
    mutating func visitVolume(_ volume: Volume) -> MarkdownOutputNode? {
        return nil
    }
    
    mutating func visitChapter(_ chapter: Chapter) -> MarkdownOutputNode? {
        return nil
    }
    
    mutating func visitTutorialReference(_ tutorialReference: TutorialReference) -> MarkdownOutputNode? {
        return nil
    }
    
    mutating func visitResources(_ resources: Resources) -> MarkdownOutputNode? {
        return nil
    }
    
    mutating func visitTile(_ tile: Tile) -> MarkdownOutputNode? {
        return nil
    }
    
    mutating func visitComment(_ comment: Comment) -> MarkdownOutputNode? {
        return nil
    }
    
    mutating func visitTutorialArticle(_ article: TutorialArticle) -> MarkdownOutputNode? {
        return nil
    }
    
    mutating func visitStack(_ stack: Stack) -> MarkdownOutputNode? {
        return nil
    }
    
    mutating func visitDeprecationSummary(_ summary: DeprecationSummary) -> MarkdownOutputNode? {
        return nil
    }
}
