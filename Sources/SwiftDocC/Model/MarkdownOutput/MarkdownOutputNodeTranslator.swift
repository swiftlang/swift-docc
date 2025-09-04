import Foundation
import Markdown

public struct MarkdownOutputNodeTranslator: SemanticVisitor {
    
    public let context: DocumentationContext
    public let bundle: DocumentationBundle
    public let identifier: ResolvedTopicReference
    
    public init(context: DocumentationContext, bundle: DocumentationBundle, identifier: ResolvedTopicReference) {
        self.context = context
        self.bundle = bundle
        self.identifier = identifier
    }
        
    public typealias Result = MarkdownOutputNode?
    
    public mutating func visitArticle(_ article: Article) -> MarkdownOutputNode? {
        var node = MarkdownOutputNode(context: context, bundle: bundle, identifier: identifier)
        
        node.visit(article.title)
        node.visit(article.abstract)
        node.visit(section: article.discussion)
        node.withRenderingLinkList {
            $0.visit(section: article.topics, addingHeading: "Topics")
            $0.visit(section: article.seeAlso, addingHeading: "See Also")
        }
        return node
    }
    
    public mutating func visitSymbol(_ symbol: Symbol) -> MarkdownOutputNode? {
        var node = MarkdownOutputNode(context: context, bundle: bundle, identifier: identifier)
        
        node.visit(Heading(level: 1, Text(symbol.title)))
        node.visit(symbol.abstract)
        node.visit(section: symbol.discussion, addingHeading: "Overview")
        node.withRenderingLinkList {
            $0.visit(section: symbol.topics, addingHeading: "Topics")
            $0.visit(section: symbol.seeAlso, addingHeading: "See Also")
        }
        return node
    }
    
    public mutating func visitCode(_ code: Code) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitStep(_ step: Step) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitSteps(_ steps: Steps) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitTutorialSection(_ tutorialSection: TutorialSection) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitTutorial(_ tutorial: Tutorial) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitIntro(_ intro: Intro) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
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
    
    public mutating func visitMarkupContainer(_ markupContainer: MarkupContainer) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitTechnology(_ technology: TutorialTableOfContents) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitImageMedia(_ imageMedia: ImageMedia) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitVideoMedia(_ videoMedia: VideoMedia) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
    
    public mutating func visitContentAndMedia(_ contentAndMedia: ContentAndMedia) -> MarkdownOutputNode? {
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
        print(#function)
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
    
    public func visitTutorialTableOfContents(_ tutorialTableOfContents: TutorialTableOfContents) -> MarkdownOutputNode? {
        print(#function)
        return nil
    }
}
