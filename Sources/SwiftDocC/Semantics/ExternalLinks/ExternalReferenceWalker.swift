/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

fileprivate extension Optional {
    /// If self is not `nil`, run the given block.
    func unwrap(_ block: (Wrapped) -> Void) {
        if let self = self {
            block(self)
        }
    }
}

/**
 Walks a `Semantic` tree and collects any and all links external to the given bundle.
 
 Visits semantic nodes and descends into all their children that do have (indirectly or directly) content.
 When visiting a node that directly contains markup content visits the markup with an instance of ``ExternalMarkupReferenceWalker``
 which in turn walks the markup tree and collects external links.
 
 Once the visitor has finished visiting the semantic node and the relevant children all
 encountered external links are collected in ``collectedExternalReferences``.
 
 > Warning: This type needs to keep up to date with the semantic objects it walks. When changing the API design
   for types like ``Symbol`` or ``Article``, if the changes include new pieces of content that might contain external links,
   this type needs to be updated to walk those new pieces of content as well.
 */
struct ExternalReferenceWalker: SemanticVisitor {
    typealias Result = Void

    /// A markup walker to use for collecting links from markup elements.
    private var markupResolver: ExternalMarkupReferenceWalker
    
    /// Collected external links while walking the given elements.
    var collectedExternalReferences: [UnresolvedTopicReference] {
        return markupResolver.collectedExternalLinks.map { url -> UnresolvedTopicReference in
            return .init(topicURL: url)
        }
    }
    
    /// Creates a new semantic walker.
    /// - Parameter bundle: All links with a bundle ID different than this bundle's are considered external and collected.
    init(bundle: DocumentationBundle) {
        self.markupResolver = ExternalMarkupReferenceWalker(bundle: bundle)
    }
    
    mutating func visitCode(_ code: Code) { }
    
    mutating func visitSteps(_ steps: Steps) {
        steps.content.forEach { visit($0) }
    }
    
    mutating func visitStep(_ step: Step) {
        visit(step.content)
        visit(step.caption)
    }
        
    mutating func visitTutorialSection(_ tutorialSection: TutorialSection) {
        visitMarkupLayouts(tutorialSection.introduction)
        tutorialSection.stepsContent.unwrap { visitSteps($0) }
    }
    
    mutating func visitTutorial(_ tutorial: Tutorial) {
        visit(tutorial.intro)
        tutorial.sections.forEach { visit($0) }
        if let assesments = tutorial.assessments {
            visit(assesments)
        }
    }
    
    mutating func visitIntro(_ intro: Intro) {
        visit(intro.content)
    }
    
    mutating func visitXcodeRequirement(_ xcodeRequirement: XcodeRequirement) { }
    
    mutating func visitAssessments(_ assessments: Assessments) {
        assessments.questions.forEach { visit($0) }
    }
    
    mutating func visitMultipleChoice(_ multipleChoice: MultipleChoice) {
        visit(multipleChoice.questionPhrasing)
        visit(multipleChoice.content)
        multipleChoice.choices.forEach { visit($0) }
    }
    
    mutating func visitJustification(_ justification: Justification) {
        visit(justification.content)
    }
    
    mutating func visitChoice(_ choice: Choice) {
        visit(choice.content)
        visit(choice.justification)
    }
    
    mutating func visitMarkupContainer(_ markupContainer: MarkupContainer) {
        markupContainer.elements.forEach { markupResolver.visit($0) }
    }
    
    mutating func visitMarkup(_ markup: Markup) {
        visitMarkupContainer(MarkupContainer(markup))
    }
    
    mutating func visitTechnology(_ technology: Technology) {
        visit(technology.intro)
        technology.volumes.forEach { visit($0) }
        technology.resources.unwrap { visit($0) }
    }
    
    mutating func visitImageMedia(_ imageMedia: ImageMedia) { }
    
    mutating func visitVideoMedia(_ videoMedia: VideoMedia) { }
    
    mutating func visitContentAndMedia(_ contentAndMedia: ContentAndMedia) {
        visit(contentAndMedia.content)
    }
    
    mutating func visitVolume(_ volume: Volume) {
        volume.content.unwrap { visit($0) }
        volume.chapters.forEach { visit($0) }
    }
    
    mutating func visitChapter(_ chapter: Chapter) {
        visit(chapter.content)
        chapter.topicReferences.forEach { visit($0) }
    }
    
    mutating func visitTutorialReference(_ tutorialReference: TutorialReference) { }

    mutating func visitResources(_ resources: Resources) {
        visitMarkupContainer(resources.content)
        resources.tiles.forEach { visitTile($0) }
    }
    
    mutating func visitTile(_ tile: Tile) {
        visitMarkupContainer(tile.content)
    }
    
    mutating func visitTutorialArticle(_ article: TutorialArticle) {
        article.intro.unwrap { visitIntro($0) }
        visitMarkupLayouts(article.content)
        article.assessments.unwrap { visit($0) }
    }
    
    mutating func visitArticle(_ article: Article) {
        article.abstractSection.unwrap { visitMarkup($0.paragraph) }
        article.discussion.unwrap { $0.content.forEach { visitMarkup($0) }}
        article.topics.unwrap { $0.content.forEach { visitMarkup($0) }}
        article.seeAlso.unwrap { $0.content.forEach { visitMarkup($0) }}
        article.deprecationSummary.unwrap { visitMarkupContainer($0) }
    }

    private mutating func visitMarkupLayouts<MarkupLayouts: Sequence>(_ markupLayouts: MarkupLayouts) where MarkupLayouts.Element == MarkupLayout {
        markupLayouts.forEach { content in
            switch content {
            case .markup(let markup): visitMarkupContainer(markup)
            case .contentAndMedia(let contentAndMedia): visitContentAndMedia(contentAndMedia)
            case .stack(let stack): visitStack(stack)
            }
        }
    }
    
    mutating func visitStack(_ stack: Stack) {
        stack.contentAndMedia.forEach { visitContentAndMedia($0) }
    }

    mutating func visitComment(_ comment: Comment) { }
    
    mutating func visitSymbol(_ symbol: Symbol) {
        symbol.abstractSection.unwrap { visitMarkup($0.paragraph) }
        symbol.discussion.unwrap { $0.content.forEach { visitMarkup($0) }}
        symbol.topics.unwrap { $0.content.forEach { visitMarkup($0) }}
        symbol.seeAlso.unwrap { $0.content.forEach { visitMarkup($0) }}
        symbol.returnsSection.unwrap { $0.content.forEach { visitMarkup($0) }}
        
        symbol.parametersSection.unwrap {
            $0.parameters.forEach {
                $0.contents.forEach { visitMarkup($0) }
            }
        }
    }
    
    mutating func visitDeprecationSummary(_ summary: DeprecationSummary) {
        visit(summary.content)
    }
}
