/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

public struct MarkdownOutputNodeTranslator: SemanticVisitor {
    
    public let context: DocumentationContext
    public let bundle: DocumentationBundle
    public let documentationNode: DocumentationNode
    public let identifier: ResolvedTopicReference
    
    public init(context: DocumentationContext, bundle: DocumentationBundle, node: DocumentationNode) {
        self.context = context
        self.bundle = bundle
        self.documentationNode = node
        self.identifier = node.reference
    }
    
    public typealias Result = MarkdownOutputNode?
    private var node: Result = nil
    
    // Tutorial processing
    private var sectionIndex = 0
    private var stepIndex = 0
    private var lastCode: Code?
}

// MARK: Article Output
extension MarkdownOutputNodeTranslator {
    
    public mutating func visitArticle(_ article: Article) -> MarkdownOutputNode? {
        var node = MarkdownOutputNode(context: context, bundle: bundle, identifier: identifier, documentType: .article)
        if let title = article.title?.plainText {
            node.metadata.title = title
        }
        
        node.metadata.role = DocumentationContentRenderer.roleForArticle(article, nodeKind: documentationNode.kind).rawValue
        node.visit(article.title)
        node.visit(article.abstract)
        node.visit(section: article.discussion)
        node.withRenderingLinkList {
            $0.visit(section: article.topics, addingHeading: "Topics")
            $0.visit(section: article.seeAlso, addingHeading: "See Also")
        }
        return node
    }
}

// MARK: Symbol Output
extension MarkdownOutputNodeTranslator {
    
    public mutating func visitSymbol(_ symbol: Symbol) -> MarkdownOutputNode? {
        var node = MarkdownOutputNode(context: context, bundle: bundle, identifier: identifier, documentType: .symbol)
        
        node.metadata.symbol = .init(symbol, context: context)
        
        node.visit(Heading(level: 1, Text(symbol.title)))
        node.visit(symbol.abstract)
        if let declarationFragments = symbol.declaration.first?.value.declarationFragments {
            let declaration = declarationFragments
                .map { $0.spelling }
                .joined()
            let code = CodeBlock(declaration)
            node.visit(code)
        }
        
        if let parametersSection = symbol.parametersSection, parametersSection.parameters.isEmpty == false {
            node.visit(Heading(level: 2, Text(ParametersSection.title ?? "Parameters")))
            for parameter in parametersSection.parameters {
                node.visit(Paragraph(InlineCode(parameter.name)))
                node.visit(container: MarkupContainer(parameter.contents))
            }
        }
        
        node.visit(section: symbol.returnsSection)
        
        node.visit(section: symbol.discussion, addingHeading: symbol.kind.identifier.swiftSymbolCouldHaveChildren ? "Overview" : "Discussion")
        node.withRenderingLinkList {
            $0.visit(section: symbol.topics, addingHeading: "Topics")
            $0.visit(section: symbol.seeAlso, addingHeading: "See Also")
        }
        return node
    }
}

import SymbolKit

extension MarkdownOutputNode.Metadata.Symbol {
    init(_ symbol: SwiftDocC.Symbol, context: DocumentationContext) {
        self.kind = symbol.kind.displayName
        self.preciseIdentifier = symbol.externalID ?? ""
        let symbolAvailability = symbol.availability?.availability.map {
            MarkdownOutputNode.Metadata.Symbol.Availability($0)
        }
        
        if let availability = symbolAvailability, availability.isEmpty == false {
            self.availability = availability
        } else {
            self.availability = nil
        }
        
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

extension MarkdownOutputNode.Metadata.Symbol.Availability {
    init(_ item: SymbolGraph.Symbol.Availability.AvailabilityItem) {
        self.platform = item.domain?.rawValue ?? "*"
        self.introduced = item.introducedVersion?.description
        self.deprecated = item.deprecatedVersion?.description
        self.unavailable = item.obsoletedVersion?.description
    }
}


// MARK: Tutorial Output
extension MarkdownOutputNodeTranslator {
    // Tutorial table of contents is not useful as markdown or indexable content
    public func visitTutorialTableOfContents(_ tutorialTableOfContents: TutorialTableOfContents) -> MarkdownOutputNode? {
        return nil
    }
    
    public mutating func visitTutorial(_ tutorial: Tutorial) -> MarkdownOutputNode? {
        node = MarkdownOutputNode(context: context, bundle: bundle, identifier: identifier, documentType: .tutorial)
        if tutorial.intro.title.isEmpty == false {
            node?.metadata.title = tutorial.intro.title
        }

        sectionIndex = 0
        for child in tutorial.children {
            node = visit(child) ?? node
        }
        return node
    }
    
    public mutating func visitTutorialSection(_ tutorialSection: TutorialSection) -> MarkdownOutputNode? {
        sectionIndex += 1
        
        node?.visit(Heading(level: 2, Text("Section \(sectionIndex): \(tutorialSection.title)")))
        for child in tutorialSection.children {
            node = visit(child) ?? node
        }
        return nil
    }
    
    public mutating func visitSteps(_ steps: Steps) -> MarkdownOutputNode? {
        stepIndex = 0
        for child in steps.children {
            node = visit(child) ?? node
        }
        
        if let code = lastCode {
            node?.visit(code)
            lastCode = nil
        }
        
        return node
    }
    
    public mutating func visitStep(_ step: Step) -> MarkdownOutputNode? {
        
        // Check if the step contains another version of the current code reference
        if let code = lastCode {
            if let stepCode = step.code {
                if stepCode.fileName != code.fileName {
                    // New reference, render before proceeding
                    node?.visit(code)
                }
            } else {
                // No code, render the current one before proceeding
                node?.visit(code)
                lastCode = nil
            }
        }
        
        lastCode = step.code
        
        stepIndex += 1
        node?.visit(Heading(level: 3, Text("Step \(stepIndex)")))
        for child in step.children {
            node = visit(child) ?? node
        }
        if let media = step.media {
            node = visit(media) ?? node
        }
        return node
    }
    
    public mutating func visitIntro(_ intro: Intro) -> MarkdownOutputNode? {
        
        node?.visit(Heading(level: 1, Text(intro.title)))
        
        for child in intro.children {
            node = visit(child) ?? node
        }
        return node
    }
    
    public mutating func visitMarkupContainer(_ markupContainer: MarkupContainer) -> MarkdownOutputNode? {
        node?.withRemoveIndentation(from: markupContainer.elements.first) {
            $0.visit(container: markupContainer)
        }
        return node
    }
    
    public mutating func visitImageMedia(_ imageMedia: ImageMedia) -> MarkdownOutputNode? {
        node?.visit(imageMedia)
        return node
    }
    
    public mutating func visitVideoMedia(_ videoMedia: VideoMedia) -> MarkdownOutputNode? {
        node?.visit(videoMedia)
        return node
    }
    
    public mutating func visitContentAndMedia(_ contentAndMedia: ContentAndMedia) -> MarkdownOutputNode? {
        for child in contentAndMedia.children {
            node = visit(child) ?? node
        }
        return node
    }
    
    public mutating func visitCode(_ code: Code) -> MarkdownOutputNode? {
        // Code rendering is handled in visitStep(_:)
        return nil
    }
}


// MARK: Visitors not used for markdown output
extension MarkdownOutputNodeTranslator {
        
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
